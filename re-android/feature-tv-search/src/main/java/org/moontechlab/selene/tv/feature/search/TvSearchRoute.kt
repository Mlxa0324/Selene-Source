package org.moontechlab.selene.tv.feature.search

import androidx.activity.compose.BackHandler
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.focus.tvPointerClickable
import org.moontechlab.selene.tv.core.design.layout.TvPosterGrid
import org.moontechlab.selene.tv.core.design.layout.TvPosterItem
import org.moontechlab.selene.tv.core.design.layout.TvPosterRail
import org.moontechlab.selene.tv.core.design.layout.TvStatePanel
import org.moontechlab.selene.tv.core.design.layout.TvStatePanelKind
import org.moontechlab.selene.tv.core.design.layout.toVideoDetailKey

// ── 布局常量：左输入区更紧凑，右结果区更宽 ──
private val LeftPanelWidth: Dp = 328.dp
private const val KeyboardColumns = 6
private const val KeyboardRows = 6
private val KeyHeight: Dp = 44.dp
private val KeySpacing: Dp = 7.dp
private val RightPanelStartPadding: Dp = 24.dp
private val PanelRadius: Dp = 22.dp
private val ControlRadius: Dp = 14.dp

/** 搜索页局部色板，统一左右面板质感。 */
private object SearchPalette {
    /** 页面底层背景。 */
    val PageBg = TvTokens.Background

    /** 左侧控制面板底色。 */
    val LeftPanel = Color(0xFF222733)

    /** 右侧内容面板底色。 */
    val RightPanel = Color(0xFF252A35)

    /** 输入框与词块默认底。 */
    val ControlIdle = Color(0xFF343A48)

    /** 键盘键默认底（略透明，避免整板过重）。 */
    val KeyIdle = Color(0x143A4152)

    /** 控件获焦填充。 */
    val ControlFocused = Color(0xFF4B5366)

    /** 搜索主按钮默认底。 */
    val PrimaryIdle = Color(0xFF8C121B)

    /** 搜索主按钮获焦底。 */
    val PrimaryFocused = TvTokens.Accent

    /** 弱提示文字。 */
    val Hint = TvTokens.FormTextSecondary

    /** 分区标题左侧装饰色。 */
    val AccentBar = TvTokens.Accent
}

// ── 键盘布局 (6×6) ──
private val KeyboardKeys: List<List<String>> = listOf(
    listOf("A", "B", "C", "D", "E", "F"),
    listOf("G", "H", "I", "J", "K", "L"),
    listOf("M", "N", "O", "P", "Q", "R"),
    listOf("S", "T", "U", "V", "W", "X"),
    listOf("Y", "Z", "1", "2", "3", "4"),
    listOf("5", "6", "7", "8", "9", "0"),
)

/**
 * TV 搜索页 —— 左键盘右内容双面板。
 *
 * 操作逻辑保持不变：键盘输入、清空/搜索/删除、历史直接搜、
 * 热词回填、联想确认搜索、结果进详情、返回先退面板再退页。
 */
