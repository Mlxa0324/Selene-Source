package org.moontechlab.selene.tv.core.player.exo

import android.view.LayoutInflater
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import org.moontechlab.selene.tv.core.player.api.TvResizeMode

/**
 * ExoPlayer 视频画面层。
 *
 * @param exoPlayer 底层 ExoPlayer 实例，空值时保持黑色容器。
 * @param isActive 当前画面层是否拥有播放器视频输出。
 * @param resizeMode 当前画面比例，直接落到 PlayerView。
 * @param engine 可选 Exo 内核，用于绑定画面比例应用器。
 * @param modifier 外层修饰器。
 */
@Composable
fun ExoPlayerSurface(
    exoPlayer: ExoPlayer?,
    isActive: Boolean = true,
    resizeMode: TvResizeMode = TvResizeMode.FIT,
    engine: ExoPlayerEngine? = null,
    modifier: Modifier = Modifier,
) {
    val currentPlayer = rememberUpdatedState(exoPlayer)
    val currentEngine = rememberUpdatedState(engine)
    val currentResizeMode = rememberUpdatedState(resizeMode)
    val playerViewHolder = remember { mutableStateOf<PlayerView?>(null) }
    val playerView = playerViewHolder.value

    LaunchedEffect(exoPlayer, isActive, playerView) {
        val activePlayerView = playerView ?: return@LaunchedEffect
        if (!isActive) {
            // 路由退到后台时先释放旧视频输出，避免两个 PlayerView 同时争抢同一个播放器。
            activePlayerView.player = null
            currentEngine.value?.bindPlayerView(null)
            return@LaunchedEffect
        }
        // 等旧路由完成解绑后再接管视频输出，修复全屏返回详情时声音正常但画面黑屏。
        withFrameNanos { }
        activePlayerView.player = currentPlayer.value
        // 绑定画面比例应用器，菜单切换填充/适应时才能真正生效。
        currentEngine.value?.bindPlayerView(activePlayerView)
        activePlayerView.resizeMode = currentResizeMode.value.toAspectRatioResizeMode()
    }

    // 菜单切换画面比例时即时应用到当前 PlayerView。
    LaunchedEffect(resizeMode, playerView, isActive) {
        if (!isActive) return@LaunchedEffect
        val activePlayerView = playerView ?: return@LaunchedEffect
        activePlayerView.resizeMode = resizeMode.toAspectRatioResizeMode()
    }

    DisposableEffect(Unit) {
        onDispose {
            // 画面层离开组合树时主动解绑 PlayerView，避免旧 surface 继续占着播放器输出。
            currentEngine.value?.bindPlayerView(null)
            playerViewHolder.value?.player = null
            playerViewHolder.value = null
        }
    }

    AndroidView(
        modifier = modifier,
        factory = { context ->
            (LayoutInflater.from(context).inflate(
                R.layout.exo_player_surface_view,
                null,
                false,
            ) as PlayerView).apply {
                // Compose + 平台视频视图组合时优先交给 Media3 PlayerView 管理 surface 生命周期。
                setEnableComposeSurfaceSyncWorkaround(true)
                setKeepContentOnPlayerReset(true)
                useController = false
                // TV 遥控器按键统一由 Compose 播放器壳处理，平台视图不得抢占焦点。
                isFocusable = false
                isFocusableInTouchMode = false
                player = null
                this.resizeMode = currentResizeMode.value.toAspectRatioResizeMode()
                playerViewHolder.value = this
            }
        },
        update = { playerView ->
            playerViewHolder.value = playerView
            if (!isActive && playerView.player != null) {
                // 当前路由失活时立即解绑，新的活跃路由会在下一帧接管播放器输出。
                playerView.player = null
                currentEngine.value?.bindPlayerView(null)
            }
            if (isActive) {
                playerView.resizeMode = currentResizeMode.value.toAspectRatioResizeMode()
            }
        },
    )
}
