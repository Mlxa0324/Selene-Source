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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
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
import kotlinx.coroutines.launch
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.layout.TvEmptyStatePanel
import org.moontechlab.selene.tv.core.design.layout.TvPosterGrid
import org.moontechlab.selene.tv.core.design.layout.TvPosterItem
import org.moontechlab.selene.tv.core.design.layout.TvStatePanel
import org.moontechlab.selene.tv.core.design.layout.TvStatePanelKind
import org.moontechlab.selene.tv.core.design.layout.toVideoDetailKey

// ── 布局常量 (对齐 Flutter TV) ──
private val LeftPanelWidth: Dp = 350.dp
private const val KeyboardColumns = 6
private const val KeyboardRows = 6
private val KeyHeight: Dp = 42.dp
private val KeySpacing: Dp = 8.dp
private val RightPanelStartPadding: Dp = 32.dp

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
 * TV 搜索页 —— 双面板布局，对齐 Flutter TV。
 */
@Composable
fun TvSearchRoute(
    state: TvSearchUiState = TvSearchUiState(),
    onAppendChar: (String) -> Unit = {},
    onDeleteLastChar: () -> Unit = {},
    onClearQuery: () -> Unit = {},
    onSearchCurrentQuery: suspend () -> Unit = {},
    onQueryClick: (String) -> Unit = {},
    onSearchHistoryClick: suspend (String) -> Unit = {},
    onVideoClick: (String) -> Unit = {},
    onBack: () -> Unit = {},
) {
    val scope = rememberCoroutineScope()

    // 拦截系统返回键
    BackHandler { onBack() }

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

    // 首焦点
    LaunchedEffect(Unit) {
        keyFocusRequesters[0][0].requestFocus()
    }

    Row(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF1A1D29))
            .padding(horizontal = TvTokens.PageHorizontalPadding, vertical = 28.dp),
    ) {
        // ═══ 左面板 (固定宽度) ═══
        Column(
            modifier = Modifier
                .width(LeftPanelWidth)
                .fillMaxHeight(),
        ) {
            // 标题
            androidx.compose.material3.Text(
                text = "搜索",
                color = Color.White,
                fontSize = 28.sp,
                fontWeight = FontWeight.ExtraBold,
            )
            Spacer(modifier = Modifier.height(4.dp))
            androidx.compose.material3.Text(
                text = "按返回键可退出本页面",
                color = TvTokens.FormTextSecondary,
                fontSize = 12.sp,
            )
            Spacer(modifier = Modifier.height(20.dp))

            // 搜索输入框 (纯展示)
            SearchInputDisplay(query = state.query)
            Spacer(modifier = Modifier.height(16.dp))

            // 虚拟键盘
            TvKeyboard(
                focusRequesters = keyFocusRequesters,
                onKeyPressed = { onAppendChar(it) },
                onArrowRightFromEdge = { row, col ->
                    lastKeyboardRow = row; lastKeyboardCol = col
                    rightPanelEntryFocus.requestFocus()
                },
                onArrowDownFromBottom = { clearButtonFocus.requestFocus() },
                onArrowUpFromTop = { deleteButtonFocus.requestFocus() },
                onBack = onBack,
                onFocusChanged = { row, col ->
                    lastKeyboardRow = row; lastKeyboardCol = col
                },
            )
            Spacer(modifier = Modifier.height(12.dp))

            // 操作按钮
            SearchActionRow(
                clearFocus = clearButtonFocus,
                searchFocus = searchButtonFocus,
                deleteFocus = deleteButtonFocus,
                onClear = onClearQuery,
                onSearch = { scope.launch { onSearchCurrentQuery() } },
                onDelete = onDeleteLastChar,
                onBack = onBack,
                onArrowUpToKeyboard = { col ->
                    keyFocusRequesters[KeyboardRows - 1][col].requestFocus()
                },
                onArrowRightFromDelete = {
                    rightPanelEntryFocus.requestFocus()
                },
            )
        }

        Spacer(modifier = Modifier.width(RightPanelStartPadding))

        // ═══ 右面板 (填充剩余，独立滚动) ═══
        RightPanel(
            state = state,
            entryFocusRequester = rightPanelEntryFocus,
            onReturnToLeftPanel = {
                keyFocusRequesters[lastKeyboardRow][lastKeyboardCol].requestFocus()
            },
            onQueryClick = onQueryClick,
            onSearchHistoryClick = onSearchHistoryClick,
            onVideoClick = onVideoClick,
            onBack = onBack,
            modifier = Modifier.weight(1f).fillMaxHeight(),
        )
    }
}

// ── 搜索输入框 ──