@Composable
fun TvSearchRoute(
    state: TvSearchUiState = TvSearchUiState(),
    onAppendChar: (String) -> Unit = {},
    onDeleteLastChar: () -> Unit = {},
    onClearQuery: () -> Unit = {},
    onSearchCurrentQuery: () -> Unit = {},
    onHotQueryClick: (String) -> Unit = {},
    onSearchHistoryClick: (String) -> Unit = {},
    onSuggestionClick: (String) -> Unit = {},
    onClearHistory: () -> Unit = {},
    onVideoClick: (String) -> Unit = {},
    onBack: () -> Unit = {},
    onConsumeBack: () -> Boolean = { false },
) {
    // 拦截系统返回键：优先在搜索页内部退结果/联想，再退出页面。
    BackHandler {
        if (!onConsumeBack()) {
            onBack()
        }
    }

    // ── 焦点请求器 ──
    val keyFocusRequesters = remember {
        List(KeyboardRows) { List(KeyboardColumns) { FocusRequester() } }
    }
    val clearButtonFocus = remember { FocusRequester() }
    val searchButtonFocus = remember { FocusRequester() }
    val deleteButtonFocus = remember { FocusRequester() }
    val rightPanelEntryFocus = remember { FocusRequester() }
    var lastKeyboardRow by remember { mutableStateOf(0) }
    var lastKeyboardCol by remember { mutableStateOf(0) }

    // 首焦点落在键盘 A。
    LaunchedEffect(Unit) {
        keyFocusRequesters[0][0].requestFocus()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(SearchPalette.PageBg),
    ) {
        // 顶部柔光，拉开“影视搜索台”层次，不抢内容。
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(220.dp)
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color(0x33241A1C),
                            Color.Transparent,
                        ),
                    ),
                ),
        )

        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(
                    start = TvTokens.PageHorizontalPadding,
                    end = TvTokens.PageHorizontalPadding,
                    top = 24.dp,
                    bottom = 24.dp,
                ),
        ) {
            // ═══ 左面板：输入 + 键盘 + 操作 ═══
            Column(
                modifier = Modifier
                    .width(LeftPanelWidth)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(PanelRadius))
                    .background(SearchPalette.LeftPanel)
                    .border(1.dp, Color.White.copy(alpha = 0.06f), RoundedCornerShape(PanelRadius))
                    .padding(horizontal = 18.dp, vertical = 20.dp),
            ) {
                // 标题区：主标题 + 操作提示。
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(10.dp)
                            .clip(CircleShape)
                            .background(SearchPalette.AccentBar),
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    androidx.compose.material3.Text(
                        text = "搜索",
                        color = Color.White,
                        fontSize = 28.sp,
                        fontWeight = FontWeight.ExtraBold,
                    )
                }
                Spacer(modifier = Modifier.height(6.dp))
                androidx.compose.material3.Text(
                    text = "遥控器方向键切换 · 返回键退出页面",
                    color = SearchPalette.Hint,
                    fontSize = 12.sp,
                )
                Spacer(modifier = Modifier.height(18.dp))

                // 搜索输入框（纯展示，真实输入靠左侧键盘）。
                SearchInputDisplay(query = state.query)
                Spacer(modifier = Modifier.height(16.dp))

                // 虚拟键盘。
                TvKeyboard(
                    focusRequesters = keyFocusRequesters,
                    onKeyPressed = { onAppendChar(it) },
                    onArrowRightFromEdge = { row, col ->
                        lastKeyboardRow = row
                        lastKeyboardCol = col
                        rightPanelEntryFocus.requestFocus()
                    },
                    onArrowDownFromBottom = { clearButtonFocus.requestFocus() },
                    onArrowUpFromTop = { deleteButtonFocus.requestFocus() },
                    onBack = {
                        if (!onConsumeBack()) {
                            onBack()
                        }
                    },
                    onFocusChanged = { row, col ->
                        lastKeyboardRow = row
                        lastKeyboardCol = col
                    },
                )
                Spacer(modifier = Modifier.height(14.dp))

                // 操作按钮：清空 / 搜索 / 删除。
                SearchActionRow(
                    clearFocus = clearButtonFocus,
                    searchFocus = searchButtonFocus,
                    deleteFocus = deleteButtonFocus,
                    onClear = onClearQuery,
                    onSearch = onSearchCurrentQuery,
                    onDelete = onDeleteLastChar,
                    onBack = {
                        if (!onConsumeBack()) {
                            onBack()
                        }
                    },
                    onArrowUpToKeyboard = { col ->
                        keyFocusRequesters[KeyboardRows - 1][col].requestFocus()
                    },
                    onArrowRightFromDelete = {
                        rightPanelEntryFocus.requestFocus()
                    },
                )
            }

            Spacer(modifier = Modifier.width(RightPanelStartPadding))

            // ═══ 右面板：历史/热词/推荐/联想/结果 ═══
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(PanelRadius))
                    .background(SearchPalette.RightPanel)
                    .border(1.dp, Color.White.copy(alpha = 0.05f), RoundedCornerShape(PanelRadius))
                    .padding(horizontal = 22.dp, vertical = 20.dp),
            ) {
                RightPanel(
                    state = state,
                    entryFocusRequester = rightPanelEntryFocus,
                    onReturnToLeftPanel = {
                        keyFocusRequesters[lastKeyboardRow][lastKeyboardCol].requestFocus()
                    },
                    onHotQueryClick = onHotQueryClick,
                    onSearchHistoryClick = onSearchHistoryClick,
                    onSuggestionClick = onSuggestionClick,
                    onClearHistory = onClearHistory,
                    onVideoClick = onVideoClick,
                    onBack = {
                        if (!onConsumeBack()) {
                            onBack()
                        }
                    },
                    modifier = Modifier.fillMaxSize(),
                )
            }
        }
    }
}

// ── 搜索输入框 ──

/**
 * 左侧搜索词展示框。
 *
 * @param query 当前输入内容。
 */
