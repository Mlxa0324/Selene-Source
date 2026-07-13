package org.moontechlab.selene.tv.feature.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
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
import androidx.compose.ui.geometry.Offset
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

private val themeOptions = listOf(
    FormOption("netflix_red", "奈飞红", Color(0xFFE50914)),
    FormOption("teal", "青绿", Color(0xFF14B8A6)),
    FormOption("amber", "暖橙", Color(0xFFD97706)),
    FormOption("ice_blue", "冰蓝", Color(0xFF38BDF8)),
    FormOption("dark_gray", "墨灰", Color(0xFF6B7280)),
)

private val backgroundOptions = listOf(
    FormOption("deep_blue", "深蓝", Color(0xFF1A1D29)),
    FormOption("pure_black", "纯黑", Color(0xFF000000)),
    FormOption("dark_purple", "暗紫", Color(0xFF2D1B4E)),
    FormOption("deep_green", "深绿", Color(0xFF064E3B)),
)

private val focusEffectOptions = listOf(
    FormOption("magnifier", "放大镜"),
    FormOption("scale_border", "缩放边框"),
    FormOption("underline", "下划线"),
)

private val imageSourceOptions = listOf(
    FormOption("official_cdn", "官方精品"),
    FormOption("direct", "直连"),
    FormOption("tencent_cdn", "腾讯CDN"),
    FormOption("alibaba_cdn", "阿里CDN"),
)

