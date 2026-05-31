package org.moontechlab.selene.tv.core.data.storage

/**
 * TV 服务器配置。
 *
 * @property baseUrl 服务器地址。
 * @property account 账号。
 * @property password 密码。
 */
data class TvServerConfig(
    val baseUrl: String,
    val account: String,
    val password: String,
)

/**
 * TV 偏好内存存储实现。
 */
class TvPreferencesStore {
    /** 当前服务器配置。 */
    private var serverConfig: TvServerConfig? = null

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
        // 首期使用内存存储，替换为 DataStore 时保持同名契约。
        serverConfig = TvServerConfig(
            baseUrl = baseUrl,
            account = account,
            password = password,
        )
    }

    /**
     * 读取服务器配置。
     *
     * @return 当前服务器配置；未保存时返回 null。
     */
    suspend fun readServerConfig(): TvServerConfig? = serverConfig
}
