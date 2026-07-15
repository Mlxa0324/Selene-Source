package org.moontechlab.selene.tv.core.design.focus

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEvent
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 边界抖动方向（对齐 Flutter [TvEdgeShake]）。
 */
enum class TvEdgeShakeDirection {
    Left,
    Right,
    Up,
    Down,
}

/**
 * TV 边界抖动状态。
 *
 * 遥控器已到列表/控件边缘时，对当前获焦项做轻微方向位移反馈，表示「到底了」。
 * 动画与冷却对齐 Flutter：`320ms` 抖动 + `520ms` 冷却（防长按连抖）。
 *
 * @param scope 动画协程作用域。
 * @param density 用于把 dp 振幅转成像素。
 */
@Stable
class TvEdgeShakeState(
    private val scope: CoroutineScope,
    private val density: Density,
) {
    /** 当前 X 位移（px）。 */
    var translationX by mutableFloatStateOf(0f)
        private set

    /** 当前 Y 位移（px）。 */
    var translationY by mutableFloatStateOf(0f)
        private set

    private var canShake: Boolean = true
    private var animJob: Job? = null

    /**
     * 按指定方向播放边界抖动。
     *
     * @param direction 抖动方向（向外再回弹）。
     */
    fun shake(direction: TvEdgeShakeDirection) {
        if (!canShake) {
            return
        }
        canShake = false
        animJob?.cancel()
        animJob = scope.launch {
            val peakPx = with(density) { PeakAmplitudeDp.toPx() }
            val midPx = with(density) { MidAmplitudeDp.toPx() }
            val settlePx = with(density) { SettleAmplitudeDp.toPx() }
            val signX = when (direction) {
                TvEdgeShakeDirection.Left -> -1f
                TvEdgeShakeDirection.Right -> 1f
                else -> 0f
            }
            val signY = when (direction) {
                TvEdgeShakeDirection.Up -> -1f
                TvEdgeShakeDirection.Down -> 1f
                else -> 0f
            }
            val anim = Animatable(0f)
            try {
                // 0 → peak
                anim.animateTo(
                    targetValue = peakPx,
                    animationSpec = tween(
                        durationMillis = (AnimationMs * 0.24f).toInt(),
                        easing = LinearOutSlowInEasing,
                    ),
                ) {
                    applyOffset(value, signX, signY)
                }
                // peak → -mid
                anim.animateTo(
                    targetValue = -midPx,
                    animationSpec = tween(
                        durationMillis = (AnimationMs * 0.30f).toInt(),
                        easing = FastOutSlowInEasing,
                    ),
                ) {
                    applyOffset(value, signX, signY)
                }
                // -mid → settle
                anim.animateTo(
                    targetValue = settlePx,
                    animationSpec = tween(
                        durationMillis = (AnimationMs * 0.24f).toInt(),
                        easing = FastOutSlowInEasing,
                    ),
                ) {
                    applyOffset(value, signX, signY)
                }
                // settle → 0
                anim.animateTo(
                    targetValue = 0f,
                    animationSpec = tween(
                        durationMillis = (AnimationMs * 0.22f).toInt(),
                        easing = LinearOutSlowInEasing,
                    ),
                ) {
                    applyOffset(value, signX, signY)
                }
            } finally {
                translationX = 0f
                translationY = 0f
                val remaining = (CooldownMs - AnimationMs).coerceAtLeast(0L)
                if (remaining > 0L) {
                    delay(remaining)
                }
                canShake = true
            }
        }
    }

    private fun applyOffset(magnitude: Float, signX: Float, signY: Float) {
        translationX = magnitude * signX
        translationY = magnitude * signY
    }

    /**
     * 若方向键撞到已关闭的边界，则抖动并消费该按键（含 KeyUp）。
     *
     * @param event 原始按键事件。
     * @param left 左边界（再按左应抖）。
     * @param right 右边界。
     * @param up 上边界。
     * @param down 下边界。
     * @return true 表示已处理（调用方应消费事件）。
     */
    fun consumeBoundaryKey(
        event: KeyEvent,
        left: Boolean = false,
        right: Boolean = false,
        up: Boolean = false,
        down: Boolean = false,
    ): Boolean {
        val direction = when (event.key) {
            Key.DirectionLeft -> if (left) TvEdgeShakeDirection.Left else null
            Key.DirectionRight -> if (right) TvEdgeShakeDirection.Right else null
            Key.DirectionUp -> if (up) TvEdgeShakeDirection.Up else null
            Key.DirectionDown -> if (down) TvEdgeShakeDirection.Down else null
            else -> null
        } ?: return false
        if (event.type == KeyEventType.KeyDown) {
            shake(direction)
        }
        // KeyDown + KeyUp 都消费，避免松键再触发系统焦点搜索。
        return event.type == KeyEventType.KeyDown || event.type == KeyEventType.KeyUp
    }

    companion object {
        /** 抖动动画时长（对齐 Flutter）。 */
        const val AnimationMs: Long = 320L

        /** 重复触发冷却（对齐 Flutter）。 */
        const val CooldownMs: Long = 520L

        private val PeakAmplitudeDp = 8.dp
        private val MidAmplitudeDp = 6.dp
        private val SettleAmplitudeDp = 4.dp
    }
}