@Composable
private fun SearchInputDisplay(query: String) {
    val hasQuery = query.isNotEmpty()
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(50.dp)
            .background(SearchPalette.ControlIdle, RoundedCornerShape(25.dp))
            .border(
                width = if (hasQuery) 1.5.dp else 1.dp,
                color = if (hasQuery) SearchPalette.AccentBar.copy(alpha = 0.75f) else Color.White.copy(alpha = 0.08f),
                shape = RoundedCornerShape(25.dp),
            ),
        contentAlignment = Alignment.CenterStart,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // 搜索图标圆底，强化“输入位”识别。
            Box(
                modifier = Modifier
                    .size(28.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.08f)),
                contentAlignment = Alignment.Center,
            ) {
                androidx.compose.material3.Text(text = "\uD83D\uDD0D", fontSize = 13.sp)
            }
            Spacer(modifier = Modifier.width(12.dp))
            if (!hasQuery) {
                androidx.compose.material3.Text(
                    text = "输入影片名称首字母进行搜索",
                    color = Color(0xFF8E95A3),
                    fontSize = 14.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            } else {
                androidx.compose.material3.Text(
                    text = query,
                    color = Color.White,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

// ── 虚拟键盘 ──

/**
 * 6×6 字母数字虚拟键盘。
 *
 * 键盘按键只消费方向键和确认键的 KeyUp，Back 键全程放行。
 *
 * @param focusRequesters 键位焦点矩阵。
 * @param onKeyPressed 确认某键。
 * @param onArrowRightFromEdge 右缘右移到右面板。
 * @param onArrowDownFromBottom 底行下移到操作按钮。
 * @param onArrowUpFromTop 顶行上移到操作按钮（环回）。
 * @param onBack 返回处理。
 * @param onFocusChanged 记录最近键位，供右面板返回。
 */
@Composable
private fun TvKeyboard(
    focusRequesters: List<List<FocusRequester>>,
    onKeyPressed: (String) -> Unit,
    onArrowRightFromEdge: (row: Int, col: Int) -> Unit,
    onArrowDownFromBottom: () -> Unit,
    onArrowUpFromTop: () -> Unit,
    onBack: () -> Unit,
    onFocusChanged: (row: Int, col: Int) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        KeyboardKeys.forEachIndexed { row, keys ->
            Row(horizontalArrangement = Arrangement.spacedBy(KeySpacing)) {
                keys.forEachIndexed { col, keyLabel ->
                    val isRightEdge = col == keys.lastIndex
                    val isTopRow = row == 0
                    val isBottomRow = row == KeyboardRows - 1
                    val interactionSource = remember { MutableInteractionSource() }
                    val isFocused by interactionSource.collectIsFocusedAsState()
                    val bgColor by animateColorAsState(
                        if (isFocused) SearchPalette.ControlFocused else SearchPalette.KeyIdle,
                        tween(140),
                        label = "searchKeyBg",
                    )
                    val borderColor by animateColorAsState(
                        if (isFocused) Color.White else Color.White.copy(alpha = 0.05f),
                        tween(140),
                        label = "searchKeyBorder",
                    )

                    Box(
                        modifier = Modifier
                            .weight(1f, fill = true)
                            .height(KeyHeight)
                            .background(bgColor, RoundedCornerShape(ControlRadius))
                            .border(
                                width = if (isFocused) 2.dp else 1.dp,
                                color = borderColor,
                                shape = RoundedCornerShape(ControlRadius),
                            )
                            .focusRequester(focusRequesters[row][col])
                            .onFocusChanged { fs ->
                                if (fs.isFocused) onFocusChanged(row, col)
                            }
                            .searchClickable({ onKeyPressed(keyLabel) })
                            .onPreviewKeyEvent(
                                KeyPreviewHandler(
                                    onEnter = { onKeyPressed(keyLabel) },
                                    onLeft = {
                                        if (col > 0) focusRequesters[row][col - 1].requestFocus()
                                    },
                                    onRight = {
                                        if (isRightEdge) onArrowRightFromEdge(row, col)
                                        else focusRequesters[row][col + 1].requestFocus()
                                    },
                                    onUp = {
                                        if (isTopRow) onArrowUpFromTop()
                                        else {
                                            focusRequesters[row - 1][
                                                col.coerceAtMost(KeyboardKeys[row - 1].lastIndex),
                                            ].requestFocus()
                                        }
                                    },
                                    onDown = {
                                        if (isBottomRow) onArrowDownFromBottom()
                                        else {
                                            focusRequesters[row + 1][
                                                col.coerceAtMost(KeyboardKeys[row + 1].lastIndex),
                                            ].requestFocus()
                                        }
                                    },
                                    onBack = onBack,
                                ),
                            )
                            .focusable(interactionSource = interactionSource),
                        contentAlignment = Alignment.Center,
                    ) {
                        androidx.compose.material3.Text(
                            text = keyLabel,
                            color = Color.White,
                            fontSize = 21.sp,
                            fontWeight = if (isFocused) FontWeight.ExtraBold else FontWeight.Bold,
                        )
                    }
                }
            }
        }
    }
}

// ── 操作按钮行 ──

/**
 * 清空 / 搜索 / 删除三操作。
 *
 * @param clearFocus 清空按钮焦点。
 * @param searchFocus 搜索按钮焦点。
 * @param deleteFocus 删除按钮焦点。
 * @param onClear 清空输入。
 * @param onSearch 提交当前输入。
 * @param onDelete 删除末字符。
 * @param onBack 返回。
 * @param onArrowUpToKeyboard 上移回键盘对应列。
 * @param onArrowRightFromDelete 删除键右移进右面板。
 */
@Composable
private fun SearchActionRow(
    clearFocus: FocusRequester,
    searchFocus: FocusRequester,
    deleteFocus: FocusRequester,
    onClear: () -> Unit,
    onSearch: () -> Unit,
    onDelete: () -> Unit,
    onBack: () -> Unit,
    onArrowUpToKeyboard: (col: Int) -> Unit,
    onArrowRightFromDelete: () -> Unit,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        SearchActionButton(
            label = "清空",
            focusRequester = clearFocus,
            primary = false,
            onClick = onClear,
            onUp = { onArrowUpToKeyboard(0) },
            onBack = onBack,
        )
        SearchActionButton(
            label = "搜索",
            focusRequester = searchFocus,
            primary = true,
            onClick = onSearch,
            onUp = { onArrowUpToKeyboard(2) },
            onBack = onBack,
        )
        SearchActionButton(
            label = "删除",
            focusRequester = deleteFocus,
            primary = false,
            onClick = onDelete,
            onUp = { onArrowUpToKeyboard(5) },
            onRight = onArrowRightFromDelete,
            onBack = onBack,
        )
    }
}

/**
 * 单个搜索操作按钮。
 *
 * @param label 文案。
 * @param focusRequester 焦点请求器。
 * @param primary 是否主操作（搜索）。
 * @param onClick 点击/确认。
 * @param onUp 上方向。
 * @param onRight 右方向（仅删除需要）。
 * @param onBack 返回。
 */
@Composable
private fun RowScope.SearchActionButton(
    label: String,
    focusRequester: FocusRequester,
    primary: Boolean,
    onClick: () -> Unit,
    onUp: () -> Unit,
    onRight: (() -> Unit)? = null,
    onBack: () -> Unit = {},
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val idleBg = if (primary) SearchPalette.PrimaryIdle else SearchPalette.ControlIdle
    val focusedBg = if (primary) SearchPalette.PrimaryFocused else SearchPalette.ControlFocused
    val bgColor by animateColorAsState(
        if (isFocused) focusedBg else idleBg,
        tween(140),
        label = "searchActionBg",
    )
    val borderColor by animateColorAsState(
        if (isFocused) Color.White else Color.White.copy(alpha = 0.06f),
        tween(140),
        label = "searchActionBorder",
    )

    Box(
        modifier = Modifier
            .weight(1f)
            .height(46.dp)
            .background(bgColor, RoundedCornerShape(23.dp))
            .border(
                width = if (isFocused) 2.dp else 1.dp,
                color = borderColor,
                shape = RoundedCornerShape(23.dp),
            )
            .focusRequester(focusRequester)
            .searchClickable(onClick)
            .onPreviewKeyEvent(
                KeyPreviewHandler(
                    onEnter = onClick,
                    onDown = { /* stay */ },
                    onUp = onUp,
                    onRight = onRight,
                    onBack = onBack,
                ),
            )
            .focusable(interactionSource = interactionSource),
        contentAlignment = Alignment.Center,
    ) {
        androidx.compose.material3.Text(
            text = label,
            color = Color.White,
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}

// ── 右面板 ──

/**
 * 右侧内容区状态分发。
 *
 * @param state 搜索 UI 状态。
 * @param entryFocusRequester 右面板入口焦点。
 * @param onReturnToLeftPanel 左方向键回键盘。
 * @param onHotQueryClick 热词点击。
 * @param onSearchHistoryClick 历史点击。
 * @param onSuggestionClick 联想点击。
 * @param onClearHistory 清空历史。
 * @param onVideoClick 视频点击。
 * @param onBack 返回。
 * @param modifier 外层修饰。
 */
@Composable
private fun RightPanel(
    state: TvSearchUiState,
    entryFocusRequester: FocusRequester,
    onReturnToLeftPanel: () -> Unit,
    onHotQueryClick: (String) -> Unit,
    onSearchHistoryClick: (String) -> Unit,
    onSuggestionClick: (String) -> Unit,
    onClearHistory: () -> Unit,
    onVideoClick: (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    when {
        // 结果面板优先，对齐 Flutter `_shouldShowSearchResultPanel`。
        // 结果区自带 LazyVerticalGrid，不能再套 verticalScroll。
        state.showResultsPanel -> SearchResultPanel(
            state = state,
            entryFocusRequester = entryFocusRequester,
            onReturnToLeftPanel = onReturnToLeftPanel,
            onVideoClick = onVideoClick,
            onBack = onBack,
            modifier = modifier,
        )

        // 纯字母数字输入进入联想面板。
        state.showSuggestionPanel -> Column(modifier = modifier.verticalScroll(rememberScrollState())) {
            SearchSuggestionPanel(
                state = state,
                entryFocusRequester = entryFocusRequester,
                onReturnToLeftPanel = onReturnToLeftPanel,
                onSuggestionClick = onSuggestionClick,
                onVideoClick = onVideoClick,
                onBack = onBack,
            )
        }

        // 默认首页：历史 + 热词 + 推荐。
        else -> Column(modifier = modifier.verticalScroll(rememberScrollState())) {
            SearchDefaultPanel(
                state = state,
                entryFocusRequester = entryFocusRequester,
                onReturnToLeftPanel = onReturnToLeftPanel,
                onHotQueryClick = onHotQueryClick,
                onSearchHistoryClick = onSearchHistoryClick,
                onClearHistory = onClearHistory,
                onVideoClick = onVideoClick,
                onBack = onBack,
            )
        }
    }
}

// ── 默认面板 (历史+热词+推荐) ──

/**
 * 搜索首页默认内容。
 *
 * @param state 搜索 UI 状态。
 * @param entryFocusRequester 右面板入口焦点。
 * @param onReturnToLeftPanel 回键盘。
 * @param onHotQueryClick 热词点击（只回填）。
 * @param onSearchHistoryClick 历史点击（直接搜索）。
 * @param onClearHistory 清空历史。
 * @param onVideoClick 推荐卡片点击。
 * @param onBack 返回。
 */
@Composable
private fun SearchDefaultPanel(
    state: TvSearchUiState,
    entryFocusRequester: FocusRequester,
    onReturnToLeftPanel: () -> Unit,
    onHotQueryClick: (String) -> Unit,
    onSearchHistoryClick: (String) -> Unit,
    onClearHistory: () -> Unit,
    onVideoClick: (String) -> Unit,
    onBack: () -> Unit,
) {
    if (state.isBootstrapping) {
        TvSearchStatePanel(
            kind = TvStatePanelKind.Loading,
            title = "加载搜索页",
            message = "正在读取历史和推荐…",
            focusRequester = entryFocusRequester,
            onReturnToLeftPanel = onReturnToLeftPanel,
            onBack = onBack,
        )
        return
    }
    if (!state.bootstrapErrorMessage.isNullOrBlank()) {
        TvSearchStatePanel(
            kind = TvStatePanelKind.Error,
            title = "搜索页加载失败",
            message = state.bootstrapErrorMessage.orEmpty(),
            focusRequester = entryFocusRequester,
            onReturnToLeftPanel = onReturnToLeftPanel,
            onBack = onBack,
        )
        return
    }

    SectionTitle(
        title = "搜索历史",
        hint = if (state.searchHistory.isEmpty()) "暂无记录" else "${state.searchHistory.size} 条记录",
        trailingActionLabel = if (state.searchHistory.isNotEmpty()) "清空" else null,
        onTrailingAction = onClearHistory,
    )
    Spacer(modifier = Modifier.height(12.dp))
    if (state.searchHistory.isEmpty()) {
        SearchHintCard(
            title = "暂无搜索历史",
            message = "使用左侧键盘输入首字母，或点击搜索按钮。",
        )
    } else {
        WordTileGrid(
            words = state.searchHistory,
            entryFocusRequester = entryFocusRequester,
            onReturnToLeftPanel = onReturnToLeftPanel,
            // 历史词直接搜索，对齐 Flutter onWordPressed -> _performSearch。
            onWordClick = onSearchHistoryClick,
            onBack = onBack,
        )
    }

    if (state.hotQueries.isNotEmpty()) {
        Spacer(modifier = Modifier.height(28.dp))
        SectionTitle("搜索热词", "${state.hotQueries.size} 个推荐词")
        Spacer(modifier = Modifier.height(12.dp))
        WordTileGrid(
            words = state.hotQueries,
            entryFocusRequester = if (state.searchHistory.isEmpty()) entryFocusRequester else null,
            onReturnToLeftPanel = onReturnToLeftPanel,
            // 热词只回填，不直接搜索。
            onWordClick = onHotQueryClick,
            onBack = onBack,
        )
    }

    Spacer(modifier = Modifier.height(30.dp))
    SectionTitle("影片推荐", if (state.recommendCards.isEmpty()) "暂无推荐" else "${state.recommendCards.size} 部")
    Spacer(modifier = Modifier.height(12.dp))
    RecommendRail(
        cards = state.recommendCards,
        entryFocusRequester = if (state.searchHistory.isEmpty() && state.hotQueries.isEmpty()) {
            entryFocusRequester
        } else {
            null
        },
        onReturnToLeftPanel = onReturnToLeftPanel,
        onVideoClick = onVideoClick,
        onBack = onBack,
    )
}

// ── 联想面板 ──

/**
 * 输入过程中的联想结果面板。
 *
 * @param state 搜索 UI 状态。
 * @param entryFocusRequester 右面板入口焦点。
 * @param onReturnToLeftPanel 回键盘。
 * @param onSuggestionClick 联想词确认搜索。
 * @param onVideoClick 推荐卡片点击。
 * @param onBack 返回。
 */
@Composable
private fun SearchSuggestionPanel(
    state: TvSearchUiState,
    entryFocusRequester: FocusRequester,
    onReturnToLeftPanel: () -> Unit,
    onSuggestionClick: (String) -> Unit,
    onVideoClick: (String) -> Unit,
    onBack: () -> Unit,
) {
    SectionTitle(
        title = "联想结果",
        hint = if (state.isSuggestionLoading) "联想中…" else "${state.suggestions.size} 个结果",
    )
    Spacer(modifier = Modifier.height(12.dp))
    when {
        state.isSuggestionLoading -> {
            TvSearchStatePanel(
                kind = TvStatePanelKind.Loading,
                title = "联想中...",
                message = "正在根据首字母匹配影片名称。",
                focusRequester = entryFocusRequester,
                onReturnToLeftPanel = onReturnToLeftPanel,
                onBack = onBack,
            )
        }

        state.suggestions.isEmpty() -> {
            TvSearchStatePanel(
                kind = TvStatePanelKind.Empty,
                title = "暂无联想结果",
                message = "可继续输入，或直接点击搜索按钮。",
                focusRequester = entryFocusRequester,
                onReturnToLeftPanel = onReturnToLeftPanel,
                onBack = onBack,
            )
        }

        else -> {
            WordTileGrid(
                words = state.suggestions,
                entryFocusRequester = entryFocusRequester,
                onReturnToLeftPanel = onReturnToLeftPanel,
                // 联想词确认后直接搜索，并保留返回上下文。
                onWordClick = onSuggestionClick,
                onBack = onBack,
            )
            if (state.recommendCards.isNotEmpty()) {
                Spacer(modifier = Modifier.height(30.dp))
                SectionTitle("影片推荐", "${state.recommendCards.size} 部")
                Spacer(modifier = Modifier.height(12.dp))
                RecommendRail(
                    cards = state.recommendCards,
                    entryFocusRequester = null,
                    onReturnToLeftPanel = onReturnToLeftPanel,
                    onVideoClick = onVideoClick,
                    onBack = onBack,
                )
            }
        }
    }
}

/**
 * 分区标题行。
 *
 * @param title 主标题。
 * @param hint 次要说明。
 * @param trailingActionLabel 右侧操作文案。
 * @param onTrailingAction 右侧操作回调。
 */
@Composable
private fun SectionTitle(
    title: String,
    hint: String,
    trailingActionLabel: String? = null,
    onTrailingAction: (() -> Unit)? = null,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // 红竖条对齐详情页分区标题语言。
        Box(
            modifier = Modifier
                .width(3.dp)
                .height(18.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(SearchPalette.AccentBar),
        )
        Spacer(modifier = Modifier.width(10.dp))
        androidx.compose.material3.Text(
            text = title,
            color = Color.White,
            fontSize = 22.sp,
            fontWeight = FontWeight.ExtraBold,
        )
        Spacer(modifier = Modifier.width(12.dp))
        androidx.compose.material3.Text(
            text = hint,
            color = SearchPalette.Hint,
            fontSize = 13.sp,
        )
        if (!trailingActionLabel.isNullOrBlank() && onTrailingAction != null) {
            Spacer(modifier = Modifier.weight(1f))
            val interactionSource = remember { MutableInteractionSource() }
            val isFocused by interactionSource.collectIsFocusedAsState()
            Box(
                modifier = Modifier
                    .height(34.dp)
                    .background(
                        if (isFocused) SearchPalette.ControlFocused else SearchPalette.ControlIdle,
                        RoundedCornerShape(17.dp),
                    )
                    .border(
                        width = if (isFocused) 2.dp else 1.dp,
                        color = if (isFocused) Color.White else Color.White.copy(alpha = 0.08f),
                        shape = RoundedCornerShape(17.dp),
                    )
                    .searchClickable(onTrailingAction)
                    .onPreviewKeyEvent(
                        KeyPreviewHandler(
                            onEnter = onTrailingAction,
                        ),
                    )
                    .focusable(interactionSource = interactionSource)
                    .padding(horizontal = 14.dp),
                contentAlignment = Alignment.Center,
            ) {
                androidx.compose.material3.Text(
                    text = trailingActionLabel,
                    color = Color.White,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}

/**
 * 词块网格：历史 / 热词 / 联想共用。
 *
 * @param words 词列表。
 * @param entryFocusRequester 首项入口焦点。
 * @param onReturnToLeftPanel 左键回键盘。
 * @param onWordClick 词确认。
 * @param onBack 返回。
 */
@Composable
private fun WordTileGrid(
    words: List<String>,
    entryFocusRequester: FocusRequester?,
    onReturnToLeftPanel: () -> Unit,
    onWordClick: (String) -> Unit,
    onBack: () -> Unit,
) {
    val columns = 3
    val rows = (words.size + columns - 1) / columns
    val focusRequesters = remember(words.size) { List(words.size) { FocusRequester() } }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        for (row in 0 until rows) {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                for (col in 0 until columns) {
                    val index = row * columns + col
                    if (index < words.size) {
                        val word = words[index]
                        val interactionSource = remember { MutableInteractionSource() }
                        val isFocused by interactionSource.collectIsFocusedAsState()
                        val bgColor by animateColorAsState(
                            if (isFocused) SearchPalette.ControlFocused else SearchPalette.ControlIdle,
                            tween(140),
                            label = "wordTileBg",
                        )
                        val isFirst = index == 0

                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(46.dp)
                                .background(bgColor, RoundedCornerShape(12.dp))
                                .border(
                                    width = if (isFocused) 2.dp else 1.dp,
                                    color = if (isFocused) Color.White else Color.White.copy(alpha = 0.05f),
                                    shape = RoundedCornerShape(12.dp),
                                )
                                .then(
                                    if (isFirst && entryFocusRequester != null) {
                                        Modifier.focusRequester(entryFocusRequester)
                                    } else {
                                        Modifier.focusRequester(focusRequesters[index])
                                    },
                                )
                                .searchClickable({ onWordClick(word) })
                                .onPreviewKeyEvent(
                                    KeyPreviewHandler(
                                        onEnter = { onWordClick(word) },
                                        // 左缘回键盘；同行/跨行焦点逻辑保持原搜索页契约。
                                        onLeft = {
                                            if (col == 0) onReturnToLeftPanel()
                                            else focusRequesters.getOrNull(index - 1)?.requestFocus()
                                        },
                                        onRight = {
                                            focusRequesters.getOrNull(index + 1)?.requestFocus()
                                        },
                                        onUp = {
                                            focusRequesters.getOrNull(index - columns)?.requestFocus()
                                        },
                                        onDown = {
                                            focusRequesters.getOrNull(index + columns)?.requestFocus()
                                        },
                                        onBack = onBack,
                                    ),
                                )
                                .focusable(interactionSource = interactionSource)
                                .padding(horizontal = 14.dp),
                            contentAlignment = Alignment.CenterStart,
                        ) {
                            androidx.compose.material3.Text(
                                text = word,
                                color = Color.White,
                                fontSize = 15.sp,
                                fontWeight = if (isFocused) FontWeight.Bold else FontWeight.SemiBold,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    } else {
                        Spacer(modifier = Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

@Composable
private fun RecommendRail(
    cards: List<TvVideoCard>,
    entryFocusRequester: FocusRequester?,
    onReturnToLeftPanel: () -> Unit,
    onVideoClick: (String) -> Unit,
    onBack: () -> Unit,
) {
    if (cards.isEmpty()) {
        SearchHintCard(
            title = "暂无推荐",
            message = "观看详情后会在这里展示相关推荐。",
        )
        return
    }
    // 推荐区用横向轨道，避免嵌在 verticalScroll 中再次套 LazyVerticalGrid。
    // onReturnToLeftPanel/onBack 由外层词块或状态面板入口承接；海报轨首项承接 entryFocus。
    TvPosterRail(
        items = cards.map { video ->
            TvPosterItem(
                id = video.id,
                source = video.source.ifBlank { "douban" },
                title = video.title,
                subtitle = video.searchResultSubtitle(),
                posterUrl = video.posterUrl,
                totalEpisodes = video.totalEpisodes,
            )
        },
        firstItemFocusRequester = entryFocusRequester,
        onItemClick = { item -> onVideoClick(item.toVideoDetailKey()) },
    )
}

@Composable
private fun SearchResultPanel(
    state: TvSearchUiState,
    entryFocusRequester: FocusRequester,
    onReturnToLeftPanel: () -> Unit,
    onVideoClick: (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // 进度文案：有资源站总数时展示完成进度。
    val progressText = if (state.searchTotalResourceCount > 0) {
        "已搜索 ${state.searchCompletedResourceCount}/${state.searchTotalResourceCount} 个资源站"
    } else {
        null
    }

    Column(modifier = modifier.fillMaxSize()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .width(3.dp)
                    .height(18.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(SearchPalette.AccentBar),
            )
            Spacer(modifier = Modifier.width(10.dp))
            androidx.compose.material3.Text(
                text = "搜索结果",
                color = Color.White,
                fontSize = 22.sp,
                fontWeight = FontWeight.ExtraBold,
            )
            Spacer(modifier = Modifier.width(12.dp))
            androidx.compose.material3.Text(
                text = "${state.resultCards.size} 个影片",
                color = SearchPalette.Hint,
                fontSize = 13.sp,
            )
            if (!progressText.isNullOrBlank()) {
                Spacer(modifier = Modifier.width(12.dp))
                Box(
                    modifier = Modifier
                        .background(SearchPalette.ControlIdle, RoundedCornerShape(12.dp))
                        .padding(horizontal = 10.dp, vertical = 4.dp),
                ) {
                    androidx.compose.material3.Text(
                        text = progressText,
                        color = Color(0xFFB0B7C3),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }
        Spacer(modifier = Modifier.height(14.dp))

        when {
            state.isSearchResultLoading && state.resultCards.isEmpty() -> TvSearchStatePanel(
                kind = TvStatePanelKind.Loading,
                title = "正在搜索 ${state.query}",
                message = progressText ?: "正在聚合各资源站结果…",
                focusRequester = entryFocusRequester,
                onReturnToLeftPanel = onReturnToLeftPanel,
                onBack = onBack,
            )

            !state.errorMessage.isNullOrBlank() && state.resultCards.isEmpty() -> TvSearchStatePanel(
                kind = TvStatePanelKind.Error,
                title = "搜索失败",
                message = state.errorMessage.orEmpty(),
                focusRequester = entryFocusRequester,
                onReturnToLeftPanel = onReturnToLeftPanel,
                onBack = onBack,
            )

            !state.isSearchResultLoading && state.resultCards.isEmpty() -> TvSearchStatePanel(
                kind = TvStatePanelKind.Empty,
                title = "暂无搜索结果",
                message = "尝试使用其他关键词搜索。",
                focusRequester = entryFocusRequester,
                onReturnToLeftPanel = onReturnToLeftPanel,
                onBack = onBack,
            )

            else -> {
                TvPosterGrid(
                    items = state.resultCards.map { video ->
                        TvPosterItem(
                            id = video.id,
                            source = video.source,
                            title = video.title,
                            subtitle = video.searchResultSubtitle(),
                            posterUrl = video.posterUrl,
                            totalEpisodes = video.totalEpisodes,
                        )
                    },
                    columns = 5,
                    modifier = Modifier.fillMaxSize(),
                    firstItemFocusRequester = entryFocusRequester,
                    onItemClick = { item -> onVideoClick(item.toVideoDetailKey()) },
                )
            }
        }
    }
}

@Composable
private fun SearchHintCard(
    title: String,
    message: String,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(SearchPalette.ControlIdle.copy(alpha = 0.55f), RoundedCornerShape(14.dp))
            .border(1.dp, Color.White.copy(alpha = 0.05f), RoundedCornerShape(14.dp))
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        androidx.compose.material3.Text(
            text = title,
            color = Color.White,
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
        )
        androidx.compose.material3.Text(
            text = message,
            color = SearchPalette.Hint,
            fontSize = 13.sp,
        )
    }
}

/**
 * 搜索右侧状态面板，承接键盘右移入口并支持左键回键盘。
 *
 * @param kind 状态类型。
 * @param title 标题。
 * @param message 说明。
 * @param focusRequester 入口焦点。
 * @param onReturnToLeftPanel 回键盘。
 * @param onBack 返回。
 */
@Composable
private fun TvSearchStatePanel(
    kind: TvStatePanelKind,
    title: String,
    message: String,
    focusRequester: FocusRequester,
    onReturnToLeftPanel: () -> Unit,
    onBack: () -> Unit,
) {
    Box(
        modifier = Modifier
            .focusRequester(focusRequester)
            .onPreviewKeyEvent(
                KeyPreviewHandler(
                    onLeft = onReturnToLeftPanel,
                    onBack = onBack,
                ),
            )
            .focusable(),
    ) {
        TvStatePanel(kind = kind, title = title, message = message)
    }
}

/**
 * 搜索结果副标题：年份 · 来源。
 *
 * @receiver 视频卡片。
 * @return 展示副标题。
 */
private fun TvVideoCard.searchResultSubtitle(): String = buildList {
    if (year.isNotBlank()) add(year)
    if (sourceName.isNotBlank()) add(sourceName)
}.joinToString(" · ").ifBlank { "结果" }

// ── 通用按键处理：只消费手动处理的键，Back/其他键全程放行 ──

/**
 * 为可获焦组件生成 onPreviewKeyEvent 处理器。
 *
 * 设计原则：
 * - 方向键/确认键 → KeyDown 处理并消费，KeyUp 也消费（防止重复触发）
 * - Back 键 → 全程不消费，交给 NavHost 处理
 * - 其他键 → 不消费，交给上层
 *
 * @param onEnter 确认。
 * @param onLeft 左。
 * @param onRight 右。
 * @param onUp 上。
 * @param onDown 下。
 * @param onBack 返回（仅作业务回调位，实际不消费 Back 键）。
 * @return 预览按键处理器。
 */
private fun KeyPreviewHandler(
    onEnter: (() -> Unit)? = null,
    onLeft: (() -> Unit)? = null,
    onRight: (() -> Unit)? = null,
    onUp: (() -> Unit)? = null,
    onDown: (() -> Unit)? = null,
    onBack: (() -> Unit)? = null,
): (androidx.compose.ui.input.key.KeyEvent) -> Boolean = { event ->
    val isKeyUp = event.type == KeyEventType.KeyUp
    when (event.key) {
        Key.Back -> false // 全程放行给 NavHost
        Key.DirectionCenter, Key.Enter, Key.NumPadEnter, Key.Spacebar -> {
            if (isKeyUp) true
            else {
                onEnter?.invoke()
                true
            }
        }
        Key.DirectionUp -> {
            if (isKeyUp) true
            else {
                onUp?.invoke()
                true
            }
        }
        Key.DirectionDown -> {
            if (isKeyUp) true
            else {
                onDown?.invoke()
                true
            }
        }
        Key.DirectionLeft -> {
            if (isKeyUp) true
            else {
                onLeft?.invoke()
                true
            }
        }
        Key.DirectionRight -> {
            if (isKeyUp) true
            else {
                onRight?.invoke()
                true
            }
        }
        else -> false
    }
}

/**
 * 搜索页可交互节点的鼠标/触摸点击，与确认键等价。
 *
 * @param onClick 点击回调。
 * @return 修饰后的 Modifier。
 */
private fun Modifier.searchClickable(onClick: () -> Unit): Modifier {
    return tvPointerClickable(onClick = onClick)
}
