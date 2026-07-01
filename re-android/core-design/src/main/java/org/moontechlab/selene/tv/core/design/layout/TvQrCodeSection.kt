package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 二维码区域 —— 简化版占位。
 *
 * 默认显示"手机配置暂不可用"占位。后续可通过 [qrData] 传入真正二维码。
 *
 * @param qrData 二维码数据，为 null 时显示占位文案。
 * @param statusText 状态说明文案。
 * @param onRegenerateClick "重新生成"按钮回调，当前预留无操作。
 * @param modifier 外层修饰器。
 */
@Composable
fun TvQrCodeSection(
    qrData: String? = null,
    statusText: String = "手机配置暂不可用",
    onRegenerateClick: () -> Unit = {},
    modifier: Modifier = Modifier,
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
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // 二维码占位区
        Box(
            modifier = Modifier
                .size(160.dp)
                .background(
                    color = TvTokens.FormFieldBackground,
                    shape = RoundedCornerShape(TvTokens.CardRadius),
                )
                .border(
                    width = 1.dp,
                    color = TvTokens.FormBorder,
                    shape = RoundedCornerShape(TvTokens.CardRadius),
                ),
            contentAlignment = Alignment.Center,
        ) {
            if (qrData != null) {
                // 后续可接入二维码图片组件
                androidx.tv.material3.Text(
                    text = "[QR]",
                    color = TvTokens.FormTextSecondary,
                    fontSize = 14.sp,
                )
            } else {
                androidx.tv.material3.Text(
                    text = "暂不可用",
                    color = TvTokens.FormTextSecondary,
                    fontSize = 14.sp,
                    textAlign = TextAlign.Center,
                )
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        androidx.tv.material3.Text(
            text = statusText,
            color = TvTokens.FormTextSecondary,
            fontSize = 13.sp,
            textAlign = TextAlign.Center,
        )

        Spacer(modifier = Modifier.height(16.dp))

        TvFormActionButton(
            label = "重新生成",
            onClick = onRegenerateClick,
            accentColor = TvTokens.FormBorder,
        )
    }
}
