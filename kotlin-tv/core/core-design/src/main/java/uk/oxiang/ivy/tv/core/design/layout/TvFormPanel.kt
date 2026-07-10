package uk.oxiang.ivy.tv.core.design.layout

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import uk.oxiang.ivy.tv.core.design.TvTokens

/**
 * TV 表单分区容器 —— 深色卡片带标题，包裹一组表单行。
 *
 * @param title 分区标题。
 * @param modifier 外层修饰器。
 * @param content 表单行内容，在 [ColumnScope] 中纵向排列。
 */
@Composable
fun TvFormPanel(
    title: String,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(
                color = TvTokens.FormCardBackground,
                shape = RoundedCornerShape(TvTokens.CardRadius),
            )
            .border(
                width = 1.dp,
                color = TvTokens.FormBorder,
                shape = RoundedCornerShape(TvTokens.CardRadius),
            )
            .padding(TvTokens.FormPanelPadding),
        verticalArrangement = Arrangement.spacedBy(0.dp),
    ) {
        Text(
            text = title,
            color = TvTokens.TextPrimary,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(bottom = 18.dp),
        )
        content()
    }
}
