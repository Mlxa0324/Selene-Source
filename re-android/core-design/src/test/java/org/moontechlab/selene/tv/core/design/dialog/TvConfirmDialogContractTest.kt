package org.moontechlab.selene.tv.core.design.dialog

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验公共 TV 确认弹窗契约。
 */
class TvConfirmDialogContractTest {
    @Test
    fun confirm_dialog_supports_cancel_confirm_and_back_dismiss() {
        val source = File(
            "src/main/java/org/moontechlab/selene/tv/core/design/dialog/TvConfirmDialog.kt",
        ).readText()

        assertThat(source).contains("fun TvConfirmDialog(")
        assertThat(source).contains("testTag(\"tv-confirm-dialog\")")
        assertThat(source).contains("tv-confirm-cancel-button")
        assertThat(source).contains("tv-confirm-confirm-button")
        assertThat(source).contains("dismissOnBackPress = true")
        assertThat(source).contains("Key.Back")
        assertThat(source).contains("Key.Escape")
        assertThat(source).contains("cancelLabel: String = \"取消\"")
        assertThat(source).contains("confirmLabel: String = \"确认\"")
        assertThat(source).contains("confirmIsDanger")
        // 默认焦点在取消，降低误触确认风险。
        assertThat(source).contains("cancelFocusRequester.requestFocus()")
        assertThat(source).contains("默认焦点落在取消")
        // 卡片与按钮均圆角，且 clip 保证四角完整。
        assertThat(source).contains("clip(RoundedCornerShape(DialogCorner))")
        assertThat(source).contains("ActionCorner")
        assertThat(source).contains("width(312.dp)")
    }

    @Test
    fun scrollable_page_header_exposes_trailing_action_slot() {
        val source = File(
            "src/main/java/org/moontechlab/selene/tv/core/design/layout/TvScrollablePageHeader.kt",
        ).readText()

        assertThat(source).contains("fun TvScrollablePageHeader(")
        assertThat(source).contains("fun TvHeaderActionButton(")
        assertThat(source).contains("tv-header-action-button")
        assertThat(source).contains("trailing")
    }
}
