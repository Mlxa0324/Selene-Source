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
import androidx.compose.foundation.ScrollState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
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

// ── 选项数据模型 ──

private data class FormOption<T>(val key: T, val label: String, val color: Color? = null)

// ── 选项常量 ──

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
    FormOption("direct", "直连"),
    FormOption("tencent_cdn", "腾讯CDN"),
    FormOption("alibaba_cdn", "阿里CDN"),
)

private val playerKernelOptions = listOf(
    FormOption("exo", "ExoPlayer"),
    FormOption("webview", "WebView"),
)

/**
 * TV 设置路由 —— 对齐 Flutter TV 表单式布局。
 *
 * 焦点链 (从上到下单向)：
 * 服务器地址 → 账号 → 密码 → 保存配置
 *   → 主题色 Chip 行 → 背景 Chip 行 → 焦点效果 Chip 行 → 图片代理 Chip 行 → 播放器内核 Chip 行
 *   → 自动去广告
 *   → 弹幕 API → 手动匹配 → 弹幕显示 → 不透明度 → 字体缩放 → 显示区域 → 防止重叠 → 速度同步 → 保存弹幕
 *   → 清除缓存 → 回到服务器地址
 */
@Composable
fun TvSettingsRoute(
    state: TvSettingsUiState = TvSettingsUiState(),
    contentFocusRequester: FocusRequester? = null,
    // 服务器
    onServerUrlChange: (String) -> Unit = {},
    onAccountChange: (String) -> Unit = {},
    onPasswordChange: (String) -> Unit = {},
    onServerConfigSave: () -> Unit = {},
    // 外观
    onThemeSelected: (String) -> Unit = {},
    onBackgroundSelected: (String) -> Unit = {},
    onFocusEffectSelected: (String) -> Unit = {},
    onImageSourceSelected: (String) -> Unit = {},
    // 播放
    onPlayerKernelSelected: (String) -> Unit = {},
    onAdFilterToggle: (Boolean) -> Unit = {},
    // 弹幕
    onDanmakuApiChange: (String) -> Unit = {},
    onDanmakuEnabledToggle: (Boolean) -> Unit = {},
    onDanmakuOpacityChange: (Float) -> Unit = {},
    onDanmakuFontScaleChange: (Float) -> Unit = {},
    onDanmakuDisplayAreaChange: (Float) -> Unit = {},
    onDanmakuPreventOverlapToggle: (Boolean) -> Unit = {},
    onDanmakuSyncSpeedToggle: (Boolean) -> Unit = {},
    onDanmakuSave: () -> Unit = {},
    onDanmakuMatchClick: () -> Unit = {},
    // 缓存
    onCacheClear: () -> Unit = {},
    // 通知
    onNoticeDismiss: () -> Unit = {},
) {
    // ── 首焦点：服务器地址 ──
    val serverUrlFocus = remember { FocusRequester() }
    val settingsEntryFocusRequester = contentFocusRequester ?: serverUrlFocus
    LaunchedEffect(settingsEntryFocusRequester) {
        settingsEntryFocusRequester.requestFocus()
    }

    TvPageScaffold(
        title = "设置",
        modifier = Modifier.fillMaxSize(),
    ) {
        Column(
            modifier = Modifier
                .padding(horizontal = TvTokens.PageHorizontalPadding)
                .verticalScroll(rememberSaveable(saver = ScrollState.Saver) { ScrollState(0) }),
            verticalArrangement = Arrangement.spacedBy(TvTokens.SectionSpacing),
        ) {
            // ═══ 0. 二维码 (顶部，不受焦点) ═══
            TvQrCodeSection(
                qrData = state.qrData,
                statusText = state.qrStatusText,
                onRegenerateClick = {},
            )

            Spacer(modifier = Modifier.height(TvTokens.SectionSpacing))

            // ═══ 1. 服务器配置 ═══
            TvFormPanel(title = "服务器配置") {
                TvFormTextField(
                    label = "服务器地址",
                    value = state.serverUrl,
                    onValueChange = onServerUrlChange,
                    focusRequester = settingsEntryFocusRequester,
                )
                Spacer(modifier = Modifier.height(12.dp))
                TvFormTextField(
                    label = "账号",
                    value = state.account,
                    onValueChange = onAccountChange,
                )
                Spacer(modifier = Modifier.height(12.dp))
                TvFormTextField(
                    label = "密码",
                    value = state.password,
                    onValueChange = onPasswordChange,
                )
                Spacer(modifier = Modifier.height(16.dp))
                TvFormActionButton(
                    label = if (state.savingServerConfig) "保存中..." else "保存配置",
                    onClick = onServerConfigSave,
                )
            }

            // ═══ 2. 外观与焦点 ═══
            TvFormPanel(title = "外观与焦点") {
                TvFormChipOptionRow(
                    label = "主题色",
                    options = themeOptions,
                    selectedKey = themeOptions.firstOrNull { it.key == state.themeKey } ?: themeOptions.first(),
                    optionLabel = { it.label },
                    onOptionSelected = { onThemeSelected(it.key) },
                    chipPreview = { option, _ ->
                        option.color?.let { color ->
                            Box(Modifier.size(12.dp).clip(CircleShape).background(color))
                        }
                    },
                )
                Spacer(modifier = Modifier.height(4.dp))
                TvFormChipOptionRow(
                    label = "背景",
                    options = backgroundOptions,
                    selectedKey = backgroundOptions.firstOrNull { it.key == state.backgroundKey } ?: backgroundOptions.first(),
                    optionLabel = { it.label },
                    onOptionSelected = { onBackgroundSelected(it.key) },
                    chipPreview = { option, _ ->
                        option.color?.let { color ->
                            Box(Modifier.size(12.dp).clip(CircleShape).background(color))
                        }
                    },
                )
                Spacer(modifier = Modifier.height(4.dp))
                TvFormChipOptionRow(
                    label = "焦点效果",
                    options = focusEffectOptions,
                    selectedKey = focusEffectOptions.firstOrNull { it.key == state.focusEffectKey } ?: focusEffectOptions.first(),
                    optionLabel = { it.label },
                    onOptionSelected = { onFocusEffectSelected(it.key) },
                )
                Spacer(modifier = Modifier.height(4.dp))
                TvFormChipOptionRow(
                    label = "图片代理",
                    options = imageSourceOptions,
                    selectedKey = imageSourceOptions.firstOrNull { it.key == state.imageSourceKey } ?: imageSourceOptions.first(),
                    optionLabel = { it.label },
                    onOptionSelected = { onImageSourceSelected(it.key) },
                )
                Spacer(modifier = Modifier.height(4.dp))
                TvFormChipOptionRow(
                    label = "播放器内核",
                    options = playerKernelOptions,
                    selectedKey = playerKernelOptions.firstOrNull { it.key == state.playerKernelKey } ?: playerKernelOptions.first(),
                    optionLabel = { it.label },
                    onOptionSelected = { onPlayerKernelSelected(it.key) },
                )
            }

            // ═══ 3. 播放与媒体 ═══
            TvFormPanel(title = "播放与媒体") {
                TvFormSwitchRow(
                    label = "自动去广告",
                    checked = state.adFilterEnabled,
                    onCheckedChange = onAdFilterToggle,
                )
            }

            // ═══ 4. 弹幕配置 ═══
            TvFormPanel(title = "弹幕配置") {
                TvFormTextField(
                    label = "弹幕 API",
                    value = state.danmakuApi,
                    onValueChange = onDanmakuApiChange,
                )
                Spacer(modifier = Modifier.height(12.dp))
                TvFormActionButton(
                    label = "手动匹配",
                    onClick = onDanmakuMatchClick,
                    accentColor = TvTokens.FormBorder,
                )
                Spacer(modifier = Modifier.height(12.dp))
                TvFormSwitchRow(
                    label = "弹幕显示",
                    checked = state.danmakuEnabled,
                    onCheckedChange = onDanmakuEnabledToggle,
                )
                Spacer(modifier = Modifier.height(12.dp))
                TvFormSliderRow(
                    label = "不透明度",
                    value = state.danmakuOpacity,
                    onValueChange = onDanmakuOpacityChange,
                    valueRange = 0.2f..1f,
                    step = 0.05f,
                )
                Spacer(modifier = Modifier.height(8.dp))
                TvFormSliderRow(
                    label = "字体缩放",
                    value = state.danmakuFontScale,
                    onValueChange = onDanmakuFontScaleChange,
                    valueRange = 0.5f..2f,
                    step = 0.1f,
                    valueDisplay = { "%.1fx".format(it) },
                )
                Spacer(modifier = Modifier.height(8.dp))
                TvFormSliderRow(
                    label = "显示区域",
                    value = state.danmakuDisplayArea,
                    onValueChange = onDanmakuDisplayAreaChange,
                    valueRange = 0.25f..1f,
                    step = 0.05f,
                )
                Spacer(modifier = Modifier.height(12.dp))
                TvFormSwitchRow(
                    label = "防止重叠",
                    checked = state.danmakuPreventOverlap,
                    onCheckedChange = onDanmakuPreventOverlapToggle,
                )
                Spacer(modifier = Modifier.height(12.dp))
                TvFormSwitchRow(
                    label = "速度同步",
                    checked = state.danmakuSyncVideoSpeed,
                    onCheckedChange = onDanmakuSyncSpeedToggle,
                )
                Spacer(modifier = Modifier.height(16.dp))
                TvFormActionButton(
                    label = if (state.savingDanmaku) "保存中..." else "保存弹幕配置",
                    onClick = onDanmakuSave,
                )
            }

            // ═══ 5. 缓存 ═══
            TvFormPanel(title = "缓存管理") {
                TvFormValueRow(
                    label = "缓存大小",
                    value = state.cacheSizeText,
                )
                Spacer(modifier = Modifier.height(12.dp))
                TvFormActionButton(
                    label = if (state.clearingCache) "清理中..." else "清除缓存",
                    onClick = onCacheClear,
                    accentColor = TvTokens.Danger,
                )
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }

    // ═══ 底部通知浮层 ═══
    TvActionNotice(
        text = state.noticeText,
        visible = state.noticeVisible,
        onDismiss = onNoticeDismiss,
    )
}
