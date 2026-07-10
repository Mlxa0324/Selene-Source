package uk.oxiang.ivy.tv.core.design.focus

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * [TvFocusableCard] 源码契约测试：多 `FocusRequester` 共享绑定顺序、
 * 焦点记忆分组接线、方向键节流接线。
 *
 * 纯 JVM 单测环境未接入 Robolectric/Compose 测试运行时，无法驱动真实
 * `onPreviewKeyEvent`/`onFocusChanged` 回调；这里采用与 `re-android` 一致的
 * 源码断言方式验证接线契约，行为级验证见 [TvRemotePressPolicyTest]、
 * [TvDirectionalRepeatThrottleTest]、[TvFocusMemoryRegistryTest]。
 */
class TvFocusableCardContractTest {

    private fun readSource(): String {
        return File("src/main/java/uk/oxiang/ivy/tv/core/design/focus/TvFocusableCard.kt").readText()
    }

    @Test
    fun multipleFocusRequesters_shareSameRealFocusNode() {
        val source = readSource()

        assertThat(source).contains("focusRequesters: List<FocusRequester> = emptyList()")
        // fold 把多个外部请求器绑定到同一个真实 focusable 节点，避免容器成为不可见中转焦点。
        assertThat(source).contains("current.focusRequester(requester)")
        assertThat(source.indexOf(".then(focusRequesterModifier)")).isLessThan(source.indexOf(".focusable("))
    }

    @Test
    fun focusMemoryGroup_registersAndUnregistersEntryLifecycle() {
        val source = readSource()

        assertThat(source).contains("focusMemoryGroupKey: Any? = null")
        assertThat(source).contains("TvFocusMemoryRegistry.register(entry)")
        assertThat(source).contains("TvFocusMemoryRegistry.unregister(entry)")
        assertThat(source).contains("TvFocusMemoryRegistry.onFocused(entry)")
        assertThat(source).contains("TvFocusMemoryRegistry.onUnfocused(entry)")
    }

    @Test
    fun directionalRepeatThrottle_isOptedInViaGroupKey() {
        val source = readSource()

        assertThat(source).contains("directionalRepeatThrottleGroupKey: Any? = null")
        assertThat(source).contains("TvDirectionalRepeatThrottle.shouldThrottle(")
    }

    @Test
    fun autoScrollOnFocus_bringsCardIntoViewOnRealFocus() {
        val source = readSource()

        assertThat(source).contains("autoScrollOnFocus: Boolean = true")
        assertThat(source).contains("bringIntoViewRequester.bringIntoView()")
    }

    @Test
    fun onFocusedNodeChanged_onlyFiresOnRealFocusGain() {
        val source = readSource()
        val focusChangedHandler = source.substringAfter("private fun handleFocusChanged(")

        assertThat(source).contains("onFocusedNodeChanged: (() -> Unit)? = null")
        // 回调必须放在 hasFocus 分支内，失焦分支不得触发。
        assertThat(focusChangedHandler.substringBefore("} else {")).contains("onFocusedNodeChanged?.invoke()")
        assertThat(focusChangedHandler.substringAfter("} else {").substringBefore("onFocusChanged?.invoke"))
            .doesNotContain("onFocusedNodeChanged?.invoke()")
    }

    @Test
    fun confirmKeyShortAndLongPress_delegatesToSharedPressPolicy() {
        val source = readSource()

        assertThat(source).contains("TvRemotePressPolicy(hasLongPressHandler = onLongPressed != null)")
        assertThat(source).contains("pressPolicy.onKeyDown(isRepeat = pressPolicy.isPressing)")
        assertThat(source).contains("pressPolicy.onKeyUp()")
    }
}