/**
 * 记住边界抖动状态（随 density 重建振幅换算）。
 */
@Composable
fun rememberTvEdgeShakeState(): TvEdgeShakeState {
    val scope = rememberCoroutineScope()
    val density = LocalDensity.current
    return remember(density) {
        TvEdgeShakeState(scope = scope, density = density)
    }
}

/**
 * 将 [TvEdgeShakeState] 的位移应用到 [graphicsLayer]。
 */
fun Modifier.tvEdgeShake(state: TvEdgeShakeState): Modifier {
    return graphicsLayer {
        translationX = state.translationX
        translationY = state.translationY
    }
}

/**
 * 显式方向键回调 + 左右边界抖动。
 *
 * 有回调则移动；左右无回调时抖动（列表首/末）。上下无回调默认不抖，交给系统/外层。
 *
 * @param event 按键事件。
 * @param edgeShake 抖动状态。
 * @param onArrowLeft 左键回调；null 且 [shakeOnNullLeft] 时抖动。
 * @param onArrowRight 右键回调。
 * @param onArrowUp 上键回调。
 * @param onArrowDown 下键回调。
 * @param shakeOnNullLeft 左回调为 null 时是否抖动。
 * @param shakeOnNullRight 右回调为 null 时是否抖动。
 * @param shakeOnNullUp 上回调为 null 时是否抖动。
 * @param shakeOnNullDown 下回调为 null 时是否抖动。
 * @param onBoundaryKey 任意边界方向 KeyDown 时额外回调（如续约菜单）。
 * @return true 表示方向键已处理。
 */
fun consumeDirectionalKeyWithEdgeShake(
    event: KeyEvent,
    edgeShake: TvEdgeShakeState,
    onArrowLeft: (() -> Unit)?,
    onArrowRight: (() -> Unit)?,
    onArrowUp: (() -> Unit)?,
    onArrowDown: (() -> Unit)?,
    shakeOnNullLeft: Boolean = true,
    shakeOnNullRight: Boolean = true,
    shakeOnNullUp: Boolean = false,
    shakeOnNullDown: Boolean = false,
    onBoundaryKey: (() -> Unit)? = null,
): Boolean {
    val handler = when (event.key) {
        Key.DirectionLeft -> onArrowLeft
        Key.DirectionRight -> onArrowRight
        Key.DirectionUp -> onArrowUp
        Key.DirectionDown -> onArrowDown
        else -> return false
    }
    if (handler != null) {
        if (event.type == KeyEventType.KeyDown) {
            handler.invoke()
        }
        return true
    }
    val shouldShake = when (event.key) {
        Key.DirectionLeft -> shakeOnNullLeft
        Key.DirectionRight -> shakeOnNullRight
        Key.DirectionUp -> shakeOnNullUp
        Key.DirectionDown -> shakeOnNullDown
        else -> false
    }
    if (!shouldShake) {
        return false
    }
    if (event.type == KeyEventType.KeyDown) {
        onBoundaryKey?.invoke()
    }
    return edgeShake.consumeBoundaryKey(
        event = event,
        left = event.key == Key.DirectionLeft,
        right = event.key == Key.DirectionRight,
        up = event.key == Key.DirectionUp,
        down = event.key == Key.DirectionDown,
    )
}
