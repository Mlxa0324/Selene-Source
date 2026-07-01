package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 页面区块标题和内容容器。
 *
 * @param title 区块标题。
 * @param hint 标题右侧提示。
 * @param modifier 外层修饰器。
 * @param trailing 标题行右侧附加内容。
 * @param insetContent 内容区是否内缩页面水平边距，横向列表应设为 false 以实现边缘滚动。
 * @param content 区块主体内容。
 */
@Composable
fun TvPageSection(
    title: String,
    hint: String? = null,
    modifier: Modifier = Modifier,
    trailing: @Composable (() -> Unit)? = null,
    insetContent: Boolean = true,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = TvTokens.PageHorizontalPadding, end = TvTokens.PageHorizontalPadding),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleLarge,
                    color = TvTokens.TextPrimary,
                )
                if (!hint.isNullOrBlank()) {
                    // 弱提示用于交代区块用途，不抢主标题注意力。
                    Text(
                        text = hint,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            trailing?.invoke()
        }

        // 主体不再包一层面板，避免首页、分类和详情都呈现工程卡片感。
        if (insetContent) {
            Box(modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding)) {
                content()
            }
        } else {
            content()
        }
    }
}
