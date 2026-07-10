package uk.oxiang.ivy.tv.core.player.webview

import uk.oxiang.ivy.tv.core.design.util.DispatcherProvider

/**
 * WebView 播放会话。
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
}
