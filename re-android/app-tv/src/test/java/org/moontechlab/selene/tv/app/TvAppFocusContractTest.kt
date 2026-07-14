package org.moontechlab.selene.tv.app

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 TV 根壳的遥控器焦点契约。
 */
class TvAppFocusContractTest {
    /**
     * 顶层路由切换后内容焦点请求器必须重建，避免请求旧页面隐藏卡片。
     */
    @Test
    fun app_shell_scopes_content_focus_requester_to_current_route() {
        val source = readAppSource()

        assertThat(source).contains("TvDesignCanvas(")
        assertThat(source).contains("preset = TvDesignPreset.QHD_1440")
        assertThat(source).contains("remember(currentRoute)")
        assertThat(source).contains("FocusRequester()")
        assertThat(source).contains("contentFocusRequester = contentFocusRequester")
    }

    /**
     * 顶部导航下方向键必须交给 focusProperties 的 down 目标，不在预览按键里提前消费。
     */
    @Test
    fun navigation_down_key_uses_focus_properties_without_preview_consumption() {
        val source = readAppSource()
        val pillSource = readNavigationPillSource()

        assertThat(source).contains("down = contentFocusRequester")
        assertThat(source).doesNotContain("import androidx.compose.ui.platform.LocalFocusManager")
        assertThat(source).doesNotContain("import androidx.compose.ui.focus.FocusDirection")
        assertThat(pillSource).doesNotContain("Key.DirectionDown")
        assertThat(pillSource).doesNotContain("onFocusContent()")
    }

    /**
     * 顶部导航必须把向下焦点目标显式声明给 Compose，避免默认搜索只在顶部区域循环。
     */
    @Test
    fun navigation_pill_declares_down_focus_target() {
        val source = readAppSource()

        assertThat(source).contains("import androidx.compose.ui.focus.focusProperties")
        assertThat(source).contains("contentFocusRequester: FocusRequester")
        assertThat(source).contains("down = contentFocusRequester")
    }

    /**
     * 下方向焦点配置必须声明在真实 focusable 节点之前，确保作用到顶部按钮焦点目标。
     */
    @Test
    fun navigation_pill_declares_down_focus_before_focusable_target() {
        val pillSource = readNavigationPillSource()

        assertThat(pillSource.indexOf(".focusProperties {")).isLessThan(pillSource.indexOf(".focusable("))
        assertThat(pillSource.indexOf(".onPreviewKeyEvent {")).isLessThan(pillSource.indexOf(".focusable("))
    }

    /**
     * 顶部主导航必须显式处理左右键，避免焦点落到相邻 tab 后又被外部进入重定向逻辑拉回当前 tab。
     */
    @Test
    fun navigation_pill_handles_left_right_inside_current_group() {
        val groupSource = readDestinationGroupSource()
        val pillSource = readNavigationPillSource()

        assertThat(groupSource).contains("var pendingInternalFocusRoute by remember")
        assertThat(groupSource).contains("destinations.forEachIndexed")
        assertThat(groupSource).contains("moveFocusInsideGroup(previousDestination)")
        assertThat(groupSource).contains("moveFocusInsideGroup(nextDestination)")
        assertThat(pillSource).contains("onMoveLeft: () -> Unit")
        assertThat(pillSource).contains("onMoveRight: () -> Unit")
        assertThat(pillSource).contains("Key.DirectionLeft")
        assertThat(pillSource).contains("Key.DirectionRight")
    }

    /**
     * 顶部导航必须把真实焦点初始化到当前选中的入口，避免首个下方向键只停在标签本身。
     */
    @Test
    fun top_navigation_requests_focus_for_current_destination() {
        val source = readAppSource()
        val topNavigationSource = readTopNavigationSource()
        val groupSource = readDestinationGroupSource()
        val pillSource = readNavigationPillSource()

        assertThat(source).contains("selectedTopDestination")
        assertThat(topNavigationSource).contains("rememberTopDestinationFocusRequesters()")
        assertThat(topNavigationSource).contains("LaunchedEffect(selectedTopDestination?.route)")
        assertThat(topNavigationSource).contains("selectedTopDestinationFocusRequester.requestFocus()")
        assertThat(groupSource).contains("focusRequester = topDestinationFocusRequesters[destination.route]")
        assertThat(pillSource).contains("focusRequester: FocusRequester?")
        assertThat(pillSource).contains(".focusRequester(focusRequester)")
    }

    /**
     * 顶部导航胶囊必须使用显式 focusable 节点，避免 clickable 内部焦点目标和内容卡片焦点树不一致。
     */
    @Test
    fun navigation_pill_uses_explicit_focusable_without_clickable_bridge() {
        val source = readAppSource()
        val pillSource = readNavigationPillSource()

        assertThat(source).doesNotContain("import androidx.compose.foundation.clickable")
        assertThat(source).contains("import androidx.compose.foundation.focusable")
        assertThat(source).contains("import androidx.compose.foundation.gestures.detectTapGestures")
        assertThat(source).contains("import androidx.compose.ui.input.pointer.pointerInput")
        assertThat(pillSource).doesNotContain(".clickable(")
        assertThat(pillSource).contains(".focusable(")
    }

    /**
     * TV 根壳创建容器时必须传入 applicationContext，
     * 这样播放器内核设置等偏好才能在安装新包和进程重启后继续恢复。
     */
    @Test
    fun app_shell_passes_application_context_into_container() {
        val source = readAppSource()

        assertThat(source).contains("appContext = context.applicationContext")
    }

    /**
     * 读取 TV 根壳源码。
     *
     * @return 当前 TvApp 源码文本。
     */
    private fun readAppSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/app/TvApp.kt")
            .readText()
    }

    /**
     * 截取顶部导航源码。
     *
     * @return TvTopNavigationBar 函数源码文本。
     */
    private fun readTopNavigationSource(): String {
        val source = readAppSource()
        return source.substringAfter("private fun TvTopNavigationBar(")
            .substringBefore("/**\n * 渲染同一分区内的一组路由按钮。")
    }

    /**
     * 截取顶部导航分组源码。
     *
     * @return TvDestinationGroup 函数源码文本。
     */
    private fun readDestinationGroupSource(): String {
        val source = readAppSource()
        return source.substringAfter("private fun TvDestinationGroup(")
            .substringBefore("/**\n * TV 顶部导航胶囊按钮。")
    }

    /**
     * 截取顶部导航按钮源码。
     *
     * @return TvNavigationPill 函数源码文本。
     */
    private fun readNavigationPillSource(): String {
        val source = readAppSource()
        return source.substringAfter("private fun TvNavigationPill(")
            .substringBefore("/**\n * TV 顶部当前时间。")
    }

    /**
     * 分类 tab 确认键才弹出筛选；首页不弹。
     */
    @Test
    fun category_tabs_confirm_toggles_filter_home_does_not() {
        val source = File("src/main/java/org/moontechlab/selene/tv/app/TvApp.kt").readText()
        assertThat(source).contains("supportsCategoryFilter")
        assertThat(source).contains("selected && supportsCategoryFilter")
        assertThat(source).contains("destination.supportsCategoryFilter()")
    }

    /**
     * 分类筛选打开时必须隐藏整套首页导航，并让返回键只关闭筛选而不离开当前分类页。
     */
    @Test
    fun category_filter_hides_home_navigation_and_back_closes_only_filter() {
        val source = readAppSource()

        assertThat(source).contains("BackHandler(enabled = showCategoryFilter)")
        assertThat(source).contains("if (isPrimaryRoute && !showCategoryFilter)")
        assertThat(source).contains("showCategoryFilter = false")
    }
}