private val playerKernelOptions = listOf(
    FormOption("exo", "ExoPlayer"),
    FormOption("webview", "WebView"),
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
    var scrollContentCoordinates by remember { mutableStateOf<LayoutCoordinates?>(null) }

    val regenerateQrFocus = remember { FocusRequester() }
    val serverUrlFocus = remember { FocusRequester() }
    val accountFocus = remember { FocusRequester() }
    val passwordFocus = remember { FocusRequester() }
    val saveServerFocus = remember { FocusRequester() }
    val themeFocus = remember { FocusRequester() }
    val backgroundFocus = remember { FocusRequester() }
    val focusEffectFocus = remember { FocusRequester() }
    val imageSourceFocus = remember { FocusRequester() }
    val playerKernelFocus = remember { FocusRequester() }
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
    val settingsEntryFocusRequester = contentFocusRequester ?: serverUrlFocus
    LaunchedEffect(settingsEntryFocusRequester) {
        runCatching { settingsEntryFocusRequester.requestFocus() }
    }

    /**
     * 仅滚动：把锚点滚到视口中线舒适带。
     *
     * @param anchorKey 表单项锚点 key。
     */
    fun scrollAnchorToCenter(anchorKey: String) {
        val y = anchorYMap[anchorKey] ?: return
        scope.launch {
            val viewport = scrollState.viewportSize
            if (viewport <= 0) return@launch
            // 0.5 = 视口中线；表单项视觉中心略上移一点，落在截图红框舒适区。
            val target = (y - viewport * 0.5f + 40f).toInt()
                .coerceIn(0, scrollState.maxValue)
            if (kotlin.math.abs(target - scrollState.value) > 8) {
                scrollState.animateScrollTo(target)
            }
        }
    }

    /**
     * 请求焦点并把对应锚点滚到视口正中舒适带。
     *
     * 目标：获焦项稳定停在屏幕中部，上下移动时随焦点滚动，而不是顶/底才动。
     */
    fun focusAndScroll(requester: FocusRequester, anchorKey: String) {
        runCatching { requester.requestFocus() }
        // requestFocus 失败时仍尝试滚动，避免焦点已在目标但列表停在旧位置。
        scrollAnchorToCenter(anchorKey)
    }

    /**
     * 记录表单项在“滚动内容”中的 Y，并在获焦时自动滚到中部。
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
            }
            .onFocusChanged { focusState ->
                // 任意路径获焦（线性链 / 系统焦点搜索）都跟滚，不只靠方向键回调。
                if (focusState.isFocused || focusState.hasFocus) {
                    scrollAnchorToCenter(key)
                }
            }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        TvPageScaffold(
            title = "设置",
            subtitle = "遥控器上下移动，左右调节，确认保存",
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
                    // 底部留白加长，最后几项也能滚到中部舒适区。
                    .padding(bottom = 320.dp),
                verticalArrangement = Arrangement.spacedBy(TvTokens.SectionSpacing),
            ) {
                TvQrCodeSection(
                    qrData = state.qrData,
                    statusText = state.qrStatusText,
                    shareAddress = state.qrShareAddress,
                    regenerating = state.regeneratingQr,
                    onRegenerateClick = onRegenerateQr,
                    regenerateFocusRequester = regenerateQrFocus,
                    onRegenerateArrowDown = { focusAndScroll(settingsEntryFocusRequester, "server") },
                    onRegenerateArrowUp = { focusAndScroll(clearCacheFocus, "clearCache") },
                    // 焦点锚在“重新生成二维码”按钮，对应截图右侧红框操作区。
                    regenerateModifier = Modifier.trackAnchor("qr"),
                    modifier = Modifier,
                )

                TvFormPanel(title = "服务器配置") {
                    TvFormTextField(
                        label = "服务器地址",
                        value = state.serverUrl,
                        onValueChange = onServerUrlChange,
                        focusRequester = settingsEntryFocusRequester,
                        onArrowUp = { focusAndScroll(regenerateQrFocus, "qr") },
                        onArrowDown = { focusAndScroll(accountFocus, "account") },
                        modifier = Modifier.trackAnchor("server"),
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    TvFormTextField(
                        label = "账号",
                        value = state.account,
                        onValueChange = onAccountChange,
                        focusRequester = accountFocus,
                        onArrowUp = { focusAndScroll(settingsEntryFocusRequester, "server") },
                        onArrowDown = { focusAndScroll(passwordFocus, "password") },
                        modifier = Modifier.trackAnchor("account"),
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    TvFormTextField(
                        label = "密码",
                        value = state.password,
                        onValueChange = onPasswordChange,
                        focusRequester = passwordFocus,
                        onArrowUp = { focusAndScroll(accountFocus, "account") },
                        onArrowDown = { focusAndScroll(saveServerFocus, "saveServer") },
                        modifier = Modifier.trackAnchor("password"),
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    TvFormActionButton(
                        label = if (state.savingServerConfig) "保存中..." else "保存配置",
                        onClick = onServerConfigSave,
                        focusRequester = saveServerFocus,
                        onArrowUp = { focusAndScroll(passwordFocus, "password") },
                        onArrowDown = { focusAndScroll(themeFocus, "theme") },
                        modifier = Modifier.trackAnchor("saveServer"),
                    )
                }

                TvFormPanel(title = "外观与焦点") {
                    TvFormChipOptionRow(
                        label = "主题色",
                        options = themeOptions,
                        selectedKey = themeOptions.firstOrNull { it.key == state.themeKey } ?: themeOptions.first(),
                        optionLabel = { it.label },
                        onOptionSelected = { onThemeSelected(it.key) },
                        entryFocusRequester = themeFocus,
                        onArrowUp = { focusAndScroll(saveServerFocus, "saveServer") },
                        onArrowDown = { focusAndScroll(backgroundFocus, "background") },
                        chipPreview = { option, _ ->
                            option.color?.let { color ->
                                Box(Modifier.size(12.dp).clip(CircleShape).background(color))
                            }
                        },
                        modifier = Modifier.trackAnchor("theme"),
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    TvFormChipOptionRow(
                        label = "背景",
                        options = backgroundOptions,
                        selectedKey = backgroundOptions.firstOrNull { it.key == state.backgroundKey }
                            ?: backgroundOptions.first(),
                        optionLabel = { it.label },
                        onOptionSelected = { onBackgroundSelected(it.key) },
                        entryFocusRequester = backgroundFocus,
                        onArrowUp = { focusAndScroll(themeFocus, "theme") },
                        onArrowDown = { focusAndScroll(focusEffectFocus, "focusEffect") },
                        chipPreview = { option, _ ->
                            option.color?.let { color ->
                                Box(Modifier.size(12.dp).clip(CircleShape).background(color))
                            }
                        },
                        modifier = Modifier.trackAnchor("background"),
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    TvFormChipOptionRow(
                        label = "焦点效果",
                        options = focusEffectOptions,
                        selectedKey = focusEffectOptions.firstOrNull { it.key == state.focusEffectKey }
                            ?: focusEffectOptions.first(),
                        optionLabel = { it.label },
                        onOptionSelected = { onFocusEffectSelected(it.key) },
                        entryFocusRequester = focusEffectFocus,
                        onArrowUp = { focusAndScroll(backgroundFocus, "background") },
                        onArrowDown = { focusAndScroll(imageSourceFocus, "imageSource") },
                        modifier = Modifier.trackAnchor("focusEffect"),
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    TvFormChipOptionRow(
                        label = "图片代理",
                        options = imageSourceOptions,
                        selectedKey = imageSourceOptions.firstOrNull {
                            it.key == normalizeImageSourceKey(state.imageSourceKey)
                        } ?: imageSourceOptions[1],
                        optionLabel = { it.label },
                        onOptionSelected = { onImageSourceSelected(it.key) },
                        entryFocusRequester = imageSourceFocus,
                        onArrowUp = { focusAndScroll(focusEffectFocus, "focusEffect") },
                        onArrowDown = { focusAndScroll(playerKernelFocus, "playerKernel") },
                        modifier = Modifier.trackAnchor("imageSource"),
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    TvFormChipOptionRow(
                        label = "播放器内核",
                        options = playerKernelOptions,
                        selectedKey = playerKernelOptions.firstOrNull { it.key == state.playerKernelKey }
                            ?: playerKernelOptions.first(),
                        optionLabel = { it.label },
                        onOptionSelected = { onPlayerKernelSelected(it.key) },
                        entryFocusRequester = playerKernelFocus,
                        onArrowUp = { focusAndScroll(imageSourceFocus, "imageSource") },
                        onArrowDown = { focusAndScroll(adFilterFocus, "adFilter") },
                        modifier = Modifier.trackAnchor("playerKernel"),
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    TvFormSwitchRow(
                        label = "自动去广告",
                        checked = state.adFilterEnabled,
                        onCheckedChange = onAdFilterToggle,
                        focusRequester = adFilterFocus,
                        onArrowUp = { focusAndScroll(playerKernelFocus, "playerKernel") },
                        onArrowDown = { focusAndScroll(danmakuApiFocus, "danmakuApi") },
                        modifier = Modifier.trackAnchor("adFilter"),
                    )
                }

                TvFormPanel(title = "弹幕设置") {
                    TvFormTextField(
                        label = "弹幕 API",
                        value = state.danmakuApi,
                        onValueChange = onDanmakuApiChange,
                        focusRequester = danmakuApiFocus,
                        onArrowUp = { focusAndScroll(adFilterFocus, "adFilter") },
                        onArrowDown = { focusAndScroll(danmakuMatchFocus, "danmakuMatch") },
                        modifier = Modifier.trackAnchor("danmakuApi"),
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    TvFormActionButton(
                        label = "手动匹配弹幕",
                        onClick = onDanmakuMatchClick,
                        focusRequester = danmakuMatchFocus,
                        onArrowUp = { focusAndScroll(danmakuApiFocus, "danmakuApi") },
                        onArrowDown = { focusAndScroll(danmakuEnabledFocus, "danmakuEnabled") },
                        modifier = Modifier.trackAnchor("danmakuMatch"),
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    TvFormSwitchRow(
                        label = "弹幕显示",
                        checked = state.danmakuEnabled,
                        onCheckedChange = onDanmakuEnabledToggle,
                        focusRequester = danmakuEnabledFocus,
                        onArrowUp = { focusAndScroll(danmakuMatchFocus, "danmakuMatch") },
                        onArrowDown = { focusAndScroll(danmakuOpacityFocus, "danmakuOpacity") },
                        modifier = Modifier.trackAnchor("danmakuEnabled"),
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    TvFormSliderRow(
                        label = "不透明度",
                        value = state.danmakuOpacity,
                        onValueChange = onDanmakuOpacityChange,
                        focusRequester = danmakuOpacityFocus,
                        onArrowUp = { focusAndScroll(danmakuEnabledFocus, "danmakuEnabled") },
                        onArrowDown = { focusAndScroll(danmakuFontScaleFocus, "danmakuFontScale") },
                        modifier = Modifier.trackAnchor("danmakuOpacity"),
                    )
                    Spacer(modifier = Modifier.height(12.dp))
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
                    Spacer(modifier = Modifier.height(12.dp))
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
                    Spacer(modifier = Modifier.height(12.dp))
                    TvFormSwitchRow(
                        label = "防止重叠",
                        checked = state.danmakuPreventOverlap,
                        onCheckedChange = onDanmakuPreventOverlapToggle,
                        focusRequester = danmakuPreventOverlapFocus,
                        onArrowUp = { focusAndScroll(danmakuDisplayAreaFocus, "danmakuDisplayArea") },
                        onArrowDown = { focusAndScroll(danmakuSyncSpeedFocus, "danmakuSyncSpeed") },
                        modifier = Modifier.trackAnchor("danmakuPreventOverlap"),
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    TvFormSwitchRow(
                        label = "速度同步",
                        checked = state.danmakuSyncVideoSpeed,
                        onCheckedChange = onDanmakuSyncSpeedToggle,
                        focusRequester = danmakuSyncSpeedFocus,
                        onArrowUp = { focusAndScroll(danmakuPreventOverlapFocus, "danmakuPreventOverlap") },
                        onArrowDown = { focusAndScroll(saveDanmakuFocus, "saveDanmaku") },
                        modifier = Modifier.trackAnchor("danmakuSyncSpeed"),
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    TvFormActionButton(
                        label = if (state.savingDanmaku) "保存中..." else "保存弹幕设置",
                        onClick = onDanmakuSave,
                        focusRequester = saveDanmakuFocus,
                        onArrowUp = { focusAndScroll(danmakuSyncSpeedFocus, "danmakuSyncSpeed") },
                        onArrowDown = { focusAndScroll(clearCacheFocus, "clearCache") },
                        modifier = Modifier.trackAnchor("saveDanmaku"),
                    )
                }

                TvFormPanel(title = "缓存管理") {
                    TvFormValueRow(
                        label = "当前缓存",
                        value = state.cacheSizeText,
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    TvFormActionButton(
                        label = if (state.clearingCache) "清理中..." else "清除缓存",
                        onClick = onCacheClear,
                        focusRequester = clearCacheFocus,
                        onArrowUp = { focusAndScroll(saveDanmakuFocus, "saveDanmaku") },
                        onArrowDown = { focusAndScroll(regenerateQrFocus, "qr") },
                        modifier = Modifier.trackAnchor("clearCache"),
                    )
                }

                Spacer(modifier = Modifier.height(24.dp))
            }
        }

        TvActionNotice(
            text = state.noticeText,
            visible = state.noticeVisible,
            onDismiss = onNoticeDismiss,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(horizontal = TvTokens.PageHorizontalPadding, vertical = 28.dp),
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
