package org.moontechlab.selene.tv.feature.search

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 TV 搜索页遥控器焦点契约。
 */
class TvSearchRouteFocusContractTest {
    /**
     * 右侧面板所有状态都必须承接键盘右移入口，避免按右方向键后丢焦。
     */
    @Test
    fun right_panel_states_attach_entry_focus_requester() {
        val source = readRouteSource()

        assertThat(source).contains("private fun SearchSuggestionPanel(")
        assertThat(source).contains("private fun SearchDefaultPanel(")
        assertThat(source).contains("entryFocusRequester: FocusRequester")
        assertThat(source).contains("onReturnToLeftPanel: () -> Unit")
        assertThat(source).contains("private fun SearchResultPanel(")
        assertThat(source).contains("firstItemFocusRequester = entryFocusRequester")
        assertThat(source).contains("TvSearchStatePanel(")
        assertThat(source).contains("focusRequester = entryFocusRequester")
        assertThat(source).contains("onConsumeBack")
        assertThat(source).contains("影片推荐")
        assertThat(source).contains("联想结果")
    }

    /**
     * 搜索结果和提示面板必须能按左方向键回到最近键盘按键。
     */
    @Test
    fun right_panel_entry_can_return_to_keyboard_with_left_key() {
        val source = readRouteSource()

        assertThat(source).contains("onLeft = onReturnToLeftPanel")
        assertThat(source).contains("onReturnToLeftPanel = onReturnToLeftPanel")
    }

    /**
     * 左右栏焦点必须按垂直分带就近：键盘上/中/下对应历史/热词/推荐，回程落到对应键行。
     */
    @Test
    fun left_right_focus_transfers_by_vertical_band() {
        val source = readRouteSource()

        assertThat(source).contains("enum class SearchRightFocusBand")
        assertThat(source).contains("keyboardRowToRightBand")
        assertThat(source).contains("resolveKeyboardRowForRightBand")
        assertThat(source).contains("resolveRightPanelEntriesForKeyboardRow")
        assertThat(source).contains("focusRightPanelFromKeyboardRow")
        assertThat(source).contains("rightHistoryEntryFocus")
        assertThat(source).contains("rightHotEntryFocus")
        assertThat(source).contains("rightRecommendEntryFocus")
        assertThat(source).contains("SearchRightFocusBand.History")
        assertThat(source).contains("SearchRightFocusBand.Hot")
        assertThat(source).contains("SearchRightFocusBand.Recommend")
        // 推荐首项左出回推荐分带，不得只靠 Default 几何乱跳。
        assertThat(source).contains("onLeftFromFirst = onReturnToLeftPanel")
    }

    /**
     * 左下角三按钮必须可左右切换；结果网格 5 列铺满格宽。
     */
    @Test
    fun left_action_row_supports_horizontal_focus_and_results_use_five_columns() {
        val source = readRouteSource()

        assertThat(source).contains("onLeft = { deleteFocus.requestFocus() }")
        assertThat(source).contains("onRight = { searchFocus.requestFocus() }")
        assertThat(source).contains("onLeft = { clearFocus.requestFocus() }")
        assertThat(source).contains("onRight = { deleteFocus.requestFocus() }")
        assertThat(source).contains("onLeft = { searchFocus.requestFocus() }")
        assertThat(source).contains("columns = 5")
        assertThat(source).contains("fillCellWidth = true")
        assertThat(source).contains("contentHorizontalPadding = 2.dp")
        assertThat(source).contains("horizontalSpacing = 12.dp")
        assertThat(source).contains("verticalSpacing = 32.dp")
        assertThat(source).contains("rating = video.doubanRate")
        assertThat(source).contains("onArrowDownToKeyboard")
    }

    /**
     * 右侧词块不环形：底行下键用 onArrowDownFromBottom 离开本区，禁止循环回顶部。
     * 跨区上下按同列就近，禁止写死跳到对方首项。
     */
    @Test
    fun right_panel_word_tiles_do_not_wrap_vertically() {
        val source = readRouteSource()
        val wordGrid = source
            .substringAfter("private fun WordTileGrid(")
            .substringBefore("@Composable\nprivate fun RecommendRail(")

        assertThat(wordGrid).contains("onArrowDownFromBottom")
        assertThat(wordGrid).contains("onArrowUpFromTop")
        assertThat(wordGrid).contains("底行下键：把列号交给外层，落到下区同列首项")
        assertThat(wordGrid).doesNotContain("底行下键：回到首行同列（环形）")
        // 首项 = 列表 requester[0] 即入口本体（rememberWordTileFocusRequesters 单挂）。
        assertThat(source).contains("rememberWordTileFocusRequesters")
        assertThat(source).contains("resolveWordTileBottomRowIndex")
        assertThat(source).contains("resolveWordTileTopRowIndex")
        assertThat(source).doesNotContain("// 回到历史区入口（首项）。")
        assertThat(wordGrid).contains(".focusRequester(itemFocus)")
        assertThat(source).contains("hotEntryFocus")
        assertThat(source).contains("recommendEntryFocus")
        // 无回调的方向键不得吞键，避免标题「清空」锁死焦点。
        assertThat(source).contains("if (action == null) return false")
    }

    /**
     * 影片推荐横滑：左右 contentPadding 独立；视口贴齐面板缘，不被父级大边距夹死。
     */
    @Test
    fun recommend_rail_uses_independent_content_padding_and_bleeds_to_panel_edge() {
        val source = readRouteSource()
        val recommendRail = source
            .substringAfter("private fun RecommendRail(")
            .substringBefore("@Composable\nprivate fun SearchResultPanel(")

        assertThat(source).contains("RecommendRailStartPadding")
        assertThat(source).contains("RecommendRailEndPadding")
        assertThat(source).contains("RightPanelContentHorizontal")
        // 左右停靠独立，不得写死成对称 0 / 同一常量混用。
        assertThat(recommendRail).contains("contentStartPadding = RecommendRailStartPadding")
        assertThat(recommendRail).contains("contentEndPadding = RecommendRailEndPadding")
        // layout 外扩抵消父级 content 水平 padding（禁止负 padding，会崩溃）。
        assertThat(recommendRail).contains("horizontalBleed(RightPanelContentHorizontal)")
        assertThat(source).contains("private fun Modifier.horizontalBleed")
        assertThat(recommendRail).doesNotContain("padding(horizontal = -")
        assertThat(recommendRail).doesNotContain("contentStartPadding = 0.dp")
    }

    /**
     * 读取搜索 Route 源码。
     *
     * @return Route 源码文本。
     */
    private fun readRouteSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/feature/search/TvSearchRoute.kt")
            .readText()
    }
}