@Composable
private fun SearchInputDisplay(query: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(46.dp)
            .background(Color(0xFF4B4E58), RoundedCornerShape(23.dp)),
        contentAlignment = Alignment.CenterStart,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 20.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            androidx.compose.material3.Text(text = "\uD83D\uDD0D", fontSize = 18.sp)
            Spacer(modifier = Modifier.width(10.dp))
            if (query.isEmpty()) {
                androidx.compose.material3.Text(
                    text = "输入影片名称首字母进行搜索",
                    color = Color(0xFF8E8E93), fontSize = 14.sp,
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                )
            } else {
                androidx.compose.material3.Text(
                    text = query, color = Color.White, fontSize = 16.sp,
                    fontWeight = FontWeight.Bold, maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

// ── 虚拟键盘 ──

/**
 * 键盘按键只消费方向键和确认键的 KeyUp，Back 键全程放行。
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
    Column(verticalArrangement = Arrangement.spacedBy(9.dp)) {
        KeyboardKeys.forEachIndexed { row, keys ->
            Row(horizontalArrangement = Arrangement.spacedBy(KeySpacing)) {
                keys.forEachIndexed { col, keyLabel ->
                    val isRightEdge = col == keys.lastIndex
                    val isTopRow = row == 0
                    val isBottomRow = row == KeyboardRows - 1
                    val interactionSource = remember { MutableInteractionSource() }
                    val isFocused by interactionSource.collectIsFocusedAsState()
                    val bgColor by animateColorAsState(
                        if (isFocused) Color(0xFF737780) else Color.Transparent, tween(140),
                    )
                    val borderColor by animateColorAsState(
                        if (isFocused) Color.White else Color.Transparent, tween(140),
                    )

                    Box(
                        modifier = Modifier
                            .weight(1f, fill = true)
                            .height(KeyHeight)
                            .background(bgColor, RoundedCornerShape(8.dp))
                            .border(
                                if (isFocused) 2.dp else 0.dp, borderColor,
                                RoundedCornerShape(8.dp),
                            )
                            .focusRequester(focusRequesters[row][col])
                            .onFocusChanged { fs ->
                                if (fs.isFocused) onFocusChanged(row, col)
                            }
                            .onPreviewKeyEvent(KeyPreviewHandler(
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
                                    else focusRequesters[row - 1][col.coerceAtMost(KeyboardKeys[row - 1].lastIndex)].requestFocus()
                                },
                                onDown = {
                                    if (isBottomRow) onArrowDownFromBottom()
                                    else focusRequesters[row + 1][col.coerceAtMost(KeyboardKeys[row + 1].lastIndex)].requestFocus()
                                },
                                onBack = onBack,
                            ))
                            .focusable(interactionSource = interactionSource),
                        contentAlignment = Alignment.Center,
                    ) {
                        androidx.compose.material3.Text(
                            text = keyLabel, color = Color.White,
                            fontSize = 22.sp, fontWeight = FontWeight.ExtraBold,
                        )
                    }
                }
            }
        }
    }
}

// ── 操作按钮行 ──

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
    Row(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
        SearchActionButton("清空", clearFocus, onClear, { onArrowUpToKeyboard(0) }, onBack = onBack)
        SearchActionButton("搜索", searchFocus, onSearch, { onArrowUpToKeyboard(2) }, onBack = onBack)
        SearchActionButton(
            "删除", deleteFocus, onDelete, { onArrowUpToKeyboard(5) },
            onRight = onArrowRightFromDelete, onBack = onBack,
        )
    }
}

@Composable
private fun RowScope.SearchActionButton(
    label: String,
    focusRequester: FocusRequester,
    onClick: () -> Unit,
    onUp: () -> Unit,
    onRight: (() -> Unit)? = null,
    onBack: () -> Unit = {},
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val bgColor by animateColorAsState(
        if (isFocused) Color(0xFF757983) else Color(0xFF424550), tween(140),
    )
    val borderColor by animateColorAsState(
        if (isFocused) Color.White else Color.Transparent, tween(140),
    )

    Box(
        modifier = Modifier
            .weight(1f)
            .height(44.dp)
            .background(bgColor, RoundedCornerShape(22.dp))
            .border(if (isFocused) 2.dp else 0.dp, borderColor, RoundedCornerShape(22.dp))
            .focusRequester(focusRequester)
            .onPreviewKeyEvent(KeyPreviewHandler(
                onEnter = onClick,
                onDown = { /* stay */ },
                onUp = onUp,
                onRight = onRight,
                onBack = onBack,
            ))
            .focusable(interactionSource = interactionSource),
        contentAlignment = Alignment.Center,
    ) {
        androidx.compose.material3.Text(
            label, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Bold,
        )
    }
}

