package org.moontechlab.selene.tv.core.design.dialog

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.window.Dialog
import androidx.tv.material3.Button
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 风格确认弹窗。
 *
 * @param title 弹窗标题。
 * @param message 弹窗说明。
 * @param confirmLabel 确认按钮文案。
 * @param cancelLabel 取消按钮文案。
 * @param onConfirm 确认回调。
 * @param onDismiss 取消或关闭回调。
 */
@Composable
fun TvConfirmDialog(
    title: String,
    message: String,
    confirmLabel: String,
    cancelLabel: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    Dialog(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .background(
                    color = MaterialTheme.colorScheme.surface,
                    shape = RoundedCornerShape(TvTokens.CardRadius),
                )
                .border(
                    width = TvTokens.FocusBorderWidth,
                    color = TvTokens.Outline,
                    shape = RoundedCornerShape(TvTokens.CardRadius),
                )
                .padding(
                    horizontal = TvTokens.DialogHorizontalPadding,
                    vertical = TvTokens.DialogVerticalPadding,
                ),
            verticalArrangement = Arrangement.spacedBy(TvTokens.DialogContentSpacing),
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.headlineSmall,
            )
            Text(
                text = message,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(
                horizontalArrangement = Arrangement.spacedBy(TvTokens.DialogButtonSpacing),
            ) {
                Button(onClick = onDismiss) {
                    Text(text = cancelLabel)
                }
                Button(onClick = onConfirm) {
                    Text(text = confirmLabel)
                }
            }
        }
    }
}
