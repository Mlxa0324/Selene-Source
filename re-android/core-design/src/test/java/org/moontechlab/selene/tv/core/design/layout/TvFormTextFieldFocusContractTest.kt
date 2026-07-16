package org.moontechlab.selene.tv.core.design.layout

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * TV 表单文本输入行的方向键焦点契约测试。
 */
class TvFormTextFieldFocusContractTest {
    /**
     * 未配置自定义上下焦点回调时，浏览态输入行必须把方向键交还给 Compose 空间导航。
     */
    @Test
    fun unbound_vertical_navigation_is_not_consumed() {
        val source = File("src/main/java/org/moontechlab/selene/tv/core/design/layout/TvFormTextField.kt")
            .readText()

        // 未绑定 onArrowUp/Down 时不消费方向键，交还系统导航。
        assertThat(source).contains("if (onArrowUp == null) return@onPreviewKeyEvent false")
        assertThat(source).contains("if (onArrowDown == null) return@onPreviewKeyEvent false")
        assertThat(source).contains("onArrowUp.invoke()")
        assertThat(source).contains("onArrowDown.invoke()")
    }

    /**
     * 密码字段默认星花掩码，右侧眼睛可切换明文。
     */
    @Test
    fun password_field_masks_by_default_with_eye_toggle() {
        val source = File("src/main/java/org/moontechlab/selene/tv/core/design/layout/TvFormTextField.kt")
            .readText()

        assertThat(source).contains("isPassword: Boolean = false")
        assertThat(source).contains("var passwordVisible by remember { mutableStateOf(false) }")
        assertThat(source).contains("PasswordVisualTransformation")
        assertThat(source).contains("TvPasswordVisibilityEye(")
        assertThat(source).contains("\"•\".repeat")
    }
}