// ── 右面板 ──

@Composable
private fun RightPanel(
    state: TvSearchUiState,
    entryFocusRequester: FocusRequester,
    onReturnToLeftPanel: () -> Unit,
    onQueryClick: (String) -> Unit,
    onSearchHistoryClick: suspend (String) -> Unit,
    onVideoClick: (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val hasResults = state.showResults && state.query.isNotBlank() &&
        (state.resultGroups.isNotEmpty() || state.isLoading || state.errorMessage != null)

    Column(
        modifier = modifier.verticalScroll(rememberScrollState()),
    ) {
        when {
            hasResults -> SearchResultPanel(
                state = state,
                entryFocusRequester = entryFocusRequester,
                onReturnToLeftPanel = onReturnToLeftPanel,
                onVideoClick = onVideoClick,
                onBack = onBack,
            )
            state.query.isEmpty() -> SearchDefaultPanel(
                state = state,
                entryFocusRequester = entryFocusRequester,
                onReturnToLeftPanel = onReturnToLeftPanel,
                onQueryClick = onQueryClick,
                onSearchHistoryClick = onSearchHistoryClick,
                onBack = onBack,
            )
            else -> SearchPromptPanel(
                query = state.query,
                entryFocusRequester = entryFocusRequester,
                onReturnToLeftPanel = onReturnToLeftPanel,
                onBack = onBack,
            )
        }
    }
}

// ── 默认面板 (历史+热词) ──

@Composable
private fun SearchDefaultPanel(
    state: TvSearchUiState,
    entryFocusRequester: FocusRequester,
    onReturnToLeftPanel: () -> Unit,
    onQueryClick: (String) -> Unit,
    onSearchHistoryClick: suspend (String) -> Unit,
    onBack: () -> Unit,
) {
    val scope = rememberCoroutineScope()

    SectionTitle("搜索历史", "${state.searchHistory.size} 条记录")
    Spacer(modifier = Modifier.height(14.dp))
    if (state.searchHistory.isEmpty()) {
        TvEmptyStatePanel("暂无搜索历史", "使用左侧键盘输入关键词后点击搜索按钮。")
    } else {
        WordTileGrid(
            words = state.searchHistory,
            entryFocusRequester = entryFocusRequester,
            onReturnToLeftPanel = onReturnToLeftPanel,
            onWordClick = { word -> scope.launch { onSearchHistoryClick(word) } },
            onBack = onBack,
        )
    }

    Spacer(modifier = Modifier.height(32.dp))

    SectionTitle("搜索热词", "${state.hotQueries.size} 个推荐词")
    Spacer(modifier = Modifier.height(14.dp))
    WordTileGrid(
        words = state.hotQueries,
        entryFocusRequester = null,
        onReturnToLeftPanel = onReturnToLeftPanel,
        onWordClick = { word -> onQueryClick(word) },
        onBack = onBack,
    )
}

@Composable
private fun SectionTitle(title: String, hint: String) {
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
        androidx.compose.material3.Text(
            title, color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.ExtraBold,
        )
        Spacer(modifier = Modifier.width(12.dp))
        androidx.compose.material3.Text(
            hint, color = TvTokens.FormTextSecondary, fontSize = 13.sp,
        )
    }
}

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
                        val bgColor = if (isFocused) Color(0xFF7B7E86) else Color(0xFF424550)
                        val isFirst = index == 0

                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(44.dp)
                                .background(bgColor, RoundedCornerShape(8.dp))
                                .then(
                                    if (isFirst && entryFocusRequester != null)
                                        Modifier.focusRequester(entryFocusRequester)
                                    else Modifier.focusRequester(focusRequesters[index])
                                )
                                .onPreviewKeyEvent(KeyPreviewHandler(
                                    onEnter = { onWordClick(word) },
                                    onLeft = {
                                        if (col == 0) onReturnToLeftPanel()
                                        else focusRequesters[index - 1].requestFocus()
                                    },
                                    onRight = {
                                        if (col < columns - 1 && index + 1 < words.size)
                                            focusRequesters[index + 1].requestFocus()
                                    },
                                    onUp = {
                                        if (row == 0) onReturnToLeftPanel()
                                        else focusRequesters[(index - columns).coerceAtLeast(0)].requestFocus()
                                    },
                                    onDown = {
                                        if (row < rows - 1)
                                            focusRequesters[(index + columns).coerceAtMost(words.lastIndex)].requestFocus()
                                    },
                                    onBack = onBack,
                                ))
                                .focusable(interactionSource = interactionSource),
                            contentAlignment = Alignment.Center,
                        ) {
                            androidx.compose.material3.Text(
                                word, color = Color.White, fontSize = 15.sp,
                                fontWeight = FontWeight.Medium, maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.padding(horizontal = 12.dp),
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

// ── 搜索提示和结果面板 ──

@Composable
private fun SearchPromptPanel(
    query: String,
    entryFocusRequester: FocusRequester,
    onReturnToLeftPanel: () -> Unit,
    onBack: () -> Unit,
) {
    SectionTitle("搜索入口", "确认词条可发起搜索")
    Spacer(modifier = Modifier.height(14.dp))
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val borderColor = if (isFocused) Color.White else Color.Transparent
    Box(
        modifier = Modifier
            .fillMaxWidth().height(80.dp)
            .background(Color(0xFF424550), RoundedCornerShape(12.dp))
            .border(if (isFocused) 2.dp else 0.dp, borderColor, RoundedCornerShape(12.dp))
            .focusRequester(entryFocusRequester)
            .onPreviewKeyEvent(KeyPreviewHandler(
                onLeft = onReturnToLeftPanel,
                onBack = onBack,
            ))
            .focusable(interactionSource = interactionSource),
        contentAlignment = Alignment.Center,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            androidx.compose.material3.Text(
                "当前搜索词: ", color = TvTokens.FormTextSecondary, fontSize = 15.sp,
            )
            androidx.compose.material3.Text(
                query, color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.Bold,
            )
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
) {
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
        androidx.compose.material3.Text(
            "搜索结果", color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.ExtraBold,
        )
        Spacer(modifier = Modifier.width(12.dp))
        val total = state.resultGroups.sumOf { it.videos.size }
        androidx.compose.material3.Text(
            "${total} 个影片", color = TvTokens.FormTextSecondary, fontSize = 13.sp,
        )
    }
    Spacer(modifier = Modifier.height(14.dp))

    when {
        state.isLoading -> TvSearchStatePanel(
            kind = TvStatePanelKind.Loading,
            title = "正在搜索 ${state.query}",
            message = "请稍候...",
            focusRequester = entryFocusRequester,
            onReturnToLeftPanel = onReturnToLeftPanel,
            onBack = onBack,
        )
        !state.errorMessage.isNullOrBlank() -> TvSearchStatePanel(
            kind = TvStatePanelKind.Error,
            title = "搜索失败",
            message = state.errorMessage,
            focusRequester = entryFocusRequester,
            onReturnToLeftPanel = onReturnToLeftPanel,
            onBack = onBack,
        )
        state.resultGroups.isEmpty() || state.resultGroups.all { it.videos.isEmpty() } ->
            TvSearchStatePanel(
                kind = TvStatePanelKind.Empty,
                title = "暂无搜索结果",
                message = "尝试使用其他关键词搜索。",
                focusRequester = entryFocusRequester,
                onReturnToLeftPanel = onReturnToLeftPanel,
                onBack = onBack,
            )
        else -> state.resultGroups.forEach { group ->
            if (group.videos.isNotEmpty()) {
                Spacer(modifier = Modifier.height(8.dp))
                TvPosterGrid(
                    items = group.videos.map { video ->
                        TvPosterItem(
                            id = video.id, source = video.source,
                            title = video.title, subtitle = video.searchResultSubtitle(),
                            posterUrl = video.posterUrl, totalEpisodes = video.totalEpisodes,
                        )
                    },
                    columns = 5,
                    firstItemFocusRequester = entryFocusRequester,
                    onItemClick = { item -> onVideoClick(item.toVideoDetailKey()) },
                )
            }
        }
    }
}

/**
 * 搜索右侧状态面板，承接键盘右移入口并支持左键回键盘。
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
            .onPreviewKeyEvent(KeyPreviewHandler(
                onLeft = onReturnToLeftPanel,
                onBack = onBack,
            ))
            .focusable(),
    ) {
        TvStatePanel(kind = kind, title = title, message = message)
    }
}

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
        Key.DirectionCenter, Key.Enter -> {
            if (isKeyUp) true
            else { onEnter?.invoke(); true }
        }
        Key.DirectionUp -> {
            if (isKeyUp) true
            else { onUp?.invoke(); true }
        }
        Key.DirectionDown -> {
            if (isKeyUp) true
            else { onDown?.invoke(); true }
        }
        Key.DirectionLeft -> {
            if (isKeyUp) true
            else { onLeft?.invoke(); true }
        }
        Key.DirectionRight -> {
            if (isKeyUp) true
            else { onRight?.invoke(); true }
        }
        else -> false
    }
}
