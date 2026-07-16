package org.moontechlab.selene.tv.core.design.layout

import android.graphics.Bitmap
import android.graphics.Color as AndroidColor
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 二维码扫码配置区域。
 *
 * 左侧真二维码 + 右侧说明与重新生成按钮；样式对齐设置页表单卡片。
 *
 * @param qrData 二维码内容（通常为局域网配置页 URL）；null 时显示不可用占位。
 * @param statusText 状态说明文案。
 * @param shareAddress 人类可读的扫码地址文案。
 * @param regenerating 是否正在重新生成会话。
 * @param onRegenerateClick “重新生成二维码”按钮回调。
 * @param regenerateFocusRequester 重新生成按钮焦点请求器。
 * @param modifier 外层修饰器。
 */
@Composable
fun TvQrCodeSection(
    qrData: String? = null,
    statusText: String = "手机配置暂不可用",
    shareAddress: String? = null,
    regenerating: Boolean = false,
    onRegenerateClick: () -> Unit = {},
    regenerateFocusRequester: FocusRequester? = null,
    onRegenerateArrowUp: (() -> Unit)? = null,
    onRegenerateArrowDown: (() -> Unit)? = null,
    regenerateModifier: Modifier = Modifier,
    modifier: Modifier = Modifier,
) {
    // 按内容缓存二维码位图，避免每次重组重复编码。
    val qrBitmap = remember(qrData) {
        qrData?.takeIf { it.isNotBlank() }?.let { encodeQrBitmap(it, sizePx = 512) }
    }
    val cardShape = RoundedCornerShape(TvTokens.FormCardRadius)
    val fieldShape = RoundedCornerShape(TvTokens.FormFieldRadius)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(
                color = TvTokens.FormCardBackground,
                shape = cardShape,
            )
            .border(
                width = 1.dp,
                color = TvTokens.FormBorder,
                shape = cardShape,
            )
            .padding(TvTokens.FormPanelPadding),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                modifier = Modifier
                    .padding(top = 3.dp)
                    .width(TvTokens.FormSectionAccentWidth)
                    .height(36.dp)
                    .background(
                        color = TvTokens.Accent,
                        shape = RoundedCornerShape(2.dp),
                    ),
            )
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                androidx.tv.material3.Text(
                    text = "手机扫码配置",
                    color = TvTokens.TextPrimary,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                )
                androidx.tv.material3.Text(
                    text = "与电视同一局域网时，可用手机扫码填写服务器与账号，提交后回填到本页。",
                    color = TvTokens.FormTextSecondary,
                    fontSize = 13.sp,
                    lineHeight = 18.sp,
                )
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(20.dp),
            verticalAlignment = Alignment.Top,
        ) {
            // 左侧二维码卡片
            Column(
                modifier = Modifier
                    .width(228.dp)
                    .background(
                        color = TvTokens.FormFieldBackground,
                        shape = fieldShape,
                    )
                    .border(
                        width = 1.dp,
                        color = TvTokens.FormBorder,
                        shape = fieldShape,
                    )
                    .padding(14.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Box(
                    modifier = Modifier
                        .size(188.dp)
                        .background(Color.White, RoundedCornerShape(12.dp)),
                    contentAlignment = Alignment.Center,
                ) {
                    if (qrBitmap != null) {
                        Image(
                            bitmap = qrBitmap.asImageBitmap(),
                            contentDescription = "手机配置二维码",
                            modifier = Modifier.size(172.dp),
                            contentScale = ContentScale.Fit,
                        )
                    } else {
                        androidx.tv.material3.Text(
                            text = "等待局域网地址",
                            color = TvTokens.FormTextSecondary,
                            fontSize = 13.sp,
                            textAlign = TextAlign.Center,
                        )
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
                androidx.tv.material3.Text(
                    text = if (qrBitmap != null) "使用手机扫码打开配置页" else "等待局域网地址",
                    color = TvTokens.TextPrimary,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.Center,
                )
            }

            // 右侧说明与操作
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                androidx.tv.material3.Text(
                    text = "可在手机编辑",
                    color = TvTokens.TextPrimary,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                )
                androidx.tv.material3.Text(
                    text = "服务器地址、账号、密码、图片代理、自动去广告、弹幕服务器。",
                    color = TvTokens.FormTextSecondary,
                    fontSize = 13.sp,
                    lineHeight = 18.sp,
                )
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            color = TvTokens.FormFieldBackground,
                            shape = fieldShape,
                        )
                        .border(
                            width = 1.dp,
                            color = TvTokens.FormBorder,
                            shape = fieldShape,
                        )
                        .padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    androidx.tv.material3.Text(
                        text = "扫码地址",
                        color = TvTokens.FormTextSecondary,
                        fontSize = 12.sp,
                    )
                    androidx.tv.material3.Text(
                        text = shareAddress?.takeIf { it.isNotBlank() }
                            ?: "当前未生成可供手机访问的局域网地址",
                        color = TvTokens.TextPrimary,
                        fontSize = 14.sp,
                    )
                    androidx.tv.material3.Text(
                        text = statusText,
                        color = TvTokens.FormTextSecondary,
                        fontSize = 12.sp,
                        lineHeight = 16.sp,
                    )
                }
                TvFormActionButton(
                    label = if (regenerating) "生成中..." else "重新生成二维码",
                    onClick = onRegenerateClick,
                    focusRequester = regenerateFocusRequester,
                    accentColor = TvTokens.Accent,
                    onArrowUp = onRegenerateArrowUp,
                    onArrowDown = onRegenerateArrowDown,
                    // 单独锚在按钮上，避免整块二维码区过大导致中部滚动偏差。
                    modifier = regenerateModifier,
                )
            }
        }
    }
}

/**
 * 使用 ZXing 生成二维码位图。
 *
 * @param content 二维码内容。
 * @param sizePx 边长像素。
 * @return 黑白二维码位图；编码失败时返回 null。
 */
fun encodeQrBitmap(content: String, sizePx: Int = 512): Bitmap? {
    return runCatching {
        val hints = mapOf(
            EncodeHintType.CHARACTER_SET to "UTF-8",
            EncodeHintType.MARGIN to 1,
        )
        val matrix = QRCodeWriter().encode(
            content,
            BarcodeFormat.QR_CODE,
            sizePx,
            sizePx,
            hints,
        )
        val width = matrix.width
        val height = matrix.height
        val pixels = IntArray(width * height)
        for (y in 0 until height) {
            val offset = y * width
            for (x in 0 until width) {
                pixels[offset + x] = if (matrix[x, y]) {
                    AndroidColor.BLACK
                } else {
                    AndroidColor.WHITE
                }
            }
        }
        Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { bitmap ->
            bitmap.setPixels(pixels, 0, width, 0, 0, width, height)
        }
    }.getOrNull()
}
