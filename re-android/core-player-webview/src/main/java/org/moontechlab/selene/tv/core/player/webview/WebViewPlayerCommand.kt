package org.moontechlab.selene.tv.core.player.webview

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import org.moontechlab.selene.tv.core.player.api.TvResizeMode

/**
 * WebView 播放页面命令。
 */
sealed interface WebViewPlayerCommand {
    /** 播放。 */
    data object Play : WebViewPlayerCommand

    /** 暂停。 */
    data object Pause : WebViewPlayerCommand

    /**
     * 跳转播放位置。
     *
     * @property positionMs 目标位置，单位毫秒。
     */
    data class SeekTo(val positionMs: Long) : WebViewPlayerCommand

    /**
     * 设置播放倍速。
     *
     * @property speed 播放倍速。
     */
    data class SetPlaybackSpeed(val speed: Float) : WebViewPlayerCommand

    /**
     * 设置画面比例。
     *
     * @property resizeMode 画面比例。
     */
    data class SetResizeMode(val resizeMode: TvResizeMode) : WebViewPlayerCommand
}

/**
 * WebView 播放命令总线。
 */
class WebViewPlayerCommandBus {
    /** 内部命令流。 */
    private val mutableCommands = MutableSharedFlow<WebViewPlayerCommand>(
        extraBufferCapacity = WEBVIEW_COMMAND_BUFFER_CAPACITY,
    )

    /** 外部只读命令流。 */
    val commands: SharedFlow<WebViewPlayerCommand> = mutableCommands

    /**
     * 发送 WebView 播放命令。
     *
     * @param command 播放命令。
     */
    suspend fun send(command: WebViewPlayerCommand) {
        mutableCommands.emit(command)
    }
}

/**
 * 将 WebView 命令转换为内置页面 JS。
 *
 * @return 可传给 `evaluateJavascript` 的脚本。
 */
internal fun WebViewPlayerCommand.toJavaScript(): String {
    return when (this) {
        WebViewPlayerCommand.Play -> "if(window.selenePlayer){window.selenePlayer.play();}"
        WebViewPlayerCommand.Pause -> "if(window.selenePlayer){window.selenePlayer.pause();}"
        is WebViewPlayerCommand.SeekTo ->
            "if(window.selenePlayer){window.selenePlayer.seekTo($positionMs);}"
        is WebViewPlayerCommand.SetPlaybackSpeed ->
            "if(window.selenePlayer){window.selenePlayer.setPlaybackSpeed($speed);}"
        is WebViewPlayerCommand.SetResizeMode ->
            "if(window.selenePlayer){window.selenePlayer.setResizeMode('${resizeMode.name}');}"
    }
}

/** WebView 命令缓冲容量。 */
private const val WEBVIEW_COMMAND_BUFFER_CAPACITY = 16
