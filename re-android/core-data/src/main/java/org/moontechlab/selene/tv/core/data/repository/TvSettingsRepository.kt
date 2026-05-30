package org.moontechlab.selene.tv.core.data.repository

import org.moontechlab.selene.tv.core.data.storage.TvPreferencesStore

/**
 * TV 设置仓库。
 *
 * @property preferencesStore TV 偏好存储。
 */
class TvSettingsRepository(
    private val preferencesStore: TvPreferencesStore,
) {
    /**
     * 保存服务器配置。
     *
     * @param baseUrl 服务器地址。
     * @param account 账号。
     * @param password 密码。
     */
    suspend fun saveServerConfig(
        baseUrl: String,
        account: String,
        password: String,
    ) {
        // 保存配置时只更新本地表单值，不在此处触发登录请求。
        preferencesStore.saveServerConfig(
            baseUrl = baseUrl,
            account = account,
            password = password,
        )
    }
}
