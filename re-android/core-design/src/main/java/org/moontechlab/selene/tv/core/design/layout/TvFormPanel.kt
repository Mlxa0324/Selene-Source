package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 表单分区容器 —— 浮层卡片 + 强调标题条，包裹一组表单行。
 *
 * @param title 分区标题。
 * @param modifier 外层修饰器。
 * @param subtitle 可选副标题，说明该分区用途。
 * @param content 表单行内容，在 [ColumnScope] 中纵向排列。
 */
@Composable
fun TvFormPanel(
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(TvTokens.FormCardRadius)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(
                color = TvTokens.FormCardBackground,
                shape = shape,
            )
            .border(
                width = 1.dp,
                color = TvTokens.FormBorder,
                shape = shape,
            )
            .padding(TvTokens.FormPanelPadding),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                modifier = Modifier
                    .padding(top = 3.dp)
                    .width(TvTokens.FormSectionAccentWidth)
                    .height(if (subtitle.isNullOrBlank()) 18.dp else 36.dp)
                    .background(
                        color = TvTokens.Accent,
                        shape = RoundedCornerShape(2.dp),
                    ),
            )
            Column(
                verticalArrangement = Arrangement.spacedBy(4.dp),
                modifier = Modifier.weight(1f),
            ) {
                Text(
                    text = title,
                    color = TvTokens.TextPrimary,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                )
                if (!subtitle.isNullOrBlank()) {
                    Text(
                        text = subtitle,
                        color = TvTokens.FormTextSecondary,
                        fontSize = 13.sp,
                        lineHeight = 18.sp,
                    )
                }
            }
        }
        content()
    }
}
