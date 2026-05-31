package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.runtime.Composable
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
    LazyVerticalGrid(
        columns = GridCells.Fixed(columns),
        modifier = modifier,
        contentPadding = PaddingValues(
            start = TvTokens.PageHorizontalPadding,
            end = TvTokens.PageHorizontalPadding,
            bottom = TvTokens.PageBottomPadding,
        ),
        verticalArrangement = Arrangement.spacedBy(TvTokens.CardSpacing),
        horizontalArrangement = Arrangement.spacedBy(TvTokens.CardSpacing),
    ) {
        items(items, key = TvPosterItem::id) { item ->
            TvPosterCard(
                item = item,
                onClick = onItemClick?.let { click -> { click(item) } },
            )
        }
    }
}
