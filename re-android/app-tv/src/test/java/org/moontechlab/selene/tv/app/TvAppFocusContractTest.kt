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
     * 主菜单下方向键交给 focusProperties → 内容区；快捷区下键由 onMoveDown 回主菜单。
     */
    @Test
    fun navigation_down_key_uses_focus_properties_or_explicit_callback() {
        val source = readAppSource()
        val pillSource = readNavigationPillSource()

        assertThat(source).contains("down = if (useContentAsDownTarget)")
        assertThat(source).contains("contentFocusRequester")
        assertThat(source).doesNotContain("import androidx.compose.ui.platform.LocalFocusManager")
        assertThat(source).doesNotContain("import androidx.compose.ui.focus.FocusDirection")
        assertThat(pillSource).contains("onMoveDown != null")
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
        assertThat(source).contains("useContentAsDownTarget")
        assertThat(source).contains("contentFocusRequester")
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
        val topNavSource = readTopNavigationSource()

        assertThat(topNavSource).contains("var pendingInternalFocusRoute by remember")
        assertThat(groupSource).contains("destinations.forEachIndexed")
        assertThat(groupSource).contains("previousDestination?.route?.let(onRequestInternalFocus)")
        assertThat(groupSource).contains("nextDestination?.route?.let(onRequestInternalFocus)")
        assertThat(pillSource).contains("onMoveLeft: () -> Unit")
        assertThat(pillSource).contains("onMoveRight: () -> Unit")
        assertThat(pillSource).contains("Key.DirectionLeft")
        assertThat(pillSource).contains("Key.DirectionRight")
    }

    /**
     * 主菜单上键必须进入右上角快捷首项；快捷区下键回到主菜单来源项。
     * 跨组移动依赖顶栏级 topNavHasFocus，禁止被“外部进入重定向”拉回选中主 tab。
     */
    @Test
    fun primary_menu_up_reaches_quick_access_and_down_returns() {
        val topNavSource = readTopNavigationSource()
        val groupSource = readDestinationGroupSource()
        val pillSource = readNavigationPillSource()

        assertThat(topNavSource).contains("topNavHasFocus")
        assertThat(topNavSource).contains("lastActionSourceRoute")
        assertThat(topNavSource).contains("onMoveUpFromItem")
        assertThat(topNavSource).contains("onMoveDownFromGroup")
        assertThat(topNavSource).contains("quickAccessDestinations")
        assertThat(topNavSource).contains("firstQuickAccessRoute")
        assertThat(groupSource).contains("movingInsideTopNav")
        assertThat(groupSource).contains("onMoveUp = onMoveUpFromItem")
        assertThat(groupSource).contains("onMoveDown = onMoveDownFromGroup")
        assertThat(pillSource).contains("Key.DirectionUp")
        assertThat(pillSource).contains("onMoveUp != null")
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
            .substringBefore("/**\n * 记住顶层入口到焦点请求器的映射。")
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
     * 主菜单为无背景文字 + 选中下划线；右上角快捷仍为胶囊。
     */
    @Test
    fun primary_menu_uses_text_underline_quick_access_keeps_pill() {
        val source = readAppSource()
        val topNavSource = readTopNavigationSource()
        val pillSource = readNavigationPillSource()

        assertThat(source).contains("enum class TvNavItemStyle")
        assertThat(source).contains("TextUnderline")
        assertThat(topNavSource).contains("itemStyle = TvNavItemStyle.TextUnderline")
        assertThat(topNavSource).contains("itemStyle = TvNavItemStyle.Pill")
        assertThat(pillSource).contains("isTextUnderline")
        assertThat(pillSource).contains("TvTokens.Accent")
        // 选中态文字必须用主题色 Accent，不能仍是白字。
        assertThat(pillSource).contains("isTextUnderline && selected -> TvTokens.Accent")
        assertThat(pillSource).contains("Color.Transparent")
        // 下划线宽度跟文案，禁止裸 fillMaxWidth 把首项撑满整行挤掉后续 tab。
        assertThat(pillSource).contains("IntrinsicSize.Max")
        assertThat(topNavSource).contains("horizontalSpacing = 12.dp")
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
