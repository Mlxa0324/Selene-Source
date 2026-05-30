package org.moontechlab.selene.tv.feature.home

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.moontechlab.selene.tv.core.data.model.TvHomePayload
import org.moontechlab.selene.tv.core.data.model.TvHomeSection

/**
 * TV 首页界面状态。
 *
 * @property selectedMainTab 当前主菜单选中项。
 * @property sections 首页分区列表。
 * @property isLoading 是否正在加载首页数据。
 */
data class TvHomeUiState(
    val selectedMainTab: String = HOME_TAB_KEY,
    val sections: List<TvHomeSection> = emptyList(),
    val isLoading: Boolean = false,
)

/**
 * TV 首页 ViewModel。
 *
 * @property loadHome 首页数据加载函数。
 */
class TvHomeViewModel(
    private val loadHome: suspend () -> TvHomePayload,
) {
    /** 首页内部状态。 */
    private val mutableState = MutableStateFlow(TvHomeUiState())

    /** 首页公开状态。 */
    val state: StateFlow<TvHomeUiState> = mutableState

    /**
     * 加载首页数据。
     */
    suspend fun load() {
        // 加载过程只更新数据状态，不改变当前主菜单选中项。
        mutableState.value = mutableState.value.copy(isLoading = true)
        val payload = loadHome()
        mutableState.value = mutableState.value.copy(
            sections = payload.sections,
            selectedMainTab = HOME_TAB_KEY,
            isLoading = false,
        )
    }
}

/** 首页主菜单标识。 */
const val HOME_TAB_KEY = "home"
