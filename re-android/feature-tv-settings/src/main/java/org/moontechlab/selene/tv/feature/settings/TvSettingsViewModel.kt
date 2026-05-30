package org.moontechlab.selene.tv.feature.settings

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * TV 设置界面状态。
 *
 * @property serverUrl 服务器地址。
 * @property account 账号。
 * @property danmakuEnabled 是否开启弹幕。
 */
data class TvSettingsUiState(
    val serverUrl: String = "",
    val account: String = "",
    val danmakuEnabled: Boolean = true,
)

/**
 * TV 设置 ViewModel。
 */
class TvSettingsViewModel {
    /** 设置内部状态。 */
    private val mutableState = MutableStateFlow(TvSettingsUiState())

    /** 设置公开状态。 */
    val state: StateFlow<TvSettingsUiState> = mutableState

    /**
     * 更新服务器表单。
     *
     * @param serverUrl 服务器地址。
     * @param account 账号。
     */
    fun updateServerForm(serverUrl: String, account: String) {
        // 设置页只更新表单值，保存动作后续再接仓库，不在输入阶段触发登录。
        mutableState.value = mutableState.value.copy(
            serverUrl = serverUrl,
            account = account,
        )
    }
}
