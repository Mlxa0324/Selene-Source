package uk.oxiang.ivy.tv.core.design.focus

/**
 * TV 遥控器确认键触发结果。
 */
enum class TvRemotePressAction {
    /**
     * 当前按键事件只消费状态，不触发业务。
     */
    None,

    /**
     * 触发一次短按确认。
     */
    ShortPress,

    /**
     * 触发一次长按确认。
     */
    LongPress,
}

/**
 * TV 遥控器确认键短按、长按和重复事件策略。
 *
 * 对齐 Flutter `TvFocusable` 的确认键判定：`KeyDown` 记录按压键，
 * `KeyRepeat` 长按只触发一次，`KeyUp` 未触发长按才回落短按，防止一次物理
 * 按压重复触发业务。
 *
 * @property hasLongPressHandler 当前控件是否提供长按业务。
 */
class TvRemotePressPolicy(
    private val hasLongPressHandler: Boolean,
) {
    /**
     * 当前是否已经收到按下事件。
     */
    private var isPressed = false

    /**
     * 当前物理按压是否还未抬起。
     */
    val isPressing: Boolean
        get() = isPressed

    /**
     * 当前物理按压是否已经触发过长按。
     */
    private var didLongPress = false

    /**
     * 处理确认键按下或重复事件。
     *
     * @param isRepeat 是否为系统重复按键事件。
     * @return 本次事件对应的业务动作。
     */
    fun onKeyDown(isRepeat: Boolean): TvRemotePressAction {
        if (!isRepeat) {
            isPressed = true
            didLongPress = false
            return TvRemotePressAction.None
        }
        if (!isPressed || didLongPress || !hasLongPressHandler) {
            return TvRemotePressAction.None
        }
        didLongPress = true
        return TvRemotePressAction.LongPress
    }

    /**
     * 处理确认键抬起事件。
     *
     * @return 本次事件对应的业务动作。
     */
    fun onKeyUp(): TvRemotePressAction {
        if (!isPressed) {
            return TvRemotePressAction.None
        }
        val action = if (didLongPress) {
            TvRemotePressAction.None
        } else {
            TvRemotePressAction.ShortPress
        }
        isPressed = false
        didLongPress = false
        return action
    }
}
