package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.background
import androidx.compose.ui.unit.dp
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 页面公共壳。
 *
 * @param title 页面主标题。
 * @param subtitle 页面副标题。
 * @param stats 页面头部统计项。
 * @param modifier 外层修饰器。
 * @param content 页面主体内容。
 */
@Composable
fun TvPageScaffold(
    title: String,
    subtitle: String? = null,
    stats: List<TvPageStatChipData> = emptyList(),
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    androidx.compose.foundation.layout.Box(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(
                    start = TvTokens.PageHorizontalPadding,
                    top = TvTokens.PageTopPadding,
                    end = TvTokens.PageHorizontalPadding,
                    bottom = TvTokens.PageBottomPadding,
                ),
            verticalArrangement = Arrangement.spacedBy(TvTokens.SectionSpacing),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.headlineMedium,
                )
                if (!subtitle.isNullOrBlank()) {
                    // 副标题用于收口页面语义，避免只剩一个冷冰冰的大标题。
                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                if (stats.isNotEmpty()) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        stats.forEach { stat ->
                            TvPageStatChip(
                                label = stat.label,
                                value = stat.value,
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(2.dp))
            content()
        }
    }
}
