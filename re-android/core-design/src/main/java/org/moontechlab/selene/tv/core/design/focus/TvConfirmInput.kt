package org.moontechlab.selene.tv.core.design.focus

import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEvent
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.pointer.pointerInput

/**
 * 判断是否为“确认”类按键。
 *
 * 平板 / 外接键盘场景下，空格与 Enter、方向中心键等价。
 *
 * @param key 原始按键。
 * @return 是否确认键。
 */
fun Key.isTvConfirmKey(): Boolean {
    return this == Key.Enter ||
        this == Key.NumPadEnter ||
        this == Key.DirectionCenter ||
        this == Key.Spacebar
}

/**
 * 判断键盘事件是否属于确认键。
 *
 * @receiver 键盘事件。
 * @return 是否确认键。
 */
fun KeyEvent.isTvConfirmKey(): Boolean = key.isTvConfirmKey()

/**
 * 在 KeyUp 阶段消费确认键并触发业务。
 *
 * 适用于不需要长按区分的按钮 / Chip / 开关。
 *
 * @param event 键盘事件。
 * @param enabled 是否可用。
 * @param onConfirm 确认回调。
 * @return 是否消费该事件。
 */
fun handleTvConfirmKeyUp(
    event: KeyEvent,
    enabled: Boolean = true,
    onConfirm: () -> Unit,
): Boolean {
    if (!enabled || !event.isTvConfirmKey()) {
        return false
    }
    // 仅在抬起时触发，避免 KeyDown + KeyUp 双发。
    if (event.type != KeyEventType.KeyUp) {
        return true
    }
    onConfirm()
    return true
}

/**
 * 为已有 focusable 节点补齐鼠标 / 触摸点击，不额外创建焦点目标。
 *
 * 页面本身可保持滚动与焦点结构不变，只让平板左键点击生效。
 *
 * @param enabled 是否响应点击。
 * @param onClick 点击回调；null 时不挂手势。
 * @return 带 pointer 手势的修饰器。
 */
fun Modifier.tvPointerClickable(
    enabled: Boolean = true,
    onClick: (() -> Unit)?,
): Modifier {
    if (!enabled || onClick == null) {
        return this
    }
    return this.pointerInput(onClick) {
        detectTapGestures(
            onTap = {
                // 鼠标左键与触摸点按统一走业务确认，不改焦点树。
                onClick()
            },
        )
    }
}
