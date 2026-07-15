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
import androidx.compose.ui.layout.layout
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
/** 左右面板之间的间距。 */
private val RightPanelStartPadding: Dp = 24.dp
/**
 * 右面板内容区水平内边距（标题、历史/热词词块共用）。
 *
 * 影片推荐轨会负向抵消这一层，改由 LazyRow 自己的 contentPadding 管左右停靠，
 * 这样横滑时卡片能从面板缘进出，不被父级大边距二次夹死。
 */
private val RightPanelContentHorizontal: Dp = 22.dp
/** 右面板内容区垂直内边距。 */
private val RightPanelContentVertical: Dp = 20.dp
/**
 * 影片推荐轨左侧 contentPadding。
 *
 * 静止态首卡与「影片推荐」标题左缘对齐；与 [RightPanelContentHorizontal] 解耦，可单独调。
 */
private val RecommendRailStartPadding: Dp = RightPanelContentHorizontal
/**
 * 影片推荐轨右侧 contentPadding。
 *
 * 末端收口用，默认可大于左侧，保证末卡获焦描边/放大不贴面板右缘。
 */
private val RecommendRailEndPadding: Dp = 32.dp
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
    // 右栏按垂直位置分入口：历史/联想/结果、热词、推荐，左右切换按分带就近落点。
    val rightHistoryEntryFocus = remember { FocusRequester() }
    val rightHotEntryFocus = remember { FocusRequester() }
    val rightRecommendEntryFocus = remember { FocusRequester() }
    var lastKeyboardRow by remember { mutableStateOf(0) }
    var lastKeyboardCol by remember { mutableStateOf(0) }

    // 首焦点落在键盘 A。
    LaunchedEffect(Unit) {
        keyFocusRequesters[0][0].requestFocus()
    }

    /**
     * 从键盘右缘进入右栏：按键所在行映射到历史 / 热词 / 推荐分带，缺失时向下一带回落。
     */
    fun focusRightPanelFromKeyboardRow(row: Int) {
        val targets = resolveRightPanelEntriesForKeyboardRow(
            row = row,
            state = state,
            historyEntry = rightHistoryEntryFocus,
            hotEntry = rightHotEntryFocus,
            recommendEntry = rightRecommendEntryFocus,
        )
        for (requester in targets) {
            val gained = runCatching { requester.requestFocus() }.getOrDefault(false)
            if (gained) {
                return
            }
        }
    }

    /**
     * 从右栏左缘回键盘：按当前分带落到对应键行，列保持离开键盘前的位置。
     */
    fun returnToLeftPanel(band: SearchRightFocusBand) {
        val row = resolveKeyboardRowForRightBand(
            band = band,
            lastKeyboardRow = lastKeyboardRow,
        )
        val col = lastKeyboardCol.coerceIn(0, KeyboardColumns - 1)
        runCatching { keyFocusRequesters[row][col].requestFocus() }
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
                        // 按键行高度进入右栏对应分带（上→历史、中→热词、下→推荐）。
                        focusRightPanelFromKeyboardRow(row)
                    },
                    // 底行下键：落到操作行对应按钮（列映射），形成与操作行的环形贯通。
                    onArrowDownFromBottom = { col ->
                        when {
                            col <= 1 -> clearButtonFocus.requestFocus()
                            col <= 3 -> searchButtonFocus.requestFocus()
                            else -> deleteButtonFocus.requestFocus()
                        }
                    },
                    // 顶行上键：落到操作行（整页上下环形：顶↔底）。
                    onArrowUpFromTop = { col ->
                        when {
                            col <= 1 -> clearButtonFocus.requestFocus()
                            col <= 3 -> searchButtonFocus.requestFocus()
                            else -> deleteButtonFocus.requestFocus()
                        }
                    },
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
                        keyFocusRequesters[KeyboardRows - 1][col.coerceIn(0, KeyboardColumns - 1)]
                            .requestFocus()
                    },
                    onArrowDownToKeyboard = { col ->
                        keyFocusRequesters[0][col.coerceIn(0, KeyboardColumns - 1)].requestFocus()
                    },
                    onArrowRightFromDelete = {
                        // 底栏右移：优先进推荐分带（与键盘底行同高），再回落其它区。
                        focusRightPanelFromKeyboardRow(KeyboardRows - 1)
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
                    .padding(
                        horizontal = RightPanelContentHorizontal,
                        vertical = RightPanelContentVertical,
                    ),
            ) {
                RightPanel(
                    state = state,
                    historyEntryFocus = rightHistoryEntryFocus,
                    hotEntryFocus = rightHotEntryFocus,
                    recommendEntryFocus = rightRecommendEntryFocus,
                    onReturnToLeftPanel = ::returnToLeftPanel,
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
 * 焦点：行内左环形、右缘进右面板；顶/底行与下方操作按钮上下贯通环形。
 * 键盘按键只消费方向键和确认键，Back 键全程放行。
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
    onArrowDownFromBottom: (col: Int) -> Unit,
    onArrowUpFromTop: (col: Int) -> Unit,
    onBack: () -> Unit,
    onFocusChanged: (row: Int, col: Int) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        KeyboardKeys.forEachIndexed { row, keys ->
            Row(horizontalArrangement = Arrangement.spacedBy(KeySpacing)) {
                keys.forEachIndexed { col, keyLabel ->
                    val isRightEdge = col == keys.lastIndex
                    val isLeftEdge = col == 0
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
                                        if (isLeftEdge) {
                                            // 行内左环形：首列左键落到本行末列。
                                            focusRequesters[row][keys.lastIndex].requestFocus()
                                        } else {
                                            focusRequesters[row][col - 1].requestFocus()
                                        }
                                    },
                                    onRight = {
                                        if (isRightEdge) {
                                            // 右缘仍进右面板（保留跨栏逻辑）。
                                            onArrowRightFromEdge(row, col)
                                        } else {
                                            focusRequesters[row][col + 1].requestFocus()
                                        }
                                    },
                                    onUp = {
                                        if (isTopRow) {
                                            onArrowUpFromTop(col)
                                        } else {
                                            focusRequesters[row - 1][
                                                col.coerceAtMost(KeyboardKeys[row - 1].lastIndex),
                                            ].requestFocus()
                                        }
                                    },
                                    onDown = {
                                        if (isBottomRow) {
                                            onArrowDownFromBottom(col)
                                        } else {
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
 * 三键左右可切换；左右两端环形互跳；上下与键盘首/末行贯通。
 *
 * @param clearFocus 清空按钮焦点。
 * @param searchFocus 搜索按钮焦点。
 * @param deleteFocus 删除按钮焦点。
 * @param onClear 清空输入。
 * @param onSearch 提交当前输入。
 * @param onDelete 删除末字符。
 * @param onBack 返回。
 * @param onArrowUpToKeyboard 上移回键盘底行对应列。
 * @param onArrowDownToKeyboard 下移回键盘顶行对应列（整页上下环形）。
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
    onArrowDownToKeyboard: (col: Int) -> Unit,
    onArrowRightFromDelete: () -> Unit,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        SearchActionButton(
            label = "清空",
            focusRequester = clearFocus,
            primary = false,
            onClick = onClear,
            onLeft = { deleteFocus.requestFocus() },
            onRight = { searchFocus.requestFocus() },
            onUp = { onArrowUpToKeyboard(0) },
            onDown = { onArrowDownToKeyboard(0) },
            onBack = onBack,
        )
        SearchActionButton(
            label = "搜索",
            focusRequester = searchFocus,
            primary = true,
            onClick = onSearch,
            onLeft = { clearFocus.requestFocus() },
            onRight = { deleteFocus.requestFocus() },
            onUp = { onArrowUpToKeyboard(2) },
            onDown = { onArrowDownToKeyboard(2) },
            onBack = onBack,
        )
        SearchActionButton(
            label = "删除",
            focusRequester = deleteFocus,
            primary = false,
            onClick = onDelete,
            onLeft = { searchFocus.requestFocus() },
            onRight = onArrowRightFromDelete,
            onUp = { onArrowUpToKeyboard(5) },
            onDown = { onArrowDownToKeyboard(5) },
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
 * @param onLeft 左方向。
 * @param onRight 右方向。
 * @param onUp 上方向。
 * @param onDown 下方向。
 * @param onBack 返回。
 */
@Composable
private fun RowScope.SearchActionButton(
    label: String,
    focusRequester: FocusRequester,
    primary: Boolean,
    onClick: () -> Unit,
    onLeft: (() -> Unit)? = null,
    onRight: (() -> Unit)? = null,
    onUp: () -> Unit,
    onDown: () -> Unit = {},
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
                    onLeft = onLeft,
                    onRight = onRight,
                    onUp = onUp,
                    onDown = onDown,
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
 * @param historyEntryFocus 历史上区 / 联想 / 结果入口。
 * @param hotEntryFocus 热词中区入口。
 * @param recommendEntryFocus 推荐下区入口。
 * @param onReturnToLeftPanel 左方向键按分带回键盘。
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
    historyEntryFocus: FocusRequester,
    hotEntryFocus: FocusRequester,
    recommendEntryFocus: FocusRequester,
    onReturnToLeftPanel: (SearchRightFocusBand) -> Unit,
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
            entryFocusRequester = historyEntryFocus,
            onReturnToLeftPanel = { onReturnToLeftPanel(SearchRightFocusBand.Generic) },
            onVideoClick = onVideoClick,
            onBack = onBack,
            modifier = modifier,
        )

        // 纯字母数字输入进入联想面板。
        state.showSuggestionPanel -> Column(modifier = modifier.verticalScroll(rememberScrollState())) {
            SearchSuggestionPanel(
                state = state,
                entryFocusRequester = historyEntryFocus,
                recommendEntryFocus = recommendEntryFocus,
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
                historyEntryFocus = historyEntryFocus,
                hotEntryFocus = hotEntryFocus,
                recommendEntryFocus = recommendEntryFocus,
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
 * @param historyEntryFocus 历史上区入口。
 * @param hotEntryFocus 热词中区入口。
 * @param recommendEntryFocus 推荐下区入口。
 * @param onReturnToLeftPanel 按分带回键盘。
 * @param onHotQueryClick 热词点击（只回填）。
 * @param onSearchHistoryClick 历史点击（直接搜索）。
 * @param onClearHistory 清空历史。
 * @param onVideoClick 推荐卡片点击。
 * @param onBack 返回。
 */
@Composable
private fun SearchDefaultPanel(
    state: TvSearchUiState,
    historyEntryFocus: FocusRequester,
    hotEntryFocus: FocusRequester,
    recommendEntryFocus: FocusRequester,
    onReturnToLeftPanel: (SearchRightFocusBand) -> Unit,
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
            focusRequester = historyEntryFocus,
            onReturnToLeftPanel = { onReturnToLeftPanel(SearchRightFocusBand.Generic) },
            onBack = onBack,
        )
        return
    }
    if (!state.bootstrapErrorMessage.isNullOrBlank()) {
        TvSearchStatePanel(
            kind = TvStatePanelKind.Error,
            title = "搜索页加载失败",
            message = state.bootstrapErrorMessage.orEmpty(),
            focusRequester = historyEntryFocus,
            onReturnToLeftPanel = { onReturnToLeftPanel(SearchRightFocusBand.Generic) },
            onBack = onBack,
        )
        return
    }

    // 右栏各区块：区内同列上下；跨区也按同列就近，不跳到对方首项。
    val hasHistory = state.searchHistory.isNotEmpty()
    val hasHot = state.hotQueries.isNotEmpty()
    val hasRecommend = state.recommendCards.isNotEmpty()
    val wordColumns = WordTileColumns
    // 历史/热词 requester 提到面板级，跨区上下才能点名「紧挨着」的同列项。
    val historyFocusRequesters = rememberWordTileFocusRequesters(
        itemCount = state.searchHistory.size,
        entryFocusRequester = historyEntryFocus,
    )
    val hotFocusRequesters = rememberWordTileFocusRequesters(
        itemCount = state.hotQueries.size,
        entryFocusRequester = hotEntryFocus,
    )

    SectionTitle(
        title = "搜索历史",
        hint = if (!hasHistory) "暂无记录" else "${state.searchHistory.size} 条记录",
        trailingActionLabel = if (hasHistory) "清空" else null,
        onTrailingAction = onClearHistory,
        // 标题旁「清空」可获焦；下/左落到历史首词，避免焦点悬空或锁死。
        onTrailingArrowDown = {
            runCatching { historyEntryFocus.requestFocus() }
        },
        onTrailingArrowLeft = {
            runCatching { historyEntryFocus.requestFocus() }
        },
        onTrailingReturnToLeft = { onReturnToLeftPanel(SearchRightFocusBand.History) },
    )
    Spacer(modifier = Modifier.height(12.dp))
    if (!hasHistory) {
        SearchHintCard(
            title = "暂无搜索历史",
            message = "使用左侧键盘输入首字母，或点击搜索按钮。",
        )
    } else {
        WordTileGrid(
            words = state.searchHistory,
            itemFocusRequesters = historyFocusRequesters,
            onReturnToLeftPanel = { onReturnToLeftPanel(SearchRightFocusBand.History) },
            // 历史词直接搜索，对齐 Flutter onWordPressed -> _performSearch。
            onWordClick = onSearchHistoryClick,
            onBack = onBack,
            onArrowDownFromBottom = { col ->
                when {
                    hasHot -> {
                        // 同列落到热词首行，紧挨着下移。
                        val target = resolveWordTileTopRowIndex(
                            itemCount = state.hotQueries.size,
                            columns = wordColumns,
                            column = col,
                        )
                        runCatching { hotFocusRequesters[target].requestFocus() }
                    }
                    hasRecommend -> runCatching { recommendEntryFocus.requestFocus() }
                }
            },
        )
    }

    if (hasHot) {
        Spacer(modifier = Modifier.height(28.dp))
        SectionTitle("搜索热词", "${state.hotQueries.size} 个推荐词")
        Spacer(modifier = Modifier.height(12.dp))
        WordTileGrid(
            words = state.hotQueries,
            itemFocusRequesters = hotFocusRequesters,
            onReturnToLeftPanel = { onReturnToLeftPanel(SearchRightFocusBand.Hot) },
            // 热词只回填，不直接搜索。
            onWordClick = onHotQueryClick,
            onBack = onBack,
            onArrowUpFromTop = { col ->
                if (hasHistory) {
                    // 同列落到历史上区底行，紧挨着上移，禁止跳历史首项。
                    val target = resolveWordTileBottomRowIndex(
                        itemCount = state.searchHistory.size,
                        columns = wordColumns,
                        column = col,
                    )
                    runCatching { historyFocusRequesters[target].requestFocus() }
                }
            },
            onArrowDownFromBottom = {
                if (hasRecommend) {
                    runCatching { recommendEntryFocus.requestFocus() }
                }
            },
        )
    }

    Spacer(modifier = Modifier.height(30.dp))
    SectionTitle("影片推荐", if (!hasRecommend) "暂无推荐" else "${state.recommendCards.size} 部")
    Spacer(modifier = Modifier.height(12.dp))
    RecommendRail(
        cards = state.recommendCards,
        entryFocusRequester = if (hasRecommend) recommendEntryFocus else null,
        onReturnToLeftPanel = { onReturnToLeftPanel(SearchRightFocusBand.Recommend) },
        onVideoClick = onVideoClick,
        onBack = onBack,
    )
}

// ── 联想面板 ──

/**
 * 输入过程中的联想结果面板。
 *
 * @param state 搜索 UI 状态。
 * @param entryFocusRequester 联想词上区入口。
 * @param recommendEntryFocus 推荐下区入口。
 * @param onReturnToLeftPanel 按分带回键盘。
 * @param onSuggestionClick 联想词确认搜索。
 * @param onVideoClick 推荐卡片点击。
 * @param onBack 返回。
 */
@Composable
private fun SearchSuggestionPanel(
    state: TvSearchUiState,
    entryFocusRequester: FocusRequester,
    recommendEntryFocus: FocusRequester,
    onReturnToLeftPanel: (SearchRightFocusBand) -> Unit,
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
                onReturnToLeftPanel = { onReturnToLeftPanel(SearchRightFocusBand.History) },
                onBack = onBack,
            )
        }

        state.suggestions.isEmpty() -> {
            TvSearchStatePanel(
                kind = TvStatePanelKind.Empty,
                title = "暂无联想结果",
                message = "可继续输入，或直接点击搜索按钮。",
                focusRequester = entryFocusRequester,
                onReturnToLeftPanel = { onReturnToLeftPanel(SearchRightFocusBand.History) },
                onBack = onBack,
            )
        }

        else -> {
            val hasRecommend = state.recommendCards.isNotEmpty()
            val suggestionFocusRequesters = rememberWordTileFocusRequesters(
                itemCount = state.suggestions.size,
                entryFocusRequester = entryFocusRequester,
            )
            WordTileGrid(
                words = state.suggestions,
                itemFocusRequesters = suggestionFocusRequesters,
                onReturnToLeftPanel = { onReturnToLeftPanel(SearchRightFocusBand.History) },
                // 联想词确认后直接搜索，并保留返回上下文。
                onWordClick = onSuggestionClick,
                onBack = onBack,
                onArrowDownFromBottom = {
                    if (hasRecommend) {
                        runCatching { recommendEntryFocus.requestFocus() }
                    }
                },
            )
            if (hasRecommend) {
                Spacer(modifier = Modifier.height(30.dp))
                SectionTitle("影片推荐", "${state.recommendCards.size} 部")
                Spacer(modifier = Modifier.height(12.dp))
                RecommendRail(
                    cards = state.recommendCards,
                    entryFocusRequester = recommendEntryFocus,
                    onReturnToLeftPanel = { onReturnToLeftPanel(SearchRightFocusBand.Recommend) },
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
 * @param onTrailingArrowDown 标题操作钮下键（通常落到本区首词）。
 * @param onTrailingArrowLeft 标题操作钮左键（落到本区首词）。
 * @param onTrailingReturnToLeft 标题操作钮再左/需要回左栏时。
 */
@Composable
private fun SectionTitle(
    title: String,
    hint: String,
    trailingActionLabel: String? = null,
    onTrailingAction: (() -> Unit)? = null,
    onTrailingArrowDown: (() -> Unit)? = null,
    onTrailingArrowLeft: (() -> Unit)? = null,
    onTrailingReturnToLeft: (() -> Unit)? = null,
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
                            onDown = onTrailingArrowDown,
                            onLeft = onTrailingArrowLeft ?: onTrailingReturnToLeft,
                            onUp = onTrailingReturnToLeft,
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
 * 右侧内容区**不环形**：底行下键交给 [onArrowDownFromBottom] 离开本区，
 * 顶行上键交给 [onArrowUpFromTop]；跨区携带列号以便同列就近落点。
 *
 * @param words 词列表。
 * @param itemFocusRequesters 与 [words] 等长的焦点请求器；首项应即入口 requester 本体。
 * @param onReturnToLeftPanel 左键回键盘。
 * @param onWordClick 词确认。
 * @param onBack 返回。
 * @param onArrowDownFromBottom 底行下键（离开本网格，参数为当前列）。
 * @param onArrowUpFromTop 顶行上键（离开本网格，参数为当前列）。
 */
@Composable
private fun WordTileGrid(
    words: List<String>,
    itemFocusRequesters: List<FocusRequester>,
    onReturnToLeftPanel: () -> Unit,
    onWordClick: (String) -> Unit,
    onBack: () -> Unit,
    onArrowDownFromBottom: ((column: Int) -> Unit)? = null,
    onArrowUpFromTop: ((column: Int) -> Unit)? = null,
) {
    val columns = WordTileColumns
    val rows = (words.size + columns - 1) / columns
    require(itemFocusRequesters.size >= words.size) {
        "itemFocusRequesters size must cover words"
    }

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
                        val lastIndex = words.lastIndex
                        val itemFocus = itemFocusRequesters[index]

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
                                .focusRequester(itemFocus)
                                .searchClickable({ onWordClick(word) })
                                .onPreviewKeyEvent(
                                    KeyPreviewHandler(
                                        onEnter = { onWordClick(word) },
                                        // 左缘回键盘；区内左右不环形。
                                        onLeft = {
                                            if (col == 0) {
                                                onReturnToLeftPanel()
                                            } else {
                                                itemFocusRequesters.getOrNull(index - 1)
                                                    ?.let { runCatching { it.requestFocus() } }
                                            }
                                        },
                                        onRight = {
                                            if (index < lastIndex) {
                                                itemFocusRequesters.getOrNull(index + 1)
                                                    ?.let { runCatching { it.requestFocus() } }
                                            }
                                        },
                                        onUp = {
                                            val up = index - columns
                                            if (up >= 0) {
                                                itemFocusRequesters.getOrNull(up)
                                                    ?.let { runCatching { it.requestFocus() } }
                                            } else {
                                                // 顶行上键：把列号交给外层，落到上区同列底项。
                                                onArrowUpFromTop?.invoke(col)
                                            }
                                        },
                                        onDown = {
                                            val down = index + columns
                                            if (down <= lastIndex) {
                                                itemFocusRequesters.getOrNull(down)
                                                    ?.let { runCatching { it.requestFocus() } }
                                            } else {
                                                // 底行下键：把列号交给外层，落到下区同列首项。
                                                onArrowDownFromBottom?.invoke(col)
                                            }
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
    // 契约（对齐 TV 横向列表 skill / 详情页 LazyRow）：
    // 1) 视口贴齐右面板左右缘（layout 外扩，禁止负 padding，会崩溃）
    // 2) 左右停靠边距只写在 LazyRow contentPadding，且可独立设置
    // 3) 滚动时卡片可从面板缘进出；静止时首/末卡仍有呼吸边距
    // 4) 首项左键按推荐分带回键盘，与键盘底行同高落点
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
        // 用 layout 外扩抵消父级 content 水平 padding，贴齐面板圆角内缘。
        modifier = Modifier.horizontalBleed(RightPanelContentHorizontal),
        firstItemFocusRequester = entryFocusRequester,
        contentStartPadding = RecommendRailStartPadding,
        contentEndPadding = RecommendRailEndPadding,
        onLeftFromFirst = onReturnToLeftPanel,
        onItemClick = { item -> onVideoClick(item.toVideoDetailKey()) },
    )
}

/**
 * 左右外扩 [bleed]，在父级已有对称水平 padding 时让子项视口贴齐容器缘。
 *
 * 不用负 [Modifier.padding]：Compose 要求 padding ≥ 0，负值会抛
 * `IllegalArgumentException: Padding must be non-negative`。
 *
 * @param bleed 单侧外扩量（通常等于父级 horizontal padding）。
 * @return 布局后左右各多占 [bleed] 的修饰器。
 */
private fun Modifier.horizontalBleed(bleed: Dp): Modifier {
    if (bleed <= 0.dp) {
        return this
    }
    return layout { measurable, constraints ->
        val bleedPx = bleed.roundToPx().coerceAtLeast(0)
        val expandedMaxWidth = (constraints.maxWidth + bleedPx * 2).coerceAtLeast(0)
        val placeable = measurable.measure(
            constraints.copy(
                minWidth = 0,
                maxWidth = expandedMaxWidth,
            ),
        )
        // 对外仍报告父级可用宽度，内容向左偏移 bleed，使左右对称外扩。
        layout(constraints.maxWidth, placeable.height) {
            placeable.placeRelative(-bleedPx, 0)
        }
    }
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
            state.isSearchResultLoading && state.resultCards.isEmpty() -> SearchResultLoadingCard(
                query = state.query,
                progressText = progressText,
                completed = state.searchCompletedResourceCount,
                total = state.searchTotalResourceCount,
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
                // 5 列铺满格宽；顶留白防首行放大裁切；上下行间距加宽。
                TvPosterGrid(
                    items = state.resultCards.map { video ->
                        TvPosterItem(
                            id = video.id,
                            source = video.source,
                            title = video.title,
                            subtitle = video.searchResultSubtitle(),
                            posterUrl = video.posterUrl,
                            totalEpisodes = video.totalEpisodes,
                            rating = video.doubanRate,
                        )
                    },
                    columns = 5,
                    modifier = Modifier.fillMaxSize(),
                    contentHorizontalPadding = 2.dp,
                    contentTopPadding = 14.dp,
                    // 底留白加大：末行封面+标题+焦点放大后仍能完整停在视口内。
                    contentBottomPadding = 40.dp,
                    horizontalSpacing = 12.dp,
                    verticalSpacing = 32.dp,
                    fillCellWidth = true,
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
/**
 * 搜索结果加载态：与搜索页色板统一，轻进度条 + 副文案，避免通用状态卡「小方块贴左」发闷。
 *
 * @param query 当前关键词。
 * @param progressText 进度副文案。
 * @param completed 已完成资源站数。
 * @param total 资源站总数。
 * @param focusRequester 右栏入口焦点。
 * @param onReturnToLeftPanel 左键回键盘。
 * @param onBack 返回。
 */
@Composable
private fun SearchResultLoadingCard(
    query: String,
    progressText: String?,
    completed: Int,
    total: Int,
    focusRequester: FocusRequester,
    onReturnToLeftPanel: () -> Unit,
    onBack: () -> Unit,
) {
    val progress = if (total > 0) {
        (completed.toFloat() / total.toFloat()).coerceIn(0f, 1f)
    } else {
        0f
    }
    val displayQuery = query.trim().ifBlank { "…" }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .focusRequester(focusRequester)
            .onPreviewKeyEvent(
                KeyPreviewHandler(
                    onLeft = onReturnToLeftPanel,
                    onBack = onBack,
                ),
            )
            .focusable()
            .background(
                color = SearchPalette.ControlIdle.copy(alpha = 0.72f),
                shape = RoundedCornerShape(16.dp),
            )
            .border(
                width = 1.dp,
                color = Color.White.copy(alpha = 0.06f),
                shape = RoundedCornerShape(16.dp),
            )
            .padding(horizontal = 20.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            androidx.compose.material3.CircularProgressIndicator(
                modifier = Modifier.size(22.dp),
                color = SearchPalette.AccentBar,
                strokeWidth = 2.5.dp,
            )
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                androidx.compose.material3.Text(
                    text = "正在搜索「$displayQuery」",
                    color = Color.White,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                androidx.compose.material3.Text(
                    text = progressText ?: "正在聚合各资源站结果…",
                    color = SearchPalette.Hint,
                    fontSize = 13.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        // 轻进度条：有总数时跟真实进度，否则细轨道呼吸感静态底。
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(4.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(Color.White.copy(alpha = 0.08f)),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(if (total > 0) progress.coerceAtLeast(0.04f) else 0.22f)
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(SearchPalette.AccentBar.copy(alpha = 0.85f)),
            )
        }
    }
}

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
        // 空/错态也跟搜索页色板，避免通用 TvStatePanel 冷绿边在深色右栏突兀。
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    color = SearchPalette.ControlIdle.copy(alpha = 0.72f),
                    shape = RoundedCornerShape(16.dp),
                )
                .border(
                    width = 1.dp,
                    color = when (kind) {
                        TvStatePanelKind.Error -> Color(0xFFB84A4A).copy(alpha = 0.55f)
                        else -> Color.White.copy(alpha = 0.06f)
                    },
                    shape = RoundedCornerShape(16.dp),
                )
                .padding(horizontal = 20.dp, vertical = 18.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            androidx.compose.material3.Text(
                text = title,
                color = Color.White,
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold,
            )
            androidx.compose.material3.Text(
                text = message,
                color = SearchPalette.Hint,
                fontSize = 13.sp,
            )
        }
    }
}

/**
 * 搜索结果副标题：年份 · 来源（来源去重，避免重复拼接）。
 *
 * @receiver 视频卡片。
 * @return 展示副标题。
 */
private fun TvVideoCard.searchResultSubtitle(): String {
    val yearPart = year.trim()
    // 拆分「A / B」「A、B」等再去重，防止接口/聚合导致来源字面重复。
    val sourceParts = sourceName
        .split(Regex("[/|,，、·]+"))
        .map { part -> part.trim() }
        .filter { part -> part.isNotEmpty() }
        .distinctBy { part -> part.replace(Regex("\\s+"), "").lowercase() }
    val sourcePart = when {
        sourceParts.isEmpty() -> ""
        sourceParts.size == 1 -> sourceParts.first()
        else -> "${sourceParts.first()} 等${sourceParts.size}源"
    }
    return buildList {
        if (yearPart.isNotBlank()) {
            // 来源文案里已带年份时不再重复拼年份。
            if (sourcePart.isEmpty() || !sourcePart.contains(yearPart)) {
                add(yearPart)
            }
        }
        if (sourcePart.isNotBlank()) {
            add(sourcePart)
        }
    }.joinToString(" · ").ifBlank { "结果" }
}

// ── 词块网格列数与跨区同列落点 ──

/** 历史 / 热词 / 联想词块统一 3 列。 */
private const val WordTileColumns = 3

/**
 * 构建词块焦点请求器：首项必须使用入口 requester 本体（单挂）。
 */
@Composable
private fun rememberWordTileFocusRequesters(
    itemCount: Int,
    entryFocusRequester: FocusRequester?,
): List<FocusRequester> {
    return remember(itemCount, entryFocusRequester) {
        List(itemCount.coerceAtLeast(0)) { index ->
            if (index == 0 && entryFocusRequester != null) {
                entryFocusRequester
            } else {
                FocusRequester()
            }
        }
    }
}

/**
 * 跨区下移：目标词表首行与 [column] 同列的下标（列超出时落到该行末项）。
 */
private fun resolveWordTileTopRowIndex(
    itemCount: Int,
    columns: Int,
    column: Int,
): Int {
    if (itemCount <= 0) return 0
    val safeColumns = columns.coerceAtLeast(1)
    val col = column.coerceIn(0, safeColumns - 1)
    val firstRowLast = (safeColumns - 1).coerceAtMost(itemCount - 1)
    return col.coerceAtMost(firstRowLast)
}

/**
 * 跨区上移：目标词表底行与 [column] 同列的下标（该列无底行项时落到底行末项）。
 */
private fun resolveWordTileBottomRowIndex(
    itemCount: Int,
    columns: Int,
    column: Int,
): Int {
    if (itemCount <= 0) return 0
    val safeColumns = columns.coerceAtLeast(1)
    val col = column.coerceIn(0, safeColumns - 1)
    val lastRowStart = ((itemCount - 1) / safeColumns) * safeColumns
    val candidate = lastRowStart + col
    return if (candidate < itemCount) {
        candidate
    } else {
        itemCount - 1
    }
}

// ── 左右栏焦点分带：按垂直位置就近互跳 ──

/**
 * 右栏垂直分带，与左侧键盘行大致对齐。
 *
 * - [History]：搜索历史 / 联想结果（上）
 * - [Hot]：搜索热词（中）
 * - [Recommend]：影片推荐（下）
 * - [Generic]：加载/错误/结果等单入口态
 */
private enum class SearchRightFocusBand {
    History,
    Hot,
    Recommend,
    Generic,
}

/**
 * 键盘行 → 优先进入的右栏分带。
 *
 * 6 行键盘：0–1 上（历史）、2–3 中（热词）、4–5 下（推荐）。
 */
private fun keyboardRowToRightBand(row: Int): SearchRightFocusBand {
    return when {
        row <= 1 -> SearchRightFocusBand.History
        row <= 3 -> SearchRightFocusBand.Hot
        else -> SearchRightFocusBand.Recommend
    }
}

/**
 * 从右栏分带回到键盘时的目标行。
 *
 * 若离开前的键行仍在该分带对应行带内，保持原行；否则落到该带首行。
 */
private fun resolveKeyboardRowForRightBand(
    band: SearchRightFocusBand,
    lastKeyboardRow: Int,
): Int {
    val bandRows = when (band) {
        SearchRightFocusBand.History -> 0..1
        SearchRightFocusBand.Hot -> 2..3
        SearchRightFocusBand.Recommend -> 4..(KeyboardRows - 1)
        SearchRightFocusBand.Generic -> 0..(KeyboardRows - 1)
    }
    return if (lastKeyboardRow in bandRows) {
        lastKeyboardRow
    } else {
        bandRows.first
    }
}

/**
 * 按键盘行解析右栏入口 FocusRequester 候选列表（优先分带 → 回落其它可用区）。
 *
 * 结果/联想单入口态始终优先进 [historyEntry]（挂在词块/结果首项上）。
 */
private fun resolveRightPanelEntriesForKeyboardRow(
    row: Int,
    state: TvSearchUiState,
    historyEntry: FocusRequester,
    hotEntry: FocusRequester,
    recommendEntry: FocusRequester,
): List<FocusRequester> {
    // 结果 / 联想：只有一个主入口，所有键行都进 historyEntry。
    if (state.showResultsPanel || state.showSuggestionPanel) {
        return listOf(historyEntry)
    }
    val hasHistory = state.searchHistory.isNotEmpty()
    val hasHot = state.hotQueries.isNotEmpty()
    val hasRecommend = state.recommendCards.isNotEmpty()
    // 启动中/失败：状态面板挂在 historyEntry。
    if (state.isBootstrapping || !state.bootstrapErrorMessage.isNullOrBlank()) {
        return listOf(historyEntry)
    }
    val band = keyboardRowToRightBand(row)
    val ordered = when (band) {
        SearchRightFocusBand.History -> listOf(
            hasHistory to historyEntry,
            hasHot to hotEntry,
            hasRecommend to recommendEntry,
        )
        SearchRightFocusBand.Hot -> listOf(
            hasHot to hotEntry,
            hasHistory to historyEntry,
            hasRecommend to recommendEntry,
        )
        SearchRightFocusBand.Recommend -> listOf(
            hasRecommend to recommendEntry,
            hasHot to hotEntry,
            hasHistory to historyEntry,
        )
        SearchRightFocusBand.Generic -> listOf(
            hasHistory to historyEntry,
            hasHot to hotEntry,
            hasRecommend to recommendEntry,
        )
    }
    return ordered.mapNotNull { (available, requester) ->
        if (available) requester else null
    }
}

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
    /**
     * 仅在提供了对应回调时才消费该方向键。
     * 若回调为 null 仍 return true，会把焦点锁死在只有 onEnter 的控件上
     * （例如历史标题旁的「清空」），方向键全部失效。
     */
    fun handle(action: (() -> Unit)?): Boolean {
        if (action == null) return false
        if (isKeyUp) return true
        action.invoke()
        return true
    }
    when (event.key) {
        Key.Back -> false // 全程放行给 NavHost
        Key.DirectionCenter, Key.Enter, Key.NumPadEnter, Key.Spacebar -> handle(onEnter)
        Key.DirectionUp -> handle(onUp)
        Key.DirectionDown -> handle(onDown)
        Key.DirectionLeft -> handle(onLeft)
        Key.DirectionRight -> handle(onRight)
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
