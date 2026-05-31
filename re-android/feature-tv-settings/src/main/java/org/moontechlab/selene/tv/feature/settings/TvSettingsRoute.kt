package org.moontechlab.selene.tv.feature.settings

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import org.moontechlab.selene.tv.core.design.layout.TvPageScaffold
import org.moontechlab.selene.tv.core.design.layout.TvPageSection
import org.moontechlab.selene.tv.core.design.layout.TvPageStatChipData
import org.moontechlab.selene.tv.core.design.layout.TvPosterItem
import org.moontechlab.selene.tv.core.design.layout.TvPosterRail

/**
 * TV 设置路由。
 *
 * @param state 设置界面状态。
 * @param onDanmakuMatchClick 弹幕手动匹配点击回调。
 */
@Composable
fun TvSettingsRoute(
    state: TvSettingsUiState = TvSettingsUiState(),
    onDanmakuMatchClick: () -> Unit = {},
) {
    TvPageScaffold(
        title = "设置",
        subtitle = "服务器 / 账号 / 密码 / 弹幕",
        stats = listOf(
            TvPageStatChipData("配置", if (state.serverUrl.isBlank()) "未填写" else "已填写"),
            TvPageStatChipData("弹幕", if (state.danmakuEnabled) "开启" else "关闭"),
            TvPageStatChipData("缓存", state.cacheSizeText),
        ),
        modifier = Modifier.fillMaxSize(),
    ) {
        TvPageSection(
            title = "服务器配置",
            hint = "地址 / 账号 / 密码",
        ) {
            val configItems = listOf(
                TvPosterItem(id = "server", title = "服务器", subtitle = state.serverUrl.ifBlank { "未填写" }),
                TvPosterItem(id = "account", title = "账号", subtitle = state.account.ifBlank { "未填写" }),
                TvPosterItem(id = "password", title = "密码", subtitle = state.password.ifBlank { "未填写" }),
            )
            TvPosterRail(items = configItems)
        }

        TvPageSection(
            title = "弹幕匹配",
            hint = if (state.danmakuEnabled) "显示弹幕，可手动匹配片名" else "弹幕显示已关闭",
        ) {
            val danmakuItems = listOf(
                TvPosterItem(
                    id = "danmaku-api",
                    title = "弹幕服务",
                    subtitle = state.danmakuApi.ifBlank { "未填写" },
                ),
                TvPosterItem(
                    id = "danmaku-switch",
                    title = "弹幕显示",
                    subtitle = if (state.danmakuEnabled) "开启" else "关闭",
                ),
                TvPosterItem(
                    id = "danmaku-match",
                    title = "手动匹配",
                    subtitle = "进入弹幕搜索面板",
                ),
            )
            TvPosterRail(
                items = danmakuItems,
                onItemClick = { item ->
                    // 手动匹配是 TV 端弹幕搜索面板的 Kotlin 入口。
                    if (item.id == "danmaku-match") {
                        onDanmakuMatchClick()
                    }
                },
            )
        }

        TvPageSection(
            title = "播放与媒体",
            hint = "去广告 / 图片代理 / 缓存",
        ) {
            TvPosterRail(
                items = listOf(
                    TvPosterItem(
                        id = "ad-filter",
                        title = "自动去广告",
                        subtitle = if (state.adFilterEnabled) "开启" else "关闭",
                    ),
                    TvPosterItem(
                        id = "image-source",
                        title = "图片代理",
                        subtitle = state.imageSource,
                    ),
                    TvPosterItem(
                        id = "cache",
                        title = "缓存大小",
                        subtitle = state.cacheSizeText,
                    ),
                ),
            )
        }

        TvPageSection(
            title = "外观与焦点",
            hint = "主题色 / 背景 / 焦点效果",
        ) {
            TvPosterRail(
                items = listOf(
                    TvPosterItem(
                        id = "theme",
                        title = "主题色",
                        subtitle = state.themeName,
                    ),
                    TvPosterItem(
                        id = "background",
                        title = "背景",
                        subtitle = state.backgroundName,
                    ),
                    TvPosterItem(
                        id = "focus-effect",
                        title = "焦点效果",
                        subtitle = state.focusEffectName,
                    ),
                ),
            )
        }
    }
}
