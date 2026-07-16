package org.moontechlab.selene.tv.feature.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.layout.TvActionNotice
import org.moontechlab.selene.tv.core.design.layout.TvFormActionButton
import org.moontechlab.selene.tv.core.design.layout.TvFormChipOptionRow
import org.moontechlab.selene.tv.core.design.layout.TvFormPanel
import org.moontechlab.selene.tv.core.design.layout.TvFormSliderRow
import org.moontechlab.selene.tv.core.design.layout.TvFormSwitchRow
import org.moontechlab.selene.tv.core.design.layout.TvFormTextField
import org.moontechlab.selene.tv.core.design.layout.TvFormValueRow
import org.moontechlab.selene.tv.core.design.layout.TvPageScaffold
import org.moontechlab.selene.tv.core.design.layout.TvQrCodeSection

/**
 * 设置页选项。
 *
 * @param T 选项 key 类型。
 * @property key 选项标识。
 * @property label 展示文案。
 * @property color 可选预览色。
 */
private data class FormOption<T>(
    val key: T,
    val label: String,
    val color: Color? = null,
)

// 主题色参考流媒体/大厂主色：奈飞红、青绿、星云紫(Twitch/Discord)、冰蓝、翡翠绿(Spotify)。
private val themeOptions = listOf(
    FormOption("netflix_red", "奈飞红", Color(0xFFE50914)),
    FormOption("teal", "青绿", Color(0xFF14B8A6)),
    FormOption("violet", "星云紫", Color(0xFF8B5CF6)),
    FormOption("ice_blue", "冰蓝", Color(0xFF3B82F6)),
    FormOption("emerald", "翡翠绿", Color(0xFF10B981)),
)

// 背景参考大厂深色底：深蓝灰、炭黑(Spotify/YT)、石板(Tailwind slate)、石墨(Apple)。
private val backgroundOptions = listOf(
    FormOption("deep_blue", "深蓝", Color(0xFF1A1D29)),
    FormOption("charcoal", "炭黑", Color(0xFF121212)),
    FormOption("slate", "石板", Color(0xFF0F172A)),
    FormOption("graphite", "石墨", Color(0xFF1C1C1E)),
)

private val imageSourceOptions = listOf(
    FormOption("official_cdn", "官方精品"),
    FormOption("direct", "直连"),
    FormOption("tencent_cdn", "腾讯CDN"),
    FormOption("alibaba_cdn", "阿里CDN"),
)

/**
 * TV 设置路由。
 *
 * 优先保证遥控器线性上下操作，二维码真实可扫，表单项获焦后自动滚动到舒适位置。
 */
