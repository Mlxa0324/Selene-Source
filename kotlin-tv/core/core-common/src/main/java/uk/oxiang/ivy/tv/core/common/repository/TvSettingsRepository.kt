package uk.oxiang.ivy.tv.core.common.repository

import uk.oxiang.ivy.tv.core.common.network.SeleneTvGatewayClient
import uk.oxiang.ivy.tv.core.common.storage.TvPreferencesStore

/**
 * TV 设置仓库。
 *
 * @property gatewayClient 后台网关客户端，负责登录并产出可持久化的会话 Cookie。
 * @property preferencesStore TV 偏好存储。
 */
class TvSettingsRepository(
    private val gatewayClient: SeleneTvGatewayClient,
    private val preferencesStore: TvPreferencesStore,
) {
    /**
     * 使用账号密码登录后台并持久化会话。
     *
     * @param baseUrl 服务器地址。
     * @param account 账号。
     * @param password 密码。
     */
    suspend fun loginAndSaveSession(
        baseUrl: String,
        account: String,
        password: String,
    ) {
        val session = gatewayClient.login(username = account, password = password)
        preferencesStore.saveSession(
            baseUrl = session.baseUrl,
            account = session.account,
            cookie = session.cookie,
        )
    }
}
