package org.moontechlab.selene.tv.core.design.focus

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusProperties
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 端可获焦卡片容器。
 *
 * @param modifier 外层修饰器。
 * @param focusRequesters 绑定到真实焦点节点的请求器列表。
 * @param enabled 是否允许获得焦点。
 * @param onPressed 确认键短按或鼠标点击回调。
 * @param onLongPressed 确认键长按、菜单键或鼠标长按回调。
 * @param focusProperties 可选方向键焦点图（网格同列就近等），挂在真实 focusable 上。
 * @param onPreviewKey 可选按键预览（先于确认键逻辑）；返回 true 表示已消费。
 * @param content 卡片内容。
 */
@Composable
fun TvFocusableCard(
    modifier: Modifier = Modifier,
    focusRequesters: List<FocusRequester> = emptyList(),
    enabled: Boolean = true,
    onPressed: (() -> Unit)? = null,
    onLongPressed: (() -> Unit)? = null,
    focusProperties: (FocusProperties.() -> Unit)? = null,
    onPreviewKey: ((androidx.compose.ui.input.key.KeyEvent) -> Boolean)? = null,
    content: @Composable () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val shape = RoundedCornerShape(TvTokens.CardRadius)
    val borderColor = if (isFocused) TvTokens.FocusBorder else Color.Transparent
    val pressPolicy = remember(onLongPressed) {
        TvRemotePressPolicy(hasLongPressHandler = onLongPressed != null)
    }
    // 仅叠加 focusRequester，初始用 Modifier 避免把外层 modifier 叠两次。
    var focusRequesterModifier: Modifier = Modifier
    focusRequesters.forEach { requester ->
        focusRequesterModifier = focusRequesterModifier.focusRequester(requester)
    }
    Box(
        modifier = modifier
            .clip(shape)
            .border(
                border = BorderStroke(TvTokens.FocusBorderWidth, borderColor),
                shape = shape,
            )
            .onPreviewKeyEvent { event ->
                // 业务侧可先消费方向键（如首项左出回键盘），再落到确认键逻辑。
                if (onPreviewKey?.invoke(event) == true) {
                    return@onPreviewKeyEvent true
                }
                if (!enabled) {
                    return@onPreviewKeyEvent false
                }
                // 菜单键：与确认键长按等价，用于删除等二次操作。
                if (onLongPressed != null && event.key.isTvMenuKey()) {
                    if (event.type == KeyEventType.KeyUp) {
                        onLongPressed.invoke()
                    }
                    return@onPreviewKeyEvent true
                }
                // 空格 / Enter / 方向中心键统一作为确认，适配平板外接键盘。
                if (!event.key.isTvConfirmKey()) {
                    return@onPreviewKeyEvent false
                }
                val action = when (event.type) {
                    KeyEventType.KeyDown -> pressPolicy.onKeyDown(
                        isRepeat = pressPolicy.isPressing,
                    )
                    KeyEventType.KeyUp -> pressPolicy.onKeyUp()
                    else -> TvRemotePressAction.None
                }
                when (action) {
                    TvRemotePressAction.ShortPress -> onPressed?.invoke()
                    TvRemotePressAction.LongPress -> onLongPressed?.invoke()
                    TvRemotePressAction.None -> Unit
                }
                true
            }
            // 鼠标左键 / 触摸点击与确认键等价；长按与菜单键等价。
            .tvPointerClickable(
                enabled = enabled,
                onClick = onPressed,
                onLongClick = onLongPressed,
            )
            .then(
                if (focusProperties != null) {
                    // 方向键邻居必须挂在 focusable 之前的同一焦点目标上。
                    Modifier.focusProperties(focusProperties)
                } else {
                    Modifier
                },
            )
            .then(focusRequesterModifier)
            .focusable(
                enabled = enabled,
                interactionSource = interactionSource,
            ),
    ) {
        // 内容层由业务卡片自行控制尺寸与图片加载。
        content()
    }
}
