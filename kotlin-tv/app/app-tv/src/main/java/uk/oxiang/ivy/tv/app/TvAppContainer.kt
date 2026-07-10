package uk.oxiang.ivy.tv.app

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import uk.oxiang.ivy.tv.core.common.network.SeleneDanmakuApi
import uk.oxiang.ivy.tv.core.common.network.SeleneDoubanApi
import uk.oxiang.ivy.tv.core.common.network.SeleneTvGatewayClient
import uk.oxiang.ivy.tv.core.common.network.SeleneTvNetworkFactory
import uk.oxiang.ivy.tv.core.common.network.SessionCookieStore
import uk.oxiang.ivy.tv.core.common.repository.DoubanRepository
import uk.oxiang.ivy.tv.core.common.repository.TvDanmakuManualMatchRepository
import uk.oxiang.ivy.tv.core.common.repository.TvDanmakuRepository
import uk.oxiang.ivy.tv.core.common.repository.TvHomeRepository
import uk.oxiang.ivy.tv.core.common.repository.TvPlaybackRepository
import uk.oxiang.ivy.tv.core.common.repository.TvSettingsRepository
import uk.oxiang.ivy.tv.core.common.storage.TvPreferencesStore
import uk.oxiang.ivy.tv.core.design.util.AppDispatchers
import uk.oxiang.ivy.tv.core.player.api.PlayerEngine
import uk.oxiang.ivy.tv.core.player.webview.WebViewPlayerEngine

/**
 * TV 本地后台网关配置。
 *
 * @property baseUrl 服务器基础地址。
 * @property username 登录账号。
 * @property password 登录密码。
 * @property danmakuBaseUrl 弹幕服务地址。
 */
data class TvLocalGatewayConfig(
    val baseUrl: String,
    val username: String,
    val password: String,
    val danmakuBaseUrl: String = "",
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
                danmakuBaseUrl = BuildConfig.SELENE_TV_DANMAKU_BASE_URL,
            )
        }
    }
}

/**
 * TV 应用依赖容器（骨架阶段）。
 *
 * 只承载 core-common/core-design/core-player 层的工厂装配，不感知任何
 * feature 模块的 ViewModel 或 Route 类型；具体业务 ViewModel 由各 feature
 * 子任务在自己模块内消费这里暴露的 Repository/Api/PlayerEngine 工厂组装。
 *
 * @property gatewayConfig 本地后台网关配置。
 * @property dataStore Jetpack Preferences DataStore 实例，由 `app-tv` 的
 * `Context.dataStore` 扩展属性单例创建并注入。
 * @property sessionCookieStore 会话存储。
 * @property gatewayClientFactory 后台客户端工厂。
 * @property danmakuApiFactory 弹幕服务接口工厂。
 * @property doubanApiFactory 豆瓣代理接口工厂。
 * @property playerEngineFactory 播放器内核工厂，默认使用 ExoPlayer 主内核。
 */
class TvAppContainer(
    private val gatewayConfig: TvLocalGatewayConfig,
    private val dataStore: DataStore<Preferences>,
    private val sessionCookieStore: SessionCookieStore = SessionCookieStore(),
    private val gatewayClientFactory: (String, SessionCookieStore) -> SeleneTvGatewayClient = { baseUrl, store ->
        SeleneTvNetworkFactory.create(rawBaseUrl = baseUrl, sessionCookieStore = store)
    },
    private val danmakuApiFactory: (String) -> SeleneDanmakuApi = { baseUrl ->
        SeleneTvNetworkFactory.createDanmakuApi(baseUrl)
    },
    private val doubanApiFactory: () -> SeleneDoubanApi = {
        SeleneTvNetworkFactory.createDoubanApi()
    },
    private val playerEngineFactory: () -> PlayerEngine = {
        // 默认使用 WebView 兜底内核，不需要 Context 依赖；需要 ExoPlayer 主内核
        // 时由 `app-tv` 组装容器时显式传入覆盖版工厂（依赖 Activity/Application Context）。
        WebViewPlayerEngine(dispatchers = AppDispatchers.createDefault())
    },
) {
    /** TV 偏好存储，供 Repository 和主题状态共用同一份 DataStore 单例。 */
    val preferencesStore: TvPreferencesStore by lazy {
        TvPreferencesStore(dataStore = dataStore)
    }

    /** 后台客户端按需创建，避免缺配置时启动阶段直接抛错。 */
    private val gatewayClient: SeleneTvGatewayClient? by lazy {
        if (gatewayConfig.isComplete) {
            gatewayClientFactory(gatewayConfig.baseUrl, sessionCookieStore)
        } else {
            null
        }
    }

    /** 弹幕仓库按需创建，未配置弹幕地址时保持空。 */
    val danmakuRepository: TvDanmakuRepository? by lazy {
        gatewayConfig.danmakuBaseUrl
            .takeIf { baseUrl -> baseUrl.isNotBlank() }
            ?.let { baseUrl -> TvDanmakuRepository(api = danmakuApiFactory(baseUrl)) }
    }

    /** 弹幕手动匹配仓库。 */
    val danmakuManualMatchRepository: TvDanmakuManualMatchRepository by lazy {
        TvDanmakuManualMatchRepository(preferencesStore = preferencesStore)
    }

    /** 豆瓣代理 API 接口。 */
    private val doubanApi by lazy { doubanApiFactory() }

    /** 豆瓣分类数据仓库，首页和分类页共享同一份会话级缓存。 */
    val doubanRepository: DoubanRepository by lazy {
        DoubanRepository(api = doubanApi)
    }

    /** 设置仓库，需要已配置完整的后台网关信息。 */
    val settingsRepository: TvSettingsRepository? by lazy {
        gatewayClient?.let { client ->
            TvSettingsRepository(gatewayClient = client, preferencesStore = preferencesStore)
        }
    }

    /** 播放记录仓库，未配置网关信息时回退空列表。 */
    private val playbackRepository: TvPlaybackRepository by lazy {
        TvPlaybackRepository(api = gatewayClient?.tvApi)
    }

    /** 首页聚合仓库，骨架阶段供 `TvNavGraph` 直接接线首页占位内容。 */
    val homeRepository: TvHomeRepository by lazy {
        TvHomeRepository(playbackRepository = playbackRepository, doubanRepository = doubanRepository)
    }

    /**
     * 创建默认播放器内核实例。
     *
     * @return 播放器内核，具体实现由 [playerEngineFactory] 决定。
     */
    fun createPlayerEngine(): PlayerEngine = playerEngineFactory()

    /**
     * 要求已配置完整后台网关信息的客户端，未配置时抛出异常。
     *
     * @return 已就绪的后台网关客户端。
     */
    fun requireGatewayClient(): SeleneTvGatewayClient {
        return gatewayClient ?: error("尚未配置完整的本地后台网关信息")
    }

    /** 清除豆瓣仓库内存缓存。 */
    fun clearDoubanCache() {
        doubanRepository.clearCache()
    }
}
