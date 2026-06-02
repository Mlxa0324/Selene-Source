package org.moontechlab.selene.tv.feature.player

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 全屏播放器路由。
 *
 * @param viewModel 播放器 ViewModel。
 */
@Composable
fun TvPlayerRoute(
    viewModel: TvPlayerViewModel = TvPlayerViewModel(),
) {
    val state by viewModel.state.collectAsState()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(36.dp),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    color = TvTokens.Surface.copy(alpha = 0.34f),
                    shape = RoundedCornerShape(18.dp),
                ),
            contentAlignment = Alignment.Center,
        ) {
            // 当前 Kotlin 壳还未接入真实画面，先保留沉浸式播放画布。
            Text(
                text = "IvyTV",
                style = MaterialTheme.typography.headlineMedium,
                color = Color.White.copy(alpha = 0.72f),
            )
        }

        Column(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                TvPlayerMenuChip(
                    label = PLAYER_MENU_PLAYLIST,
                    onClick = { viewModel.openMenu(PLAYER_MENU_PLAYLIST) },
                )
                TvPlayerMenuChip(
                    label = PLAYER_MENU_OTHER,
                    modifier = Modifier.testTag("tv-player-menu-other"),
                    onClick = { viewModel.openMenu(PLAYER_MENU_OTHER) },
                )
            }
            if (state.isMenuVisible && state.selectedTopMenu == PLAYER_MENU_OTHER) {
                // 其它菜单首期保留既有内核切换文案，视觉上作为二级控制项展示。
                TvPlayerMenuChip(
                    label = state.selectedOtherMenuItem,
                    selected = true,
                    onClick = {},
                )
            }
        }
    }
}

/**
 * TV 全屏播放器控制菜单按钮。
 *
 * @param label 菜单文案。
 * @param modifier 外层修饰器。
 * @param selected 是否为当前二级选中项。
 * @param onClick 点击回调。
 */
@Composable
private fun TvPlayerMenuChip(
    label: String,
    modifier: Modifier = Modifier,
    selected: Boolean = false,
    onClick: () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val shape = RoundedCornerShape(10.dp)
    val backgroundColor = when {
        selected -> TvTokens.Accent
        isFocused -> TvTokens.FocusFill
        else -> TvTokens.Surface.copy(alpha = 0.88f)
    }

    Box(
        modifier = modifier
            .height(46.dp)
            .widthIn(min = 108.dp)
            .clip(shape)
            .background(backgroundColor)
            .border(
                width = 2.dp,
                color = if (isFocused) TvTokens.FocusBorder else Color.Transparent,
                shape = shape,
            )
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick,
            )
            .focusable(interactionSource = interactionSource)
            .padding(horizontal = 18.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.titleMedium,
            color = Color.White,
        )
    }
}
