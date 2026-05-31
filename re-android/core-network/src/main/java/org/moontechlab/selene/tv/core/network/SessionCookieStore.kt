package org.moontechlab.selene.tv.core.network

/**
 * TV 会话信息。
 *
 * @property baseUrl 服务器基础地址。
 * @property account 当前账号。
 * @property cookie 当前会话 Cookie。
 */
data class SessionPayload(
    val baseUrl: String,
    val account: String,
    val cookie: String,
)

/**
 * TV 会话 Cookie 存储。
 */
class SessionCookieStore {
    /**
     * 当前内存会话。
     */
    private var session: SessionPayload? = null

    /**
     * 保存服务器会话。
     *
     * @param baseUrl 服务器基础地址。
     * @param account 当前账号。
     * @param cookie 当前会话 Cookie。
     */
    suspend fun saveSession(
        baseUrl: String,
        account: String,
        cookie: String,
    ) {
        // 首期先提供可测试内存实现，持久化存储替换时保持同一接口。
        session = SessionPayload(
            baseUrl = baseUrl,
            account = account,
            cookie = cookie,
        )
    }

    /**
     * 读取当前服务器会话。
     *
     * @return 当前会话；未配置时返回 null。
     */
    suspend fun readSession(): SessionPayload? = session

    /**
     * 同步读取当前会话。
     *
     * @return 当前会话；未配置时返回 null。
     */
    fun readSessionNow(): SessionPayload? = session

    /**
     * 同步读取当前 Cookie。
     *
     * @return 当前 Cookie；未登录时返回 null。
     */
    fun currentCookie(): String? = session?.cookie
}
