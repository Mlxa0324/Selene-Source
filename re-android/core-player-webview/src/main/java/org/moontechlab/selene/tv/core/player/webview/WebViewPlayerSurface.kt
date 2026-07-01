package org.moontechlab.selene.tv.core.player.webview

import android.util.Log
import android.webkit.ConsoleMessage
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import java.net.URLEncoder

/**
 * WebView 播放器画面层。
 *
 * @param playbackRequest 当前播放请求，空值时保持黑色视频容器。
 * @param modifier 外层修饰器。
 * @param commandBus WebView 播放命令总线。
 * @param onPlaybackEvent WebView 页面上报真实播放状态后的回调。
 */
@Composable
fun WebViewPlayerSurface(
    playbackRequest: PlaybackRequest?,
    modifier: Modifier = Modifier,
    commandBus: WebViewPlayerCommandBus? = null,
    onPlaybackEvent: ((WebViewPlaybackEvent) -> Unit)? = null,
) {
    val webViewHolder = remember { mutableStateOf<WebView?>(null) }
    val playbackEventCallback = rememberUpdatedState(onPlaybackEvent)
    val playbackBridge = remember {
        WebViewPlayerJavascriptBridge(
            onPlaybackEvent = { event ->
                playbackEventCallback.value?.invoke(event)
            },
        )
    }

    LaunchedEffect(commandBus) {
        if (commandBus == null) {
            return@LaunchedEffect
        }
        commandBus.commands.collect { command ->
            webViewHolder.value?.evaluateJavascript(command.toJavaScript(), null)
        }
    }

    AndroidView(
        modifier = modifier,
        factory = { context ->
            WebView(context).apply {
                // TV WebView 播放 HLS 需要脚本和免手势起播，遥控器控制仍由 Compose 壳接管。
                settings.javaScriptEnabled = true
                settings.mediaPlaybackRequiresUserGesture = false
                settings.domStorageEnabled = true
                // 内置 asset 播放页需要访问远端 m3u8 和分片资源。
                settings.allowUniversalAccessFromFileURLs = true
                settings.allowFileAccessFromFileURLs = true
                settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
                setBackgroundColor(android.graphics.Color.BLACK)
                if (onPlaybackEvent != null) {
                    // 只暴露播放状态上报入口，页面命令仍由 Compose 壳通过 evaluateJavascript 下发。
                    addJavascriptInterface(playbackBridge, WEBVIEW_PLAYER_BRIDGE_NAME)
                }
                webChromeClient = object : WebChromeClient() {
                    /**
                     * 透出内置播放页日志，方便定位 HLS manifest、分片或 codec 错误。
                     */
                    override fun onConsoleMessage(consoleMessage: ConsoleMessage?): Boolean {
                        consoleMessage?.let { message ->
                            Log.d(
                                WEBVIEW_PLAYER_LOG_TAG,
                                "${message.messageLevel()}: ${message.message()} @${message.lineNumber()}",
                            )
                        }
                        return true
                    }
                }
                webViewClient = object : WebViewClient() {
                    /**
                     * 播放页创建完成后补一次起播，避免初始命令早于页面 JS 注册。
                     */
                    override fun onPageFinished(view: WebView?, url: String?) {
                        view?.evaluateJavascript(WebViewPlayerCommand.Play.toJavaScript(), null)
                    }

                    /**
                     * 透出 WebView 资源加载错误，避免详情页只显示黑屏但没有排障线索。
                     */
                    override fun onReceivedError(
                        view: WebView?,
                        request: WebResourceRequest?,
                        error: WebResourceError?,
                    ) {
                        super.onReceivedError(view, request, error)
                        Log.w(
                            WEBVIEW_PLAYER_LOG_TAG,
                            "resource error ${request?.url}: ${error?.errorCode} ${error?.description}",
                        )
                    }

                    /**
                     * 透出 HLS manifest 或分片 HTTP 错误，便于判断资源是否被服务端拒绝。
                     */
                    override fun onReceivedHttpError(
                        view: WebView?,
                        request: WebResourceRequest?,
                        errorResponse: WebResourceResponse?,
                    ) {
                        super.onReceivedHttpError(view, request, errorResponse)
                        Log.w(
                            WEBVIEW_PLAYER_LOG_TAG,
                            "http error ${request?.url}: ${errorResponse?.statusCode} ${errorResponse?.reasonPhrase}",
                        )
                    }
                }
                webViewHolder.value = this
            }
        },
        update = { webView ->
            webViewHolder.value = webView
            val playbackUrl = playbackRequest?.url.orEmpty()
            if (playbackUrl.isBlank()) {
                return@AndroidView
            }
            val targetUrl = resolveWebViewPlayerUrl(playbackUrl)
            if (webView.url != targetUrl) {
                // 只有播放地址变化时才重载页面，菜单和焦点重组不能打断 WebView 播放。
                webView.loadUrl(resolveWebViewPlayerUrl(playbackUrl))
            }
        },
    )
}

/**
 * WebView 页面到原生播放器状态的 JS 桥。
 *
 * @property bridge JSON 播放事件映射器。
 * @property onPlaybackEvent 播放事件回调。
 */
private class WebViewPlayerJavascriptBridge(
    private val bridge: WebViewPlayerBridge = WebViewPlayerBridge(),
    private val onPlaybackEvent: (WebViewPlaybackEvent) -> Unit,
) {
    /**
     * 接收内置播放页上报的播放事件。
     *
     * @param payload 播放页序列化后的 JSON 字符串。
     */
    @JavascriptInterface
    fun onPlaybackEvent(payload: String) {
        onPlaybackEvent(bridge.mapEvent(payload))
    }
}

/**
 * 构建内置 HLS 播放页地址。
 *
 * @param playbackUrl 真实播放地址。
 * @return 带播放地址参数的 asset 页面地址。
 */
internal fun resolveWebViewPlayerUrl(playbackUrl: String): String {
    val encodedUrl = URLEncoder.encode(playbackUrl, Charsets.UTF_8.name())
    return "$HLS_PLAYER_ASSET_URL?url=$encodedUrl"
}

/** WebView 内置 HLS 播放页。 */
internal const val HLS_PLAYER_ASSET_URL = "file:///android_asset/player/hls_player.html"

/** WebView 页面注入的 Android 播放事件桥名称。 */
internal const val WEBVIEW_PLAYER_BRIDGE_NAME = "SeleneAndroidPlayer"

/** WebView 播放链路日志标签。 */
private const val WEBVIEW_PLAYER_LOG_TAG = "SeleneWebViewPlayer"
