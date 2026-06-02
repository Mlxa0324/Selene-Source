package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 纵向海报网格。
 *
 * @param items 影视卡片列表。
 * @param columns 每行列数。
 * @param modifier 外层修饰器。
 * @param onItemClick 卡片点击回调。
 */
@Composable
fun TvPosterGrid(
    items: List<TvPosterItem>,
    columns: Int,
    modifier: Modifier = Modifier,
    onItemClick: ((TvPosterItem) -> Unit)? = null,
) {
    val gridState = rememberLazyGridState()

    LazyVerticalGrid(
        columns = GridCells.Fixed(columns),
        modifier = modifier,
        state = gridState,
        contentPadding = PaddingValues(
            start = TvListLayoutMetrics.GridHorizontalPadding,
            end = TvListLayoutMetrics.GridHorizontalPadding,
            bottom = TvListLayoutMetrics.GridBottomPadding,
        ),
        verticalArrangement = Arrangement.spacedBy(TvTokens.CardSpacing),
        horizontalArrangement = Arrangement.spacedBy(TvTokens.CardSpacing),
    ) {
        items(items, key = TvPosterItem::id) { item ->
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.TopCenter,
            ) {
                // 单元格内居中，避免 7 列网格在宽屏上显得左重右轻。
                TvPosterCard(
                    item = item,
                    onClick = onItemClick?.let { click -> { click(item) } },
                )
            }
        }
    }
}
