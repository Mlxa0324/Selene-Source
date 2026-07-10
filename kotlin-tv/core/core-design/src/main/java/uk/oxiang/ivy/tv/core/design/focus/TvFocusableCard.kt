package uk.oxiang.ivy.tv.core.design.focus

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.FocusState
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import kotlinx.coroutines.launch
import uk.oxiang.ivy.tv.core.design.TvTokens

/**
 * TV 端可获焦卡片容器。
 *
 * 完整对齐 Flutter `TvFocusable`（`lib/tv_app/widgets/tv_focusable.dart`）的 5 项能力：
 * 1. 确认键短按/长按判定（[TvRemotePressPolicy]）。
 * 2. 焦点记忆分组（[focusMemoryGroupKey]，见 [TvFocusMemoryRegistry]）。
 * 3. 方向键长按节流分组（[directionalRepeatThrottleGroupKey]，见 [TvDirectionalRepeatThrottle]）。
 * 4. 获焦自动滚动（[autoScrollOnFocus]，通过 [BringIntoViewRequester] 实现）。
 * 5. `onFocusedNodeChanged` 只在真正获焦时触发。
 *
 * 各能力通过可选构造参数控制启用范围，不传对应参数则不启用，避免所有卡片/列表
 * 都强制承担全部逻辑开销。
 *
 * @param modifier 外层修饰器。
 * @param focusRequesters 绑定到真实焦点节点的请求器列表。
 * @param enabled 是否允许获得焦点。
 * @param onPressed 确认键短按或鼠标点击回调。
 * @param onLongPressed 确认键长按回调。
 * @param onFocusChanged 焦点变化回调（获焦和失焦都会触发）。
 * @param onFocusedNodeChanged 只在真正获焦（不是失焦）时触发，用于记录"最近停留焦点"。
 * @param focusMemoryGroupKey 焦点记忆分组标识；为空则不启用该能力。
 * @param directionalRepeatThrottleGroupKey 方向键长按节流分组标识；为空则不启用节流。
 * @param autoScrollOnFocus 获焦时是否自动滚动到可见区域。
 * @param showFocusBorder 是否绘制内置焦点描边；海报卡片等需要自绘特定描边+阴影的场景可关闭。
 * @param focusBorderColor 内置焦点描边颜色，默认白色。
 * @param content 卡片内容。
 */
@Composable
fun TvFocusableCard(
    modifier: Modifier = Modifier,
    focusRequesters: List<FocusRequester> = emptyList(),
    enabled: Boolean = true,
    onPressed: (() -> Unit)? = null,
    onLongPressed: (() -> Unit)? = null,
    onFocusChanged: ((Boolean) -> Unit)? = null,
    onFocusedNodeChanged: (() -> Unit)? = null,
    focusMemoryGroupKey: Any? = null,
    directionalRepeatThrottleGroupKey: Any? = null,
    autoScrollOnFocus: Boolean = true,
    showFocusBorder: Boolean = true,
    focusBorderColor: Color = Color.White,
    content: @Composable () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val shape = RoundedCornerShape(TvTokens.CardRadius)
    val borderColor = if (isFocused && showFocusBorder) focusBorderColor else Color.Transparent
    val pressPolicy = remember(onLongPressed) {
        TvRemotePressPolicy(hasLongPressHandler = onLongPressed != null)
    }
    val bringIntoViewRequester = remember { BringIntoViewRequester() }
    val coroutineScope = rememberCoroutineScope()
    var lastCoordinates: LayoutCoordinates? = remember { null }

    // ── 能力 2：焦点记忆分组注册 ──
    val ownFocusRequester = remember { FocusRequester() }
    val allFocusRequesters = remember(focusRequesters) {
        if (focusRequesters.isEmpty()) listOf(ownFocusRequester) else focusRequesters
    }
    val memoryEntry = remember(focusMemoryGroupKey) {
        focusMemoryGroupKey?.let { groupKey ->
            TvFocusMemoryRegistry.Entry(
                groupKey = groupKey,
                focusRequester = allFocusRequesters.first(),
                boundsProvider = { lastCoordinates?.let { coordinates -> coordinates.boundsInWindow() } },
            )
        }
    }
    DisposableEffect(memoryEntry) {
        memoryEntry?.let { entry -> TvFocusMemoryRegistry.register(entry) }
        onDispose {
            memoryEntry?.let { entry ->
                entry.canRequestFocus = false
                TvFocusMemoryRegistry.unregister(entry)
            }
        }
    }

    val focusRequesterModifier: Modifier = allFocusRequesters.fold<FocusRequester, Modifier>(Modifier) { current, requester ->
        // 多个入口共享同一个真实焦点节点，避免外层容器成为不可见中转焦点。
        current.focusRequester(requester)
    }
    val pointerClickModifier = if (enabled && onPressed != null) {
        Modifier.pointerInput(onPressed) {
            detectTapGestures(
                onTap = {
                    // 鼠标和触摸点击只触发业务，不额外创建可获焦节点。
                    onPressed()
                },
            )
        }
    } else {
        Modifier
    }
    val bringIntoViewModifier = if (autoScrollOnFocus) {
        Modifier.bringIntoViewRequester(bringIntoViewRequester)
    } else {
        Modifier
    }

    Box(
        modifier = modifier
            .clip(shape)
            .border(
                border = BorderStroke(TvTokens.FocusBorderWidth, borderColor),
                shape = shape,
            )
            .onGloballyPositioned { coordinates -> lastCoordinates = coordinates }
            .then(bringIntoViewModifier)
            .onPreviewKeyEvent { event ->
                val confirmHandled = handleConfirmKeyEvent(
                    event = event,
                    enabled = enabled,
                    pressPolicy = pressPolicy,
                    onPressed = onPressed,
                    onLongPressed = onLongPressed,
                )
                if (confirmHandled) {
                    return@onPreviewKeyEvent true
                }
                // ── 能力 3：方向键长按节流分组 ──
                if (enabled && directionalRepeatThrottleGroupKey != null) {
                    handleDirectionalRepeatThrottle(
                        event = event,
                        groupKey = directionalRepeatThrottleGroupKey,
                    )
                } else {
                    false
                }
            }
            .then(pointerClickModifier)
            .then(focusRequesterModifier)
            .onFocusChanged { focusState: FocusState ->
                handleFocusChanged(
                    hasFocus = focusState.hasFocus,
                    memoryEntry = memoryEntry,
                    onFocusChanged = onFocusChanged,
                    onFocusedNodeChanged = onFocusedNodeChanged,
                    autoScrollOnFocus = autoScrollOnFocus,
                    coroutineScope = coroutineScope,
                    bringIntoViewRequester = bringIntoViewRequester,
                )
            }
            .focusable(
                enabled = enabled,
                interactionSource = interactionSource,
            ),
    ) {
        // 内容层由业务卡片自行控制尺寸与图片加载。
        content()
    }
}

