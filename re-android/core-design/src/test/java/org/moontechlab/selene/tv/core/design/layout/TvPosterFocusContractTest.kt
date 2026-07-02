package org.moontechlab.selene.tv.core.design.layout

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 TV 海报列表的遥控器焦点契约。
 */
class TvPosterFocusContractTest {
    /**
     * 横向海报带必须形成焦点分组，顶部导航向下才能稳定进入影视卡片。
     */
    @Test
    fun posterRail_declares_focus_group() {
        val source = readLayoutSource("TvPosterRail.kt")

        assertThat(source).contains("modifier = modifier.posterFocusGroup(")
    }

    /**
     * 纵向海报网格必须形成焦点分组，分类页和历史页才能从顶部进入影视卡片。
     */
    @Test
    fun posterGrid_declares_focus_group() {
        val source = readLayoutSource("TvPosterGrid.kt")

        assertThat(source).contains("modifier = modifier.posterFocusGroup(")
    }

    /**
     * 横向海报带必须把分组请求器挂到首张真实海报，避免 Lazy 容器生成不可见中转焦点。
     */
    @Test
    fun posterRail_attaches_group_requester_to_first_real_card() {
        val source = readLayoutSource("TvPosterRail.kt")

        assertThat(source).contains("val firstCardFocusRequester = remember { FocusRequester() }")
        assertThat(source).contains("firstCardFocusRequester = firstCardFocusRequester")
        assertThat(source).contains("val cardFocusRequesters = if (index == 0)")
        assertThat(source).contains("listOfNotNull(")
        assertThat(source).contains("firstCardFocusRequester,")
        assertThat(source).contains("focusRequesters = cardFocusRequesters")
    }

    /**
     * 横向海报带必须把顶部下探入口绑定到最近获焦卡片，避免首卡被 LazyRow 回收后下键失效。
     */
    @Test
    fun posterRail_remembers_last_focused_card_for_top_navigation_reentry() {
        val source = readLayoutSource("TvPosterRail.kt")

        assertThat(source).contains("val designMetrics = LocalTvDesignMetrics.current")
        assertThat(source).contains("designMetrics.viewportWidth.toInt()")
        assertThat(source).contains("designMetrics.viewportHeight.toInt()")
        assertThat(source).contains("var lastFocusedItemIndex by rememberSaveable")
        assertThat(source).contains("val bindsContentEntry = index == lastFocusedItemIndex")
        assertThat(source).contains("if (bindsContentEntry) firstItemFocusRequester else null")
        assertThat(source).contains("lastFocusedItemIndex = index")
    }

    /**
     * 纵向网格同样必须把公开请求器挂到首张真实海报。
     */
    @Test
    fun posterGrid_attaches_public_requester_to_first_real_card() {
        val source = readLayoutSource("TvPosterGrid.kt")

        assertThat(source).contains("val firstCardFocusRequester = remember { FocusRequester() }")
        assertThat(source).contains("firstCardFocusRequester = firstCardFocusRequester")
        assertThat(source).contains("val cardFocusRequesters = if (index == 0)")
        assertThat(source).contains("firstCardFocusRequester,")
        assertThat(source).contains("if (bindsContentEntry) firstItemFocusRequester else null")
        assertThat(source).contains("focusRequesters = cardFocusRequesters")
    }

    /**
     * 纵向网格必须像横向海报带一样记录最近获焦卡片，避免首卡回收后顶部下探失效。
     */
    @Test
    fun posterGrid_remembers_last_focused_card_for_top_navigation_reentry() {
        val source = readLayoutSource("TvPosterGrid.kt")

        assertThat(source).contains("val designMetrics = LocalTvDesignMetrics.current")
        assertThat(source).contains("designMetrics.viewportWidth.toInt()")
        assertThat(source).contains("designMetrics.viewportHeight.toInt()")
        assertThat(source).contains("var lastFocusedItemIndex by rememberSaveable")
        assertThat(source).contains("val bindsContentEntry = index == lastFocusedItemIndex")
        assertThat(source).contains("if (bindsContentEntry) firstItemFocusRequester else null")
        assertThat(source).contains("lastFocusedItemIndex = index")
    }

    /**
     * 海报焦点分组只负责分组进入规则，不创建可获焦的容器中转节点。
     */
    @Test
    fun poster_focus_group_does_not_create_focusable_bridge_node() {
        val source = readLayoutSource("TvPosterFocusGroup.kt")
        val focusGroupSource = source.substringAfter("internal fun Modifier.posterFocusGroup(")
            .substringBefore("/**\n * 构建首张海报的焦点目标修饰器。")

        assertThat(focusGroupSource).contains("firstCardFocusRequester: FocusRequester")
        assertThat(source).contains("import androidx.compose.ui.focus.focusProperties")
        assertThat(focusGroupSource).contains("onEnter = {")
        assertThat(focusGroupSource).contains("firstCardFocusRequester.requestFocus()")
        assertThat(focusGroupSource).doesNotContain("contentFocusRequester")
        assertThat(focusGroupSource).doesNotContain("focusable()")
    }

