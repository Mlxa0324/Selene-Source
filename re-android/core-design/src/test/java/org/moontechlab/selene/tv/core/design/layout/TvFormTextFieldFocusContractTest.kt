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

        assertThat(source).contains("val arrowHandler = when (event.key)")
        assertThat(source).contains("val hasArrowHandler = arrowHandler != null")
        assertThat(source).contains("if (!isEditing && hasArrowHandler)")
        assertThat(source).contains("arrowHandler.invoke()")
    }
}
