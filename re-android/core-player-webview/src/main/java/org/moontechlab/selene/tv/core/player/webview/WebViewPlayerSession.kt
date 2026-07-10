package org.moontechlab.selene.tv.core.player.webview

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.webkit.ConsoleMessage
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import java.util.concurrent.atomic.AtomicReference
import org.moontechlab.selene.tv.core.design.threading.DispatcherProvider
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest

/**
 * WebView 播放会话。
 *
 * 这个会话负责把“播放器引擎”和“真实 WebView 页面实例”绑到同一个生命周期里，
 * 从而支持详情页和全屏页之间复用同一份 WebView 播放页，减少切页面时的重载感。
 *
 * @property commandBus 播放命令总线。
 * @property engine 绑定同一命令总线的播放内核。
 */
class WebViewPlayerSession(
    dispatchers: DispatcherProvider,
) {
    /** WebView 页面命令总线。 */
    val commandBus: WebViewPlayerCommandBus = WebViewPlayerCommandBus()

    /** WebView 播放内核。 */
    val engine: WebViewPlayerEngine = WebViewPlayerEngine(
        dispatchers = dispatchers,
        commandBus = commandBus,
    )

    /** JS 桥接器，负责把页面真实状态回灌给播放器内核。 */
    private val playbackBridge = WebViewPlayerJavascriptBridge()

    /** 当前缓存的唯一 WebView 实例。 */
    private var webView: WebView? = null

    /**
     * 绑定当前播放事件回调。
     *
     * @param callback 当前活跃页面需要接收的播放事件回调。
     */
    fun bindPlaybackEventCallback(callback: ((WebViewPlaybackEvent) -> Unit)?) {
        playbackBridge.updatePlaybackEventCallback(callback)
    }

    /**
     * 获取可复用的 WebView 实例。
     *
     * @param context Android 上下文。
     * @return 已配置好的唯一 WebView。
     */
    fun obtainWebView(context: Context): WebView {
        webView?.let { cachedWebView ->
            return cachedWebView
        }
        return WebView(context).apply {
            // TV WebView 播放 HLS 需要脚本和免手势起播，遥控器控制仍由 Compose 壳接管。
            settings.javaScriptEnabled = true
            settings.mediaPlaybackRequiresUserGesture = false
            settings.domStorageEnabled = true
            // 内置 asset 播放页需要访问远端 m3u8 和分片资源。
            settings.allowUniversalAccessFromFileURLs = true
            settings.allowFileAccessFromFileURLs = true
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
            setBackgroundColor(android.graphics.Color.BLACK)
            // TV 设备 WebView 视频需要显式硬件加速层，否则有声音无画面。
            setLayerType(View.LAYER_TYPE_HARDWARE, null)
            // 播放器按键统一由 Compose 壳处理，WebView 不得抢占遥控器或键盘焦点。
            isFocusable = false
            isFocusableInTouchMode = false
            isClickable = false
            // JS 桥始终注入，真正是否分发由桥内部回调引用决定，避免首次为 null 时后续无法补挂。
            addJavascriptInterface(playbackBridge, WEBVIEW_PLAYER_BRIDGE_NAME)
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
            webView = this
        }
    }

    /**
     * 将复用中的 WebView 从旧父容器拆下。
     */
    fun detachFromParent() {
        (webView?.parent as? ViewGroup)?.removeView(webView)
    }

    /**
     * 根据播放请求刷新 WebView 播放页地址。
     *
     * @param playbackRequest 当前播放请求。
     */
    fun attachPlaybackRequest(playbackRequest: PlaybackRequest?) {
        val playbackUrl = playbackRequest?.url.orEmpty()
        if (playbackUrl.isBlank()) {
            return
        }
        val targetUrl = resolveWebViewPlayerUrl(playbackUrl)
        val currentWebView = webView ?: return
        if (currentWebView.url != targetUrl) {
            // 只有播放地址变化时才重载页面，详情页与全屏页切换不应打断同一地址播放。
            currentWebView.loadUrl(targetUrl)
        }
    }

    /**
     * 共享 WebView 重新挂到活跃页面后恢复渲染状态。
     *
     * 该操作只恢复平台视图绘制，不改变视频的播放或暂停状态。
     */
    fun resumeRendering() {
        webView?.apply {
            visibility = View.VISIBLE
            onResume()
            requestLayout()
            postInvalidateOnAnimation()
        }
    }

    /**
     * 向复用的 WebView 播放页下发控制命令。
     *
     * @param command 待执行命令。
     */
    fun evaluateCommand(command: WebViewPlayerCommand) {
        webView?.evaluateJavascript(command.toJavaScript(), null)
    }

    /**
     * 释放会话持有的 WebView 和播放器内核。
     */
    suspend fun release() {
        detachFromParent()
        webView?.destroy()
        webView = null
        engine.release()
    }
}

/**
 * WebView 页面到原生播放器状态的 JS 桥。
 *
 * @property bridge JSON 播放事件映射器。
 * @property mainHandler 主线程切换器。
 */
private class WebViewPlayerJavascriptBridge(
    private val bridge: WebViewPlayerBridge = WebViewPlayerBridge(),
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
) {
    /** 当前播放事件回调引用。 */
    private val playbackEventCallbackRef = AtomicReference<((WebViewPlaybackEvent) -> Unit)?>(null)

    /**
     * 更新当前播放事件回调。
     *
     * @param callback 最新回调；传空时只保留日志不再继续分发。
     */
    fun updatePlaybackEventCallback(callback: ((WebViewPlaybackEvent) -> Unit)?) {
        playbackEventCallbackRef.set(callback)
    }

    /**
     * 接收内置播放页上报的播放事件。
     *
     * @param payload 播放页序列化后的 JSON 字符串。
     */
    @JavascriptInterface
    fun onPlaybackEvent(payload: String) {
        val playbackEvent = runCatching {
            bridge.mapEvent(payload)
        }.onFailure { throwable ->
            // 先记下原始 payload 片段，避免 WebView 只抛 “Java exception was raised” 无法继续定位。
            Log.e(
                WEBVIEW_PLAYER_LOG_TAG,
                "failed to map playback event payload=${payload.toPayloadPreview()}",
                throwable,
            )
        }.getOrNull() ?: return

        // WebView JS 接口运行在私有后台线程，真正的状态分发必须切回主线程，避免直接读写 Compose/播放器 UI 状态。
        mainHandler.post {
            runCatching {
                playbackEventCallbackRef.get()?.invoke(playbackEvent)
            }.onFailure { throwable ->
                Log.e(
                    WEBVIEW_PLAYER_LOG_TAG,
                    "failed to dispatch playback event payload=${payload.toPayloadPreview()}",
                    throwable,
                )
            }
        }
    }
}

/**
 * 将播放事件 payload 裁成适合日志排障的短文本。
 *
 * @return 单行 payload 预览。
 */
private fun String.toPayloadPreview(): String {
    return replace('\n', ' ')
        .replace('\r', ' ')
        .take(PAYLOAD_PREVIEW_MAX_LENGTH)
}

/** WebView 播放链路日志标签。 */
internal const val WEBVIEW_PLAYER_LOG_TAG = "SeleneWebViewPlayer"

/** 日志里最多保留的 payload 预览长度。 */
private const val PAYLOAD_PREVIEW_MAX_LENGTH = 240
