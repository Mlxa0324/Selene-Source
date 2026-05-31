package org.moontechlab.selene.tv.feature.settings

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * TV 设置界面状态。
 *
 * @property serverUrl 服务器地址。
 * @property account 账号。
 * @property password 密码。
 * @property danmakuApi 弹幕服务地址。
 * @property danmakuEnabled 是否开启弹幕。
 * @property adFilterEnabled 是否开启自动去广告。
 * @property imageSource 图片代理名称。
 * @property themeName 主题色名称。
 * @property backgroundName 背景名称。
 * @property focusEffectName 焦点效果名称。
 * @property cacheSizeText 缓存大小展示文本。
 */
data class TvSettingsUiState(
    val serverUrl: String = "",
    val account: String = "",
    val password: String = "",
    val danmakuApi: String = "",
    val danmakuEnabled: Boolean = true,
    val adFilterEnabled: Boolean = true,
    val imageSource: String = "直连",
    val themeName: String = "青绿",
    val backgroundName: String = "深蓝",
    val focusEffectName: String = "平滑边框",
    val cacheSizeText: String = "0 MB",
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
        // 设置页只更新表单值，保存动作由仓库层处理，不在输入阶段触发登录。
        mutableState.value = mutableState.value.copy(
            serverUrl = serverUrl,
            account = account,
        )
    }

    /**
     * 更新账号密码。
     *
     * @param password 密码。
     */
    fun updatePassword(password: String) {
        // 密码单独更新，便于遥控器焦点停留在密码项时局部提交。
        mutableState.value = mutableState.value.copy(password = password)
    }

    /**
     * 更新弹幕配置。
     *
     * @param danmakuApi 弹幕服务地址。
     * @param enabled 是否显示弹幕。
     */
    fun updateDanmaku(danmakuApi: String, enabled: Boolean) {
        // 弹幕匹配入口读取同一份开关状态，避免播放器和设置页显示不一致。
        mutableState.value = mutableState.value.copy(
            danmakuApi = danmakuApi,
            danmakuEnabled = enabled,
        )
    }

    /**
     * 更新播放与媒体配置。
     *
     * @param adFilterEnabled 是否开启自动去广告。
     * @param imageSource 图片代理名称。
     * @param cacheSizeText 缓存大小展示文本。
     */
    fun updateMediaOptions(
        adFilterEnabled: Boolean,
        imageSource: String,
        cacheSizeText: String,
    ) {
        // 媒体配置和缓存信息同屏展示，便于大屏上统一确认当前播放环境。
        mutableState.value = mutableState.value.copy(
            adFilterEnabled = adFilterEnabled,
            imageSource = imageSource,
            cacheSizeText = cacheSizeText,
        )
    }

    /**
     * 更新外观和焦点配置。
     *
     * @param themeName 主题色名称。
     * @param backgroundName 背景名称。
     * @param focusEffectName 焦点效果名称。
     */
    fun updateAppearance(
        themeName: String,
        backgroundName: String,
        focusEffectName: String,
    ) {
        // 外观配置直接影响 TV 壳视觉反馈，需要保持在同一状态对象中。
        mutableState.value = mutableState.value.copy(
            themeName = themeName,
            backgroundName = backgroundName,
            focusEffectName = focusEffectName,
        )
    }
}
