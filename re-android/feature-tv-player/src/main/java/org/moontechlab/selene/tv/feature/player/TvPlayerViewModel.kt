package org.moontechlab.selene.tv.feature.player

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * TV 全屏播放器界面状态。
 *
 * @property isMenuVisible 底部菜单是否可见。
 * @property selectedTopMenu 当前一级菜单。
 * @property selectedOtherMenuItem 其它菜单当前默认项。
 */
data class TvPlayerUiState(
    val isMenuVisible: Boolean = false,
    val selectedTopMenu: String = PLAYER_MENU_PLAYLIST,
    val selectedOtherMenuItem: String = PLAYER_OTHER_ENGINE_SWITCH,
)

/**
 * TV 全屏播放器 ViewModel。
 */
class TvPlayerViewModel {
    /** 播放器内部状态。 */
    private val mutableState = MutableStateFlow(TvPlayerUiState())

    /** 播放器公开状态。 */
    val state: StateFlow<TvPlayerUiState> = mutableState

    /**
     * 打开指定一级菜单。
     *
     * @param menu 一级菜单名称。
     */
    fun openMenu(menu: String) {
        // 底部菜单由壳层状态控制，不能触发底层播放器重建。
        mutableState.value = mutableState.value.copy(
            isMenuVisible = true,
            selectedTopMenu = menu,
        )
    }
}

/** 播放列表一级菜单。 */
const val PLAYER_MENU_PLAYLIST = "播放列表"

/** 其它一级菜单。 */
const val PLAYER_MENU_OTHER = "其它"

/** 内核切换二级菜单项。 */
const val PLAYER_OTHER_ENGINE_SWITCH = "内核切换"
