package uk.oxiang.ivy.tv.core.design.layout

import android.graphics.Bitmap
import androidx.compose.foundation.Image
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uk.oxiang.ivy.tv.core.design.LocalTvThemePalette
import uk.oxiang.ivy.tv.core.design.TvTokens

/**
 * TV 手机扫码配置区域 —— 渲染真实二维码。
 *
 * 精确对齐 Flutter `_buildMobileConfigQrCard`（`lib/tv_app/screens/tv_settings_screen.dart`）
 * 的视觉：白底 220dp 二维码卡片 + 状态文案 + "重新生成"按钮。
 * `core-design` 只负责渲染调用方（`feature-settings`）用 ZXing 生成好的 [Bitmap]，
 * 不引入 ZXing 依赖，避免 UI 组件层耦合业务生成逻辑。
 *
 * @param qrBitmap 二维码位图；为 null 时显示占位提示（例如局域网地址未就绪）。
 * @param statusText 二维码下方状态说明文案。
 * @param onRegenerateClick "重新生成"按钮回调。
 * @param modifier 外层修饰器。
 */
@Composable
fun TvQrCodeSection(
    qrBitmap: Bitmap?,
    statusText: String,
    onRegenerateClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val palette = LocalTvThemePalette.current
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(
                color = TvTokens.FormCardBackground,
                shape = RoundedCornerShape(10.dp),
            )
            .border(
                width = 1.dp,
                color = TvTokens.FormBorder,
                shape = RoundedCornerShape(10.dp),
            )
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .size(220.dp)
                .background(color = Color.White, shape = RoundedCornerShape(12.dp)),
            contentAlignment = Alignment.Center,
        ) {
            if (qrBitmap != null) {
                Image(
                    bitmap = qrBitmap.asImageBitmap(),
                    contentDescription = "手机配置二维码",
                    modifier = Modifier.size(204.dp),
                )
            } else {
                androidx.tv.material3.Text(
                    text = "等待局域网地址",
                    color = palette.disabledFill,
                    fontSize = 14.sp,
                    textAlign = TextAlign.Center,
                )
            }
        }

        Spacer(modifier = Modifier.height(14.dp))

        androidx.tv.material3.Text(
            text = statusText,
            color = Color.White,
            fontSize = 15.sp,
            textAlign = TextAlign.Center,
        )

        Spacer(modifier = Modifier.height(16.dp))

        TvFormActionButton(
            label = "重新生成二维码",
            onClick = onRegenerateClick,
        )
    }
}