/**
 * 处理确认键短按/长按判定与方向键长按节流。
 *
 * @return 是否消费该事件。
 */
private fun handleConfirmKeyEvent(
    event: androidx.compose.ui.input.key.KeyEvent,
    enabled: Boolean,
    pressPolicy: TvRemotePressPolicy,
    onPressed: (() -> Unit)?,
    onLongPressed: (() -> Unit)?,
): Boolean {
    if (!enabled) {
        return false
    }
    if (event.key == Key.DirectionCenter || event.key == Key.Enter) {
        val action = when (event.type) {
            KeyEventType.KeyDown -> pressPolicy.onKeyDown(isRepeat = pressPolicy.isPressing)
            KeyEventType.KeyUp -> pressPolicy.onKeyUp()
            else -> TvRemotePressAction.None
        }
        when (action) {
            TvRemotePressAction.ShortPress -> onPressed?.invoke()
            TvRemotePressAction.LongPress -> onLongPressed?.invoke()
            TvRemotePressAction.None -> Unit
        }
        return true
    }
    return false
}

/**
 * 处理真实焦点变化：同步焦点记忆分组、触发获焦回调、发起自动滚动。
 */
private fun handleFocusChanged(
    hasFocus: Boolean,
    memoryEntry: TvFocusMemoryRegistry.Entry?,
    onFocusChanged: ((Boolean) -> Unit)?,
    onFocusedNodeChanged: (() -> Unit)?,
    autoScrollOnFocus: Boolean,
    coroutineScope: kotlinx.coroutines.CoroutineScope,
    bringIntoViewRequester: BringIntoViewRequester,
) {
    if (hasFocus) {
        memoryEntry?.let { entry -> TvFocusMemoryRegistry.onFocused(entry) }
        // 只在真正获焦（不是失焦）时触发，用于记录"最近停留焦点"。
        onFocusedNodeChanged?.invoke()
        if (autoScrollOnFocus) {
            coroutineScope.launch {
                runCatching { bringIntoViewRequester.bringIntoView() }
            }
        }
    } else {
        memoryEntry?.let { entry -> TvFocusMemoryRegistry.onUnfocused(entry) }
    }
    onFocusChanged?.invoke(hasFocus)
}

/**
 * 处理纯文字列表方向键长按节流。
 *
 * 首次方向键仍交给默认焦点系统处理（返回 false），只有过密的重复事件才会被
 * 吞掉（返回 true）。对齐 Flutter `_handleDirectionalRepeatThrottle`。
 *
 * @return 是否消费（吞掉）该方向键事件。
 */
private fun handleDirectionalRepeatThrottle(
    event: androidx.compose.ui.input.key.KeyEvent,
    groupKey: Any,
): Boolean {
    val direction = when (event.key) {
        Key.DirectionUp -> TvDirection.UP
        Key.DirectionDown -> TvDirection.DOWN
        Key.DirectionLeft -> TvDirection.LEFT
        Key.DirectionRight -> TvDirection.RIGHT
        else -> return false
    }
    // Compose `KeyEvent` 目前不区分系统重复事件标记，这里用 KeyDown 视为潜在重复，
    // KeyUp 一律放行，避免节流影响松手判定。
    if (event.type != KeyEventType.KeyDown) {
        return false
    }
    return TvDirectionalRepeatThrottle.shouldThrottle(
        groupKey = groupKey,
        direction = direction,
        isRepeatEvent = true,
        nowNanos = System.nanoTime(),
    )
}
