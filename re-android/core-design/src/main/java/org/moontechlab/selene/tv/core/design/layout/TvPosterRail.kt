package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 横向海报带。
 *
 * @param items 影视卡片列表。
 * @param modifier 外层修饰器。
 * @param onItemClick 卡片点击回调。
 * @param trailingContent 列表尾部附加内容。
 */
@Composable
fun TvPosterRail(
    items: List<TvPosterItem>,
    modifier: Modifier = Modifier,
    onItemClick: ((TvPosterItem) -> Unit)? = null,
    trailingContent: (@Composable () -> Unit)? = null,
) {
    val listState = rememberLazyListState()

    LazyRow(
        modifier = modifier,
        state = listState,
        contentPadding = PaddingValues(
            start = TvListLayoutMetrics.RailStartPadding,
            end = TvListLayoutMetrics.RailEndPadding,
        ),
        horizontalArrangement = Arrangement.spacedBy(TvTokens.CardSpacing),
    ) {
        items(items, key = TvPosterItem::id) { item ->
            TvPosterCard(
                item = item,
                onClick = onItemClick?.let { click -> { click(item) } },
            )
        }
        if (trailingContent != null) {
            item(key = "tv-poster-rail-trailing") {
                // 尾部内容用于查看更多等操作卡片，沿用同一条横向轨道。
                trailingContent()
            }
        }
    }
}
