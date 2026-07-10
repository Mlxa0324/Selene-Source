package uk.oxiang.ivy.tv.core.design.layout

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import uk.oxiang.ivy.tv.core.design.TvTokens

/**
 * TV 表单只读标签-值行。
 *
 * @param label 左侧标签文案。
 * @param value 右侧值文案。
 * @param modifier 外层修饰器。
 */
@Composable
fun TvFormValueRow(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(TvTokens.FormRowHeight)
            .background(
                color = TvTokens.FormFieldBackground,
                shape = RoundedCornerShape(TvTokens.CardRadius),
            )
            .border(
                width = 1.dp,
                color = TvTokens.FormBorder,
                shape = RoundedCornerShape(TvTokens.CardRadius),
            )
            .padding(horizontal = TvTokens.FormRowHorizontalPadding),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            color = TvTokens.FormTextSecondary,
            fontSize = 15.sp,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = value,
            color = TvTokens.TextPrimary,
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium,
        )
    }
}