@Composable
fun TvSettingsRoute(
    state: TvSettingsUiState = TvSettingsUiState(),
    contentFocusRequester: FocusRequester? = null,
    onServerUrlChange: (String) -> Unit = {},
    onAccountChange: (String) -> Unit = {},
    onPasswordChange: (String) -> Unit = {},
    onServerConfigSave: () -> Unit = {},
    onThemeSelected: (String) -> Unit = {},
    onBackgroundSelected: (String) -> Unit = {},
    onFocusEffectSelected: (String) -> Unit = {},
    onImageSourceSelected: (String) -> Unit = {},
    onPlayerKernelSelected: (String) -> Unit = {},
    onAdFilterToggle: (Boolean) -> Unit = {},
    onDanmakuApiChange: (String) -> Unit = {},
    onDanmakuEnabledToggle: (Boolean) -> Unit = {},
    onDanmakuOpacityChange: (Float) -> Unit = {},
    onDanmakuFontScaleChange: (Float) -> Unit = {},
    onDanmakuDisplayAreaChange: (Float) -> Unit = {},
    onDanmakuPreventOverlapToggle: (Boolean) -> Unit = {},
    onDanmakuSyncSpeedToggle: (Boolean) -> Unit = {},
    onDanmakuSave: () -> Unit = {},
    onDanmakuMatchClick: () -> Unit = {},
    onCacheClear: () -> Unit = {},
    onRegenerateQr: () -> Unit = {},
    onNoticeDismiss: () -> Unit = {},
) {
    val scrollState = rememberScrollState()
    val scope = rememberCoroutineScope()
    // 锚点使用“滚动内容坐标”，避免嵌套在 TvFormPanel 里的 positionInParent 失真。
    val anchorYMap = remember { mutableMapOf<String, Int>() }
    val anchorHeightMap = remember { mutableMapOf<String, Int>() }
    var scrollContentCoordinates by remember { mutableStateOf<LayoutCoordinates?>(null) }

    val serverUrlFocus = remember { FocusRequester() }
    val accountFocus = remember { FocusRequester() }
    val passwordFocus = remember { FocusRequester() }
    val saveServerFocus = remember { FocusRequester() }
    val regenerateQrFocus = remember { FocusRequester() }
    val themeFocus = remember { FocusRequester() }
    val backgroundFocus = remember { FocusRequester() }
    val imageSourceFocus = remember { FocusRequester() }
    val adFilterFocus = remember { FocusRequester() }
    val danmakuApiFocus = remember { FocusRequester() }
    val danmakuMatchFocus = remember { FocusRequester() }
    val danmakuEnabledFocus = remember { FocusRequester() }
    val danmakuOpacityFocus = remember { FocusRequester() }
    val danmakuFontScaleFocus = remember { FocusRequester() }
    val danmakuDisplayAreaFocus = remember { FocusRequester() }
    val danmakuPreventOverlapFocus = remember { FocusRequester() }
    val danmakuSyncSpeedFocus = remember { FocusRequester() }
    val saveDanmakuFocus = remember { FocusRequester() }
    val clearCacheFocus = remember { FocusRequester() }

    // 首焦点：服务器地址（保留顶部导航下探契约）。
    // 仅在首次进入请求一次，避免外观保存触发重组后再次抢焦到顶部。
    val settingsEntryFocusRequester = contentFocusRequester ?: serverUrlFocus
    LaunchedEffect(Unit) {
        runCatching { settingsEntryFocusRequester.requestFocus() }
        // 进入设置时真正回到内容顶部，避免中部算法把首屏“顶飞”。
        if (scrollState.value > SETTINGS_SCROLL_NEAR_EDGE_PX) {
            scrollState.scrollTo(0)
        }
    }

    /**
     * 获焦后滚动：顶/底锚点真正到 0/max，中部仅保证可见，不再强行居中。
     *
     * @param anchorKey 表单项锚点 key。
     */
    fun scrollAnchorIntoView(anchorKey: String) {
        val y = anchorYMap[anchorKey] ?: return
        val height = anchorHeightMap[anchorKey] ?: SETTINGS_DEFAULT_ANCHOR_HEIGHT_PX
        scope.launch {
            val viewport = scrollState.viewportSize
            if (viewport <= 0) return@launch
            val target = computeSettingsFocusScrollTarget(
                anchorKey = anchorKey,
                anchorTop = y,
                anchorHeight = height,
                viewport = viewport,
                currentScroll = scrollState.value,
                maxScroll = scrollState.maxValue,
            )
            if (kotlin.math.abs(target - scrollState.value) > SETTINGS_SCROLL_NEAR_EDGE_PX) {
                scrollState.animateScrollTo(target)
            }
        }
    }

    /**
     * 请求焦点并把对应锚点滚入可视区（顶底可真正到位）。
     */
    fun focusAndScroll(requester: FocusRequester, anchorKey: String) {
        runCatching { requester.requestFocus() }
        // requestFocus 失败时仍尝试滚动，避免焦点已在目标但列表停在旧位置。
        scrollAnchorIntoView(anchorKey)
    }

    /**
     * 记录表单项在“滚动内容”中的 Y/高度，并在获焦时跟滚。
     *
     * 必须用 root 坐标换算内容偏移：嵌套在面板内的 positionInParent 只能得到局部 Y，
     * 会导致中部表单项永远滚不到、看起来像焦点进不去。
     */
    fun Modifier.trackAnchor(key: String): Modifier {
        return this
            .onGloballyPositioned { coords ->
                val parent = scrollContentCoordinates
                if (parent == null || !parent.isAttached || !coords.isAttached) {
                    return@onGloballyPositioned
                }
                // 内容坐标 = 当前视口内相对位置 + 已滚动偏移。
                val topInViewport = coords.positionInRoot().y - parent.positionInRoot().y
                val contentY = (topInViewport + scrollState.value).toInt()
                anchorYMap[key] = contentY
                anchorHeightMap[key] = coords.size.height.coerceAtLeast(1)
            }
            .onFocusChanged { focusState ->
                // 任意路径获焦（线性链 / 系统焦点搜索）都跟滚，不只靠方向键回调。
                if (focusState.isFocused || focusState.hasFocus) {
                    scrollAnchorIntoView(key)
                }
            }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        TvPageScaffold(
            title = "设置",
            subtitle = "登录后可同步继续观看、播放历史与收藏",
            modifier = Modifier.fillMaxSize(),
        ) {
            Column(
                modifier = Modifier
                    .padding(horizontal = TvTokens.PageHorizontalPadding)
                    .onGloballyPositioned { coords ->
                        // 记录滚动视口坐标，供子项换算内容 Y。
                        scrollContentCoordinates = coords
                    }
                    .verticalScroll(scrollState)
                    // 底部只留很薄呼吸边，末项到底时不留大块空白。
                    .padding(bottom = 28.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                // 登录置顶：从「去登录」进入时首屏即是账号区。
                TvFormPanel(
                    title = "账号登录",
                    subtitle = "填写服务器地址与账号密码，确认后登录并同步数据",
                ) {
                    TvFormTextField(
                        label = "服务器地址",
                        value = state.serverUrl,
                        onValueChange = onServerUrlChange,
                        focusRequester = settingsEntryFocusRequester,
                        onArrowUp = { focusAndScroll(clearCacheFocus, "clearCache") },
                        onArrowDown = { focusAndScroll(accountFocus, "account") },
                        modifier = Modifier.trackAnchor("server"),
                    )
                    TvFormTextField(
                        label = "账号",
                        value = state.account,
                        onValueChange = onAccountChange,
                        focusRequester = accountFocus,
                        onArrowUp = { focusAndScroll(settingsEntryFocusRequester, "server") },
                        onArrowDown = { focusAndScroll(passwordFocus, "password") },
                        modifier = Modifier.trackAnchor("account"),
                    )
                    TvFormTextField(
                        label = "密码",
                        value = state.password,
                        onValueChange = onPasswordChange,
                        focusRequester = passwordFocus,
                        onArrowUp = { focusAndScroll(accountFocus, "account") },
                        onArrowDown = { focusAndScroll(saveServerFocus, "saveServer") },
                        // 默认星花掩码，右侧眼睛可切换明文。
                        isPassword = true,
                        modifier = Modifier.trackAnchor("password"),
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    TvFormActionButton(
                        label = if (state.savingServerConfig) "登录中..." else "登录",
                        onClick = onServerConfigSave,
                        focusRequester = saveServerFocus,
                        filled = true,
                        onArrowUp = { focusAndScroll(passwordFocus, "password") },
                        onArrowDown = { focusAndScroll(regenerateQrFocus, "qr") },
                        modifier = Modifier.trackAnchor("saveServer"),
                    )
                }

                TvQrCodeSection(
                    qrData = state.qrData,
                    statusText = state.qrStatusText,
                    shareAddress = state.qrShareAddress,
                    regenerating = state.regeneratingQr,
                    onRegenerateClick = onRegenerateQr,
                    regenerateFocusRequester = regenerateQrFocus,
                    onRegenerateArrowUp = { focusAndScroll(saveServerFocus, "saveServer") },
                    onRegenerateArrowDown = { focusAndScroll(themeFocus, "theme") },
                    // 焦点锚在“重新生成二维码”按钮，对应截图右侧操作区。
                    regenerateModifier = Modifier.trackAnchor("qr"),
                    modifier = Modifier,
                )

                // 焦点效果未接入全局样式；播放器默认固定 Exo，设置页暂不暴露。
                TvFormPanel(
                    title = "外观与体验",
                    subtitle = "主题色与背景即时生效，图片代理影响海报加载线路",
                ) {
                    TvFormChipOptionRow(
                        label = "主题色",
                        options = themeOptions,
                        selectedKey = themeOptions.firstOrNull { it.key == state.themeKey } ?: themeOptions.first(),
                        optionLabel = { it.label },
                        onOptionSelected = { onThemeSelected(it.key) },
                        entryFocusRequester = themeFocus,
                        onArrowUp = { focusAndScroll(regenerateQrFocus, "qr") },
                        onArrowDown = { focusAndScroll(backgroundFocus, "background") },
                        chipPreview = { option, _ ->
                            option.color?.let { color ->
                                Box(Modifier.size(12.dp).clip(CircleShape).background(color))
                            }
                        },
                        modifier = Modifier.trackAnchor("theme"),
                    )
                    TvFormChipOptionRow(
                        label = "背景",
                        options = backgroundOptions,
                        selectedKey = backgroundOptions.firstOrNull { it.key == state.backgroundKey }
                            ?: backgroundOptions.first(),
                        optionLabel = { it.label },
                        onOptionSelected = { onBackgroundSelected(it.key) },
                        entryFocusRequester = backgroundFocus,
                        onArrowUp = { focusAndScroll(themeFocus, "theme") },
                        onArrowDown = { focusAndScroll(imageSourceFocus, "imageSource") },
                        chipPreview = { option, _ ->
                            option.color?.let { color ->
                                Box(Modifier.size(12.dp).clip(CircleShape).background(color))
                            }
                        },
                        modifier = Modifier.trackAnchor("background"),
                    )
                    TvFormChipOptionRow(
                        label = "图片代理",
                        options = imageSourceOptions,
                        selectedKey = imageSourceOptions.firstOrNull {
                            it.key == normalizeImageSourceKey(state.imageSourceKey)
                        } ?: imageSourceOptions[1],
                        optionLabel = { it.label },
                        onOptionSelected = { onImageSourceSelected(it.key) },
                        entryFocusRequester = imageSourceFocus,
                        onArrowUp = { focusAndScroll(backgroundFocus, "background") },
                        onArrowDown = { focusAndScroll(adFilterFocus, "adFilter") },
                        modifier = Modifier.trackAnchor("imageSource"),
                    )
                    TvFormSwitchRow(
                        label = "自动去广告",
                        checked = state.adFilterEnabled,
                        onCheckedChange = onAdFilterToggle,
                        focusRequester = adFilterFocus,
                        onArrowUp = { focusAndScroll(imageSourceFocus, "imageSource") },
                        onArrowDown = { focusAndScroll(danmakuApiFocus, "danmakuApi") },
                        modifier = Modifier.trackAnchor("adFilter"),
                    )
                }

                TvFormPanel(
                    title = "弹幕",
                    subtitle = "调整弹幕服务与显示参数；改完后点「保存弹幕设置」",
                ) {
                    TvFormTextField(
                        label = "弹幕 API",
                        value = state.danmakuApi,
                        onValueChange = onDanmakuApiChange,
                        focusRequester = danmakuApiFocus,
                        onArrowUp = { focusAndScroll(adFilterFocus, "adFilter") },
                        onArrowDown = { focusAndScroll(danmakuMatchFocus, "danmakuMatch") },
                        modifier = Modifier.trackAnchor("danmakuApi"),
                    )
                    TvFormActionButton(
                        label = "手动匹配弹幕",
                        onClick = onDanmakuMatchClick,
                        focusRequester = danmakuMatchFocus,
                        onArrowUp = { focusAndScroll(danmakuApiFocus, "danmakuApi") },
                        onArrowDown = { focusAndScroll(danmakuEnabledFocus, "danmakuEnabled") },
                        modifier = Modifier.trackAnchor("danmakuMatch"),
                    )
                    TvFormSwitchRow(
                        label = "弹幕显示",
                        checked = state.danmakuEnabled,
                        onCheckedChange = onDanmakuEnabledToggle,
                        focusRequester = danmakuEnabledFocus,
                        onArrowUp = { focusAndScroll(danmakuMatchFocus, "danmakuMatch") },
                        onArrowDown = { focusAndScroll(danmakuOpacityFocus, "danmakuOpacity") },
                        modifier = Modifier.trackAnchor("danmakuEnabled"),
                    )
                    TvFormSliderRow(
                        label = "不透明度",
                        value = state.danmakuOpacity,
                        onValueChange = onDanmakuOpacityChange,
                        focusRequester = danmakuOpacityFocus,
                        onArrowUp = { focusAndScroll(danmakuEnabledFocus, "danmakuEnabled") },
                        onArrowDown = { focusAndScroll(danmakuFontScaleFocus, "danmakuFontScale") },
                        modifier = Modifier.trackAnchor("danmakuOpacity"),
                    )
                    TvFormSliderRow(
                        label = "字体缩放",
                        value = ((state.danmakuFontScale - 0.5f) / 1.5f).coerceIn(0f, 1f),
                        onValueChange = { ratio -> onDanmakuFontScaleChange(0.5f + ratio * 1.5f) },
                        valueDisplay = { "${"%.1f".format(0.5f + it * 1.5f)}x" },
                        focusRequester = danmakuFontScaleFocus,
                        onArrowUp = { focusAndScroll(danmakuOpacityFocus, "danmakuOpacity") },
                        onArrowDown = { focusAndScroll(danmakuDisplayAreaFocus, "danmakuDisplayArea") },
                        modifier = Modifier.trackAnchor("danmakuFontScale"),
                    )
                    TvFormSliderRow(
                        label = "显示区域",
                        value = ((state.danmakuDisplayArea - 0.25f) / 0.75f).coerceIn(0f, 1f),
                        onValueChange = { ratio -> onDanmakuDisplayAreaChange(0.25f + ratio * 0.75f) },
                        valueDisplay = { "${"%.0f".format((0.25f + it * 0.75f) * 100)}%" },
                        focusRequester = danmakuDisplayAreaFocus,
                        onArrowUp = { focusAndScroll(danmakuFontScaleFocus, "danmakuFontScale") },
                        onArrowDown = { focusAndScroll(danmakuPreventOverlapFocus, "danmakuPreventOverlap") },
                        modifier = Modifier.trackAnchor("danmakuDisplayArea"),
                    )
                    TvFormSwitchRow(
                        label = "防止重叠",
                        checked = state.danmakuPreventOverlap,
                        onCheckedChange = onDanmakuPreventOverlapToggle,
                        focusRequester = danmakuPreventOverlapFocus,
                        onArrowUp = { focusAndScroll(danmakuDisplayAreaFocus, "danmakuDisplayArea") },
                        onArrowDown = { focusAndScroll(danmakuSyncSpeedFocus, "danmakuSyncSpeed") },
                        modifier = Modifier.trackAnchor("danmakuPreventOverlap"),
                    )
                    TvFormSwitchRow(
                        label = "速度同步",
                        checked = state.danmakuSyncVideoSpeed,
                        onCheckedChange = onDanmakuSyncSpeedToggle,
                        focusRequester = danmakuSyncSpeedFocus,
                        onArrowUp = { focusAndScroll(danmakuPreventOverlapFocus, "danmakuPreventOverlap") },
                        onArrowDown = { focusAndScroll(saveDanmakuFocus, "saveDanmaku") },
                        modifier = Modifier.trackAnchor("danmakuSyncSpeed"),
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    TvFormActionButton(
                        label = if (state.savingDanmaku) "保存中..." else "保存弹幕设置",
                        onClick = onDanmakuSave,
                        focusRequester = saveDanmakuFocus,
                        filled = true,
                        onArrowUp = { focusAndScroll(danmakuSyncSpeedFocus, "danmakuSyncSpeed") },
                        onArrowDown = { focusAndScroll(clearCacheFocus, "clearCache") },
                        modifier = Modifier.trackAnchor("saveDanmaku"),
                    )
                }

                TvFormPanel(
                    title = "缓存",
                    subtitle = "清理本地海报与临时缓存，不影响登录与播放记录",
                ) {
                    TvFormValueRow(
                        label = "当前缓存",
                        value = state.cacheSizeText,
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    TvFormActionButton(
                        label = if (state.clearingCache) "清理中..." else "清除缓存",
                        onClick = onCacheClear,
                        focusRequester = clearCacheFocus,
                        onArrowUp = { focusAndScroll(saveDanmakuFocus, "saveDanmaku") },
                        onArrowDown = { focusAndScroll(settingsEntryFocusRequester, "server") },
                        modifier = Modifier.trackAnchor("clearCache"),
                    )
                }

                Spacer(modifier = Modifier.height(8.dp))
            }
        }

        // 公共轻提示：登录结果 / 外观保存等，底部居中窄胶囊，不抢主题色。
        TvActionNotice(
            text = state.noticeText,
            visible = state.noticeVisible,
            onDismiss = onNoticeDismiss,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 36.dp),
        )
    }
}

/**
 * 规整图片代理 key，兼容历史中文值。
 *
 * @param raw 原始 key。
 * @return 规范化 key。
 */
private fun normalizeImageSourceKey(raw: String): String {
    return when (raw) {
        "直连" -> "direct"
        "豆瓣官方精品 CDN", "官方精品" -> "official_cdn"
        "豆瓣 CDN By CMLiussss（腾讯云）" -> "tencent_cdn"
        "豆瓣 CDN By CMLiussss（阿里云）" -> "alibaba_cdn"
        else -> raw
    }
}

/** 距顶/底小于该像素视为已到位，避免残差抖动。 */
internal const val SETTINGS_SCROLL_NEAR_EDGE_PX = 8

/** 锚点高度未知时的默认行高（px 近似）。 */
internal const val SETTINGS_DEFAULT_ANCHOR_HEIGHT_PX = 52

/** 中部 ensure-visible 的上下安全边（px）。 */
internal const val SETTINGS_VISIBLE_EDGE_PAD_PX = 24

/**
 * 登录卡片内全部锚点：获焦时固定 scroll=0。
 *
 * 在「登录」按钮上时也要完整露出滚动内容顶部（账号登录整卡 + 标题区），
 * 不能因为按钮靠下就把首屏顶走。
 */
internal val SETTINGS_TOP_EDGE_ANCHOR_KEYS = setOf(
    "server",
    "account",
    "password",
    "saveServer",
)

/** 底区锚点：获焦时真正滚到 scroll=max。 */
internal val SETTINGS_BOTTOM_EDGE_ANCHOR_KEYS = setOf("saveDanmaku", "clearCache")

/**
 * 计算设置页焦点滚动目标。
 *
 * - 登录区（含登录按钮）：固定 0，保证滚动内容顶部完整可见
 * - 底区：固定 max，保证缓存区真正到底
 * - 中部：仅在项被裁切时 bring-into-view，不强制居中
 *
 * @param anchorKey 锚点 key。
 * @param anchorTop 锚点在内容坐标系中的顶边。
 * @param anchorHeight 锚点高度。
 * @param viewport 视口高度。
 * @param currentScroll 当前滚动。
 * @param maxScroll 最大滚动。
 * @return 目标 scroll 值。
 */
internal fun computeSettingsFocusScrollTarget(
    anchorKey: String,
    anchorTop: Int,
    anchorHeight: Int,
    viewport: Int,
    currentScroll: Int,
    maxScroll: Int,
): Int {
    if (viewport <= 0) {
        return currentScroll.coerceIn(0, maxScroll.coerceAtLeast(0))
    }
    val max = maxScroll.coerceAtLeast(0)
    val height = anchorHeight.coerceAtLeast(1)
    return when {
        anchorKey in SETTINGS_TOP_EDGE_ANCHOR_KEYS -> 0
        anchorKey in SETTINGS_BOTTOM_EDGE_ANCHOR_KEYS -> max
        else -> {
            val itemTopInViewport = anchorTop - currentScroll
            val itemBottomInViewport = anchorTop + height - currentScroll
            val topPad = SETTINGS_VISIBLE_EDGE_PAD_PX
            val bottomPad = SETTINGS_VISIBLE_EDGE_PAD_PX
            when {
                itemTopInViewport < topPad -> {
                    (anchorTop - topPad).coerceIn(0, max)
                }
                itemBottomInViewport > viewport - bottomPad -> {
                    (anchorTop + height - viewport + bottomPad).coerceIn(0, max)
                }
                else -> currentScroll.coerceIn(0, max)
            }
        }
    }
}
