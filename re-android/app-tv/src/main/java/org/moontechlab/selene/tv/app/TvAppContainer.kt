package org.moontechlab.selene.tv.app

import org.moontechlab.selene.tv.core.data.model.TvHomePayload
import org.moontechlab.selene.tv.core.data.repository.TvFavoritesRepository
import org.moontechlab.selene.tv.core.data.repository.TvHomeRepository
import org.moontechlab.selene.tv.core.data.repository.TvPlaybackRepository
import org.moontechlab.selene.tv.core.data.repository.TvSearchRepository
import org.moontechlab.selene.tv.core.data.repository.TvVideoLibraryRepository
import org.moontechlab.selene.tv.core.network.SeleneTvGatewayClient
import org.moontechlab.selene.tv.core.network.SeleneTvNetworkFactory
import org.moontechlab.selene.tv.core.network.SessionCookieStore
import org.moontechlab.selene.tv.feature.favorites.TvFavoritesViewModel
import org.moontechlab.selene.tv.feature.history.TvHistoryViewModel
import org.moontechlab.selene.tv.feature.home.TvHomeViewModel
import org.moontechlab.selene.tv.feature.home.TvVideoLibraryUiState
import org.moontechlab.selene.tv.feature.home.TvVideoLibraryViewModel
import org.moontechlab.selene.tv.feature.search.TvSearchViewModel
import org.moontechlab.selene.tv.feature.settings.TvSettingsUiState
import org.moontechlab.selene.tv.feature.settings.TvSettingsViewModel

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
     * 创建搜索 ViewModel。
     *
     * @return 搜索 ViewModel。
     */
    fun createSearchViewModel(): TvSearchViewModel {
        return TvSearchViewModel(
            search = { query ->
                ensureSession()
                TvSearchRepository(requireGatewayClient().tvApi).search(query)
            },
        )
    }

    /**
     * 创建分类视频库 ViewModel。
     *
     * @param categoryKey 分类标识。
     * @return 分类视频库 ViewModel。
     */
    fun createVideoLibraryViewModel(categoryKey: String): TvVideoLibraryViewModel {
        return TvVideoLibraryViewModel(
            categoryKey = categoryKey,
            loadCategory = ::loadVideoLibraryState,
        )
    }

    /**
     * 创建播放历史 ViewModel。
     *
     * @return 播放历史 ViewModel。
     */
    fun createHistoryViewModel(): TvHistoryViewModel {
        return TvHistoryViewModel(
            loadHistory = {
                ensureSession()
                TvPlaybackRepository(api = requireGatewayClient().tvApi)
                    .readContinueWatching()
            },
            deleteHistoryItem = { videoId ->
                ensureSession()
                TvPlaybackRepository(api = requireGatewayClient().tvApi)
                    .deletePlayRecordByKey(videoId)
            },
            clearHistory = {
                ensureSession()
                TvPlaybackRepository(api = requireGatewayClient().tvApi)
                    .clearPlayRecords()
            },
        )
    }

    /**
     * 创建收藏夹 ViewModel。
     *
     * @return 收藏夹 ViewModel。
     */
    fun createFavoritesViewModel(): TvFavoritesViewModel {
        return TvFavoritesViewModel(
            loadFavorites = {
                ensureSession()
                TvFavoritesRepository(requireGatewayClient().tvApi).readFavorites()
            },
            deleteFavoriteItem = { videoId ->
                ensureSession()
                TvFavoritesRepository(requireGatewayClient().tvApi)
                    .deleteFavoriteByKey(videoId)
            },
            clearFavorites = {
                ensureSession()
                TvFavoritesRepository(requireGatewayClient().tvApi).clearFavorites()
            },
        )
    }

    /**
     * 加载分类视频库状态。
     *
     * @param categoryKey 分类标识。
     * @return 已带远端视频列表的分类状态。
     */
    suspend fun loadVideoLibraryState(categoryKey: String): TvVideoLibraryUiState {
        ensureSession()
        val baseState = TvVideoLibraryUiState.forCategory(categoryKey)
        return baseState.copy(
            videos = TvVideoLibraryRepository(requireGatewayClient().tvApi)
                .loadCategory(categoryKey),
        )
    }

    /**
     * 创建设置页 ViewModel。
     *
     * @return 已带入本地后台配置的设置页 ViewModel。
     */
    fun createSettingsViewModel(): TvSettingsViewModel {
        return TvSettingsViewModel(
            initialState = gatewayConfig.toSettingsUiState(),
        )
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
            playbackRepository = TvPlaybackRepository(api = requireGatewayClient().tvApi),
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

/**
 * 转换为设置页展示状态。
 *
 * @return 设置页初始状态。
 */
private fun TvLocalGatewayConfig.toSettingsUiState(): TvSettingsUiState {
    return TvSettingsUiState(
        serverUrl = baseUrl,
        account = username,
        password = password,
    )
}