    /**
     * 海报卡片的高亮必须直接跟随 Compose 焦点状态，避免焦点已进入但视觉仍停在顶部导航。
     */
    @Test
    fun posterCard_tracks_visual_focus_from_compose_focus_state() {
        val source = readLayoutSource("TvPosterCard.kt")

        assertThat(source).contains("import androidx.compose.ui.focus.onFocusChanged")
        assertThat(source).contains("var hasCardFocus by remember { mutableStateOf(false) }")
        assertThat(source).contains("hasCardFocus = focusState.hasFocus")
    }

    /**
     * 海报占位底色必须固定为统一浅灰，避免封面未返回时出现随机彩色卡片。
     */
    @Test
    fun posterCard_uses_single_neutral_placeholder_color() {
        val source = readLayoutSource("TvPosterCard.kt")
        val placeholderSource = source.substringAfter("private fun posterBrushColors()")
            .substringBefore("/**\n * 生成海报卡片辅助文案。")

        assertThat(placeholderSource).contains("TvTokens.PosterPlaceholder")
        assertThat(placeholderSource).doesNotContain("Color(0xFF16C784)")
        assertThat(placeholderSource).doesNotContain("Color(0xFF1E90FF)")
        assertThat(placeholderSource).doesNotContain("Color(0xFF8B5CF6)")
        assertThat(placeholderSource).doesNotContain("Color(0xFFFFB020)")
        assertThat(placeholderSource).doesNotContain("Color(0xFFE25555)")
        assertThat(placeholderSource).doesNotContain("Color(0xFF2DD4BF)")
    }

    /**
     * 横向海报带在任意卡片获焦时都必须把分区获焦事件抛给外层页面，用于驱动首页纵向滚动。
     */
    @Test
    fun posterRail_exposes_focus_callback_for_parent_section_scroll() {
        val source = readLayoutSource("TvPosterRail.kt")

        assertThat(source).contains("onRailFocused: (() -> Unit)? = null")
        assertThat(source).contains("onRailFocused?.invoke()")
    }

    /**
     * 海报卡片必须复用 TV 专用焦点容器，确保方向键和确认键落在同一个遥控器焦点节点。
     */
    @Test
    fun posterCards_use_tv_focusable_card_container() {
        val source = readLayoutSource("TvPosterCard.kt")
        val posterCardSource = source.substringAfter("fun TvPosterCard(")
            .substringBefore("private fun TvPosterCover(")
        val moreCardSource = source.substringAfter("fun TvMorePosterCard(")
            .substringBefore("private fun posterBrushColors(")

        assertThat(source).contains("import org.moontechlab.selene.tv.core.design.focus.TvFocusableCard")
        assertThat(posterCardSource).contains("TvFocusableCard(")
        assertThat(posterCardSource).contains("focusRequesters = focusRequesters")
        assertThat(posterCardSource).contains("onPressed = onClick")
        assertThat(moreCardSource).contains("TvFocusableCard(")
        assertThat(moreCardSource).contains("onPressed = onClick")
    }

    /**
     * 可聚焦卡片必须把请求器绑定在真实 focusable 节点前，避免外层 Modifier 顺序吞掉顶部下探。
     */
    @Test
    fun focusableCard_binds_requesters_before_real_focus_target() {
        val source = File("src/main/java/org/moontechlab/selene/tv/core/design/focus/TvFocusableCard.kt")
            .readText()

        assertThat(source).contains("focusRequesters: List<FocusRequester> = emptyList()")
        assertThat(source).contains("current.focusRequester(requester)")
        assertThat(source.indexOf(".then(focusRequesterModifier)")).isLessThan(source.indexOf(".focusable("))
    }

    /**
     * 可聚焦卡片不能再通过 clickable 生成第二个焦点节点。
     */
    @Test
    fun focusableCard_uses_pointer_input_without_extra_clickable_focus_target() {
        val source = File("src/main/java/org/moontechlab/selene/tv/core/design/focus/TvFocusableCard.kt")
            .readText()

        assertThat(source).doesNotContain("import androidx.compose.foundation.clickable")
        assertThat(source).doesNotContain(".clickable(")
        assertThat(source).contains("import androidx.compose.foundation.gestures.detectTapGestures")
        assertThat(source).contains("import androidx.compose.ui.input.pointer.pointerInput")
    }

    /**
     * 读取海报布局源码。
     *
     * @param fileName 源码文件名。
     * @return 当前源码文本。
     */
    private fun readLayoutSource(fileName: String): String {
        return File("src/main/java/org/moontechlab/selene/tv/core/design/layout/$fileName")
            .readText()
    }
}
