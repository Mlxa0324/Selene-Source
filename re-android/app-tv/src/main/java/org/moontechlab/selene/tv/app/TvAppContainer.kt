package org.moontechlab.selene.tv.app

import org.moontechlab.selene.tv.core.data.repository.TvHomeRepository
import org.moontechlab.selene.tv.core.data.repository.TvPlaybackRepository
import org.moontechlab.selene.tv.core.data.model.TvHomePayload
import org.moontechlab.selene.tv.core.network.SeleneTvGatewayClient
import org.moontechlab.selene.tv.core.network.SeleneTvNetworkFactory
import org.moontechlab.selene.tv.core.network.SessionCookieStore
import org.moontechlab.selene.tv.feature.home.TvHomeViewModel

/**
 * TV 本地后台网关配置。
 *
 * @property baseUrl 后台基础地址。
 * @property username 登录账号。
 * @property password 登录密码。
 */
data class TvLocalGatewayConfig(
    val baseUrl: String,
    val username: String,
    val password: String,
) {
    /** 配置是否具备登录所需字段。 */
    val isComplete: Boolean
        get() = baseUrl.isNotBlank() && username.isNotBlank() && password.isNotBlank()

    companion object {
        /**
         * 从 BuildConfig 创建本地后台配置。
         *
         * @return 本地后台配置。
         */
        fun fromBuildConfig(): TvLocalGatewayConfig {
            return TvLocalGatewayConfig(
                baseUrl = BuildConfig.SELENE_TV_BASE_URL,
                username = BuildConfig.SELENE_TV_USERNAME,
                password = BuildConfig.SELENE_TV_PASSWORD,
            )
        }
    }
}

/**
 * TV 应用依赖容器。
 *
 * @property gatewayConfig 本地后台网关配置。
 * @property sessionCookieStore 会话存储。
 * @property gatewayClientFactory 后台客户端工厂。
 * @property playbackRepository 播放记录仓库。
 */
class TvAppContainer(
    private val gatewayConfig: TvLocalGatewayConfig,
    private val sessionCookieStore: SessionCookieStore = SessionCookieStore(),
    private val gatewayClientFactory: (String, SessionCookieStore) -> SeleneTvGatewayClient = { baseUrl, store ->
        SeleneTvNetworkFactory.create(
            rawBaseUrl = baseUrl,
            sessionCookieStore = store,
        )
    },
    private val playbackRepository: TvPlaybackRepository = TvPlaybackRepository(),
) {
    /** 后台客户端按需创建，避免缺配置时启动阶段直接抛错。 */
    private val gatewayClient: SeleneTvGatewayClient? by lazy {
        if (gatewayConfig.isComplete) {
            gatewayClientFactory(gatewayConfig.baseUrl, sessionCookieStore)
        } else {
            null
        }
    }

    /**
     * 创建首页 ViewModel。
     *
     * @return 首页 ViewModel。
     */
    fun createHomeViewModel(): TvHomeViewModel {
        return TvHomeViewModel(loadHome = ::loadHome)
    }

    /**
     * 加载真实后台首页数据。
     *
     * @return 首页聚合数据。
     */
    private suspend fun loadHome(): TvHomePayload {
        // 首页数据请求前保证本地配置已经换成有效 Cookie。
        ensureSession()
        return TvHomeRepository(
            api = requireGatewayClient().tvApi,
            playbackRepository = playbackRepository,
        ).loadHome()
    }

    /**
     * 确保已有后台登录会话。
     */
    private suspend fun ensureSession() {
        val client = requireGatewayClient()
        if (!sessionCookieStore.currentCookie().isNullOrBlank()) {
            return
        }
        client.login(
            username = gatewayConfig.username,
            password = gatewayConfig.password,
        )
    }

    /**
     * 获取后台客户端。
     *
     * @return 后台客户端。
     */
    private fun requireGatewayClient(): SeleneTvGatewayClient {
        return gatewayClient ?: throw IllegalStateException(LOCAL_CONFIG_MISSING_MESSAGE)
    }

    private companion object {
        /** 本地后台配置缺失提示。 */
        const val LOCAL_CONFIG_MISSING_MESSAGE =
            "请填写 re-android/local.gateway.properties 后重新构建 TV 应用"
    }
}
