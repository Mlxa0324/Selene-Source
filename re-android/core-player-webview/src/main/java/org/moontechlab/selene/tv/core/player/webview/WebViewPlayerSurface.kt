package org.moontechlab.selene.tv.core.player.webview

import android.graphics.Color
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import java.net.URLEncoder

/**
 * WebView 播放器画面层。
 *
 * @param session WebView 共享播放会话。
 * @param playbackRequest 当前播放请求，空值时保持黑色视频容器。
 * @param isActive 当前画面层是否拥有共享 WebView。
 * @param modifier 外层修饰器。
 */
@Composable
fun WebViewPlayerSurface(
    session: WebViewPlayerSession?,
    playbackRequest: PlaybackRequest?,
    isActive: Boolean = true,
    modifier: Modifier = Modifier,
) {
    if (session == null) {
        return
    }

    LaunchedEffect(session, isActive) {
        if (isActive) {
            // 只有当前活跃页面负责接收共享 WebView 的真实播放事件。
            session.bindPlaybackEventCallback(session.engine::updateFromWebView)
        }
    }

    LaunchedEffect(session, isActive) {
        if (isActive) {
            // 避免导航过渡期间详情页和全屏页重复消费同一条播放器命令。
            session.commandBus.commands.collect { command ->
                session.evaluateCommand(command)
            }
        }
    }

    AndroidView(
        modifier = modifier,
        factory = { context ->
            FrameLayout(context).apply {
                // 每个页面保留独立容器，真正的 WebView 只挂到当前活跃容器。
                setBackgroundColor(Color.BLACK)
                descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
                isFocusable = false
                isFocusableInTouchMode = false
            }
        },
        update = { container ->
            if (!isActive) {
                // 失活页面只能清理自己的容器，不能误拆新页面已经接管的共享 WebView。
                container.removeAllViews()
                return@AndroidView
            }
            val webView = session.obtainWebView(container.context)
            if (webView.parent !== container) {
                // 路由切换时把同一个 WebView 从旧容器迁移到当前容器，不重新加载播放页。
                session.detachFromParent()
                container.removeAllViews()
                container.addView(
                    webView,
                    FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT,
                    ),
                )
            }
            session.attachPlaybackRequest(playbackRequest)
            session.resumeRendering()
        },
    )
}

/**
 * 构建内置 HLS 播放页地址。
 *
 * 注意：不要把 startPositionMs 写进 URL。详情预览进度会持续变化，
 * 若写进 query 会触发 WebView 反复 loadUrl 重载。
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
