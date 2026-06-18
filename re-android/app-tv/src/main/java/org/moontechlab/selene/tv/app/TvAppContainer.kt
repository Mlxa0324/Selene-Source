package org.moontechlab.selene.tv.app

import org.moontechlab.selene.tv.core.data.model.TvDanmakuAnimePayload
import org.moontechlab.selene.tv.core.data.model.TvDanmakuCommentPayload
import org.moontechlab.selene.tv.core.data.model.TvDanmakuEpisodePayload
import org.moontechlab.selene.tv.core.data.model.TvDanmakuLoadPayload
import org.moontechlab.selene.tv.core.data.model.TvDanmakuSearchPayload
import org.moontechlab.selene.tv.core.data.model.TvHomePayload
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.data.model.TvVideoDetail
import org.moontechlab.selene.tv.core.player.api.PlaybackEpisode
import org.moontechlab.selene.tv.core.player.api.PlaybackSource
import org.moontechlab.selene.tv.core.data.repository.DoubanCategoryParams
import org.moontechlab.selene.tv.core.data.repository.DoubanRepository
import org.moontechlab.selene.tv.core.data.repository.TvDanmakuManualMatchRepository
import org.moontechlab.selene.tv.core.data.repository.TvDanmakuRepository
import org.moontechlab.selene.tv.core.data.repository.TvDetailRepository
import org.moontechlab.selene.tv.core.data.repository.TvFavoritesRepository
import org.moontechlab.selene.tv.core.data.repository.TvHomeRepository
import org.moontechlab.selene.tv.core.data.repository.TvPlaybackRepository
import org.moontechlab.selene.tv.core.data.repository.TvSearchRepository
import org.moontechlab.selene.tv.core.data.repository.TvVideoLibraryRepository
import org.moontechlab.selene.tv.core.data.storage.TvPreferencesStore
import org.moontechlab.selene.tv.core.design.threading.AppDispatchers
import org.moontechlab.selene.tv.core.network.SeleneDanmakuApi
import org.moontechlab.selene.tv.core.network.SeleneDoubanApi
import org.moontechlab.selene.tv.core.network.SeleneTvGatewayClient
import org.moontechlab.selene.tv.core.network.SeleneTvNetworkFactory
import org.moontechlab.selene.tv.core.network.SessionCookieStore
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.core.player.api.PlayerEngine
import org.moontechlab.selene.tv.core.player.webview.WebViewPlayerEngine
import org.moontechlab.selene.tv.core.player.webview.WebViewPlayerSession
import org.moontechlab.selene.tv.feature.favorites.TvFavoritesViewModel
import org.moontechlab.selene.tv.feature.detail.TvDetailEntry
import org.moontechlab.selene.tv.feature.detail.TvDetailResumeRecord
import org.moontechlab.selene.tv.feature.detail.TvDetailViewModel
import org.moontechlab.selene.tv.feature.history.TvHistoryViewModel
import org.moontechlab.selene.tv.feature.home.TvHomeViewModel
import org.moontechlab.selene.tv.feature.home.TvVideoLibraryUiState
import org.moontechlab.selene.tv.feature.home.TvVideoLibraryViewModel
import org.moontechlab.selene.tv.feature.player.TvPlayerViewModel
import org.moontechlab.selene.tv.feature.player.TvPlayerDanmakuComment
import org.moontechlab.selene.tv.feature.player.TvPlayerDanmakuLoadResult
import org.moontechlab.selene.tv.feature.search.TvSearchViewModel
import org.moontechlab.selene.tv.feature.settings.TvDanmakuMatchViewModel
import org.moontechlab.selene.tv.feature.settings.TvDanmakuSearchAnime
import org.moontechlab.selene.tv.feature.settings.TvDanmakuSearchEpisode
import org.moontechlab.selene.tv.feature.settings.TvDanmakuSearchResult
import org.moontechlab.selene.tv.feature.settings.TvSettingsUiState
import org.moontechlab.selene.tv.feature.settings.TvSettingsViewModel

/**
 * TV 本地后台网关配置。
 *
 * @property baseUrl 后台基础地址。
 * @property username 登录账号。
 * @property password 登录密码。
 * @property danmakuBaseUrl 弹幕服务基础地址。
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
 * TV 应用依赖容器。
 *
 * @property gatewayConfig 本地后台网关配置。
 * @property sessionCookieStore 会话存储。
 * @property preferencesStore TV 偏好存储。
 * @property gatewayClientFactory 后台客户端工厂。
 * @property danmakuApiFactory 弹幕服务接口工厂。
 * @property playerEngineFactory 播放器内核工厂。
 */
class TvAppContainer(
    private val gatewayConfig: TvLocalGatewayConfig,
    private val sessionCookieStore: SessionCookieStore = SessionCookieStore(),
    private val preferencesStore: TvPreferencesStore = TvPreferencesStore(),
    private val gatewayClientFactory: (String, SessionCookieStore) -> SeleneTvGatewayClient = { baseUrl, store ->
        SeleneTvNetworkFactory.create(
            rawBaseUrl = baseUrl,
            sessionCookieStore = store,
        )
    },
    private val danmakuApiFactory: (String) -> SeleneDanmakuApi = { baseUrl ->
        SeleneTvNetworkFactory.createDanmakuApi(baseUrl)
    },
    private val playerEngineFactory: () -> PlayerEngine = {
        WebViewPlayerEngine(dispatchers = AppDispatchers.createDefault())
    },
    private val doubanApiFactory: () -> SeleneDoubanApi = {
        SeleneTvNetworkFactory.createDoubanApi()
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

    /** 弹幕仓库按需创建，未配置弹幕地址时保持空。 */
    private val danmakuRepository: TvDanmakuRepository? by lazy {
        gatewayConfig.danmakuBaseUrl
            .takeIf { baseUrl -> baseUrl.isNotBlank() }
            ?.let { baseUrl -> TvDanmakuRepository(api = danmakuApiFactory(baseUrl)) }
    }

    /** 弹幕手动匹配仓库。 */
    private val danmakuManualMatchRepository: TvDanmakuManualMatchRepository by lazy {
        TvDanmakuManualMatchRepository(preferencesStore = preferencesStore)
    }

    /** 豆瓣代理 API 接口。 */
    private val doubanApi by lazy {
        doubanApiFactory()
    }

    /** 豆瓣分类数据仓库。 */
    internal val doubanRepository: DoubanRepository by lazy {
        DoubanRepository(api = doubanApi)
    }

    /**
     * 清除豆瓣仓库内存缓存。
     */
    fun clearDoubanCache() {
        doubanRepository.clearCache()
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
            loadSearchHistory = {
                ensureSession()
                TvSearchRepository(requireGatewayClient().tvApi).readSearchHistory()
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
            loadCategory = { key, filters, page -> loadCategoryVideos(key, filters, page) },
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
     * 创建详情 ViewModel。
     *
     * @param source 播放来源标识。
     * @param videoTitle 视频标题，用于精确详情失败后的搜索兜底。
     * @param playerEngine 预览播放器引擎。
     * @return 详情页 ViewModel。
     */
    fun createDetailViewModel(
        source: String,
        videoTitle: String = "",
        playerEngine: PlayerEngine? = null,
    ): TvDetailViewModel {
        val initialEntry = TvDetailEntry(
            source = source,
            videoId = "",
            title = videoTitle,
            searchTitle = videoTitle,
        )
        var exactFallbackDetail: TvVideoDetail? = null
        return TvDetailViewModel(
            initialEntry = initialEntry,
            playerEngine = playerEngine,
            loadExactSources = { entry ->
                ensureSession()
                val repo = TvDetailRepository(requireGatewayClient().tvApi)
                // 精确详情即使没有剧集，也能提供标题、年份和封面给标题补源兜底。
                val exactDetail = repo.loadDetail(source = entry.source, id = entry.videoId)
                exactFallbackDetail = exactDetail
                exactDetail?.sources
                    .orEmpty()
                    .filter { videoSource -> videoSource.episodes.isNotEmpty() }
            },
            loadMoreSources = { entry, onIncremental ->
                ensureSession()
                val fallbackDetail = exactFallbackDetail
                val fallbackTitle = entry.resolvedSearchTitle
                    .ifBlank { fallbackDetail?.title.orEmpty() }
                    .ifBlank { entry.videoId }
                val sources = TvDetailRepository(requireGatewayClient().tvApi)
                    .loadMoreSourcesByEntry(
                        title = fallbackTitle,
                        searchTitle = fallbackTitle,
                        year = entry.year.ifBlank { fallbackDetail?.year.orEmpty() },
                    )
                // Kotlin 当前搜索接口是批量响应，通过同一增量入口回调一次，对齐 Flutter SSE 契约。
                onIncremental(sources)
                sources
            },
            loadFavoriteState = { entry ->
                TvFavoritesRepository(requireGatewayClient().tvApi)
                    .readFavorites().any { it.id == entry.videoId }
            },
            saveFavoriteState = { _, _ ->
                // 收藏写入待后续接入 Favorite API
            },
            loadResumeRecord = { entry ->
                val record = TvPlaybackRepository(api = requireGatewayClient().tvApi)
                    .readContinueWatching()
                    .firstOrNull { card -> card.source == entry.source && card.id == entry.videoId }
                record?.let { card ->
                    TvDetailResumeRecord(
                        source = card.source,
                        videoId = card.id,
                        // 远端播放记录集数按 Flutter 约定为 1-based，播放器请求使用 0-based。
                        episodeIndex = (card.episodeIndex - 1).coerceAtLeast(0),
                        positionMs = card.playTime * 1000L,
                        sourceName = card.sourceName,
                    )
                }
            },
        )
    }

    /**
     * 创建播放器 ViewModel。
     *
     * @param playbackRequest 详情页传入的完整播放请求。
     * @param playerEngine 指定播放器内核，WebView 会话共享命令总线时使用。
     * @return 已注入播放器内核的 ViewModel。
     */
    fun createPlayerViewModel(
        playbackRequest: PlaybackRequest?,
        playerEngine: PlayerEngine? = null,
        availableSources: List<PlaybackSource> = emptyList(),
        allEpisodes: List<PlaybackEpisode> = emptyList(),
    ): TvPlayerViewModel {
        return TvPlayerViewModel(
            initialRequest = playbackRequest,
            playerEngine = playerEngine ?: playerEngineFactory(),
            availableSources = availableSources,
            allEpisodes = allEpisodes,
            loadDanmaku = ::loadDanmakuForPlayback,
            loadSkipIntroSeconds = preferencesStore::getSkipIntroSeconds,
            loadSkipOutroSeconds = preferencesStore::getSkipOutroSeconds,
            saveSkipIntroSeconds = preferencesStore::saveSkipIntroSeconds,
            saveSkipOutroSeconds = preferencesStore::saveSkipOutroSeconds,
        )
    }

    /**
     * 创建 WebView 播放会话。
     *
     * @return 共享命令总线的 WebView 播放会话。
     */
    fun createWebViewPlayerSession(): WebViewPlayerSession {
        return WebViewPlayerSession(dispatchers = AppDispatchers.createDefault())
    }

    /**
     * 加载分类视频列表（按分类分支，对齐 Flutter TV defaultLoadCategoryData）。
     *
     * @param categoryKey 分类标识。
     * @param filters 当前已选筛选条件。
     * @param page 页码（触底加载）
     * @return 分类视频卡片列表。
     */
    suspend fun loadCategoryVideos(
        categoryKey: String,
        filters: List<org.moontechlab.selene.tv.feature.home.TvLibraryFilter>,
        page: Int = 0,
    ): List<TvVideoCard> {
        return when (categoryKey) {
            "movie" -> loadMovieCategory(filters, page)
            "tv" -> loadSeriesCategory(filters, page)
            "anime" -> loadAnimeCategory(filters, page)
            "show" -> loadVarietyCategory(filters, page)
            else -> emptyList()
        }
    }

    /**
     * 加载电影分类数据（对齐 Flutter _loadMovieCategoryData）。
     */
    private suspend fun loadMovieCategory(
        filters: List<org.moontechlab.selene.tv.feature.home.TvLibraryFilter>,
        page: Int = 0,
    ): List<TvVideoCard> {
        val sel = filters.associate { f -> f.key to f.selectedOption.apiValue }
        val category = sel["分类"] ?: "热门"

        return if (category != "全部") {
            // Simple mode: getCategoryData(kind=movie, category, type=region)
            val params = DoubanCategoryParams(
                kind = "movie",
                category = category,
                type = sel["地区"] ?: "全部",
                page = page,
            )
            doubanRepository.loadCategory(params)
        } else {
            // Advanced mode: fetchDoubanRecommends(kind=movie, format=all)
            val params = DoubanCategoryParams(
                kind = "movie",
                category = "全部",
                type = sel["类型"] ?: "all",
                format = "all",
                region = sel["地区"] ?: "all",
                year = sel["年代"] ?: "all",
                platform = sel["平台"] ?: "all",
                sort = sel["排序"] ?: "T",
                page = page,
            )
            doubanRepository.loadCategory(params)
        }
    }

    /**
     * 加载剧集分类数据（对齐 Flutter _loadSeriesCategoryData）。
     */
    private suspend fun loadSeriesCategory(
        filters: List<org.moontechlab.selene.tv.feature.home.TvLibraryFilter>,
        page: Int = 0,
    ): List<TvVideoCard> {
        val sel = filters.associate { f -> f.key to f.selectedOption.apiValue }
        val category = sel["分类"] ?: "最近热门"

        return if (category != "全部") {
            // Simple mode: getCategoryData(kind=tv, category, type)
            val params = DoubanCategoryParams(
                kind = "tv",
                category = category,
                type = sel["类型"] ?: "tv",
                page = page,
            )
            doubanRepository.loadCategory(params)
        } else {
            // Advanced mode: fetchDoubanRecommends(kind=tv, format=电视剧)
            val params = DoubanCategoryParams(
                kind = "tv",
                category = "全部",
                type = sel["类型"] ?: "all",
                format = "电视剧",
                region = sel["地区"] ?: "all",
                year = sel["年代"] ?: "all",
                platform = sel["平台"] ?: "all",
                sort = sel["排序"] ?: "T",
                page = page,
            )
            doubanRepository.loadCategory(params)
        }
    }

    /**
     * 加载动漫分类数据（对齐 Flutter _loadAnimeCategoryData）。
     */
    private suspend fun loadAnimeCategory(
        filters: List<org.moontechlab.selene.tv.feature.home.TvLibraryFilter>,
        page: Int = 0,
    ): List<TvVideoCard> {
        val sel = filters.associate { f -> f.key to f.selectedOption.apiValue }
        val category = sel["分类"] ?: "每日放送"

        return when (category) {
            "每日放送" -> {
                // Bangumi 日历接口：Kotlin TV 暂未接入 BangumiService，返回空列表。
                // 后续可接入 Bangumi API 实现真正的每日放送数据。
                emptyList()
            }
            "番剧" -> {
                // fetchDoubanRecommends(kind=tv, category=动画, format=电视剧, type→label)
                val params = DoubanCategoryParams(
                    kind = "tv",
                    category = "全部",
                    type = "动画",
                    format = "电视剧",
                    label = sel["类型"] ?: "all",
                    region = sel["地区"] ?: "all",
                    year = sel["年代"] ?: "all",
                    platform = sel["平台"] ?: "all",
                    sort = sel["排序"] ?: "T",
                    page = page,
                )
                doubanRepository.loadCategory(params)
            }
            else -> {
                // 剧场版: fetchDoubanRecommends(kind=movie, category=动画, format=all, type→label, no platform)
                val params = DoubanCategoryParams(
                    kind = "movie",
                    category = "全部",
                    type = "动画",
                    format = "all",
                    label = sel["类型"] ?: "all",
                    region = sel["地区"] ?: "all",
                    year = sel["年代"] ?: "all",
                    platform = "all",
                    sort = sel["排序"] ?: "T",
                )
                doubanRepository.loadCategory(params)
            }
        }
    }

    /**
     * 加载综艺分类数据（对齐 Flutter _loadVarietyCategoryData）。
     */
    private suspend fun loadVarietyCategory(
        filters: List<org.moontechlab.selene.tv.feature.home.TvLibraryFilter>,
        page: Int = 0,
    ): List<TvVideoCard> {
        val sel = filters.associate { f -> f.key to f.selectedOption.apiValue }
        val category = sel["分类"] ?: "最近热门"

        return if (category != "全部") {
            // Simple mode: getCategoryData(kind=tv, category=show, type)
            val params = DoubanCategoryParams(
                kind = "tv",
                category = "show",
                type = sel["类型"] ?: "show",
                page = page,
            )
            doubanRepository.loadCategory(params)
        } else {
            // Advanced mode: fetchDoubanRecommends(kind=tv, format=综艺)
            val params = DoubanCategoryParams(
                kind = "tv",
                category = "全部",
                type = sel["类型"] ?: "all",
                format = "综艺",
                region = sel["地区"] ?: "all",
                year = sel["年代"] ?: "all",
                platform = sel["平台"] ?: "all",
                sort = sel["排序"] ?: "T",
                page = page,
            )
            doubanRepository.loadCategory(params)
        }
    }

    /** 已废弃：分类加载已迁移至豆瓣代理 API，保留供 TvVideoLibraryRepository 兼容使用。 */
    @Deprecated("分类数据改为豆瓣代理，不再走后台搜索")
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
     * @param loadCacheSize 缓存大小加载函数（不传则返回 "0 MB"）。
     * @param clearCache 缓存清理函数（不传则只清 Douban 仓库）。
     * @return 已带入本地后台配置的设置页 ViewModel。
     */
    fun createSettingsViewModel(
        loadCacheSize: suspend () -> String = { "0 MB" },
        clearCache: suspend () -> Unit = {
            doubanRepository.clearCache()
        },
    ): TvSettingsViewModel {
        return TvSettingsViewModel(
            initialState = TvSettingsUiState(
                serverUrl = gatewayConfig.baseUrl,
                account = gatewayConfig.username,
                password = gatewayConfig.password,
                danmakuApi = gatewayConfig.danmakuBaseUrl,
            ),
            loadCacheSize = loadCacheSize,
            clearCache = clearCache,
            saveServerConfig = { url, account, password ->
                preferencesStore.saveServerConfig(url, account, password)
            },
            saveDanmakuApi = { api ->
                preferencesStore.saveDanmakuApi(api)
            },
            saveDanmakuEnabled = { enabled ->
                preferencesStore.saveDanmakuEnabled(enabled)
            },
            saveDanmakuOpacity = { opacity ->
                preferencesStore.saveDanmakuOpacity(opacity)
            },
            saveDanmakuFontScale = { scale ->
                preferencesStore.saveDanmakuFontScale(scale)
            },
            saveDanmakuDisplayArea = { area ->
                preferencesStore.saveDanmakuDisplayArea(area)
            },
            saveDanmakuPreventOverlap = { prevent ->
                preferencesStore.saveDanmakuPreventOverlap(prevent)
            },
            saveDanmakuSyncVideoSpeed = { sync ->
                preferencesStore.saveDanmakuSyncVideoSpeed(sync)
            },
            saveAdFilter = { enabled ->
                preferencesStore.saveAdFilterEnabled(enabled)
            },
            saveImageSource = { source ->
                preferencesStore.saveImageSource(source)
            },
            saveTheme = { themeKey ->
                preferencesStore.saveThemeKey(themeKey)
            },
            saveBackground = { backgroundKey ->
                preferencesStore.saveBackgroundKey(backgroundKey)
            },
            saveFocusEffect = { effectKey ->
                preferencesStore.saveFocusEffectKey(effectKey)
            },
            savePlayerKernel = { kernel ->
                preferencesStore.savePlayerKernel(kernel)
            },
        )
    }

    /**
     * 创建弹幕手动匹配 ViewModel。
     *
     * @param initialQuery 初始搜索词。
     * @return 已接入弹幕服务搜索的匹配 ViewModel。
     */
    fun createDanmakuMatchViewModel(initialQuery: String): TvDanmakuMatchViewModel {
        return TvDanmakuMatchViewModel(
            initialQuery = initialQuery,
            searchEpisodes = { query ->
                // 弹幕服务未配置时保持 Flutter 同款不可用态，由 ViewModel 显示错误文案。
                danmakuRepository?.searchEpisodes(query)?.toFeatureResult()
            },
        )
    }

    /**
     * 保存弹幕手动匹配选择。
     *
     * @param playbackRequest 当前播放请求。
     * @param anime 当前选中的动画候选。
     * @param selectedEpisode 当前选中的弹幕剧集。
     * @param selectedEpisodeOffset 选中剧集在候选列表中的下标。
     * @param searchKeyword 当前搜索词。
     */
    suspend fun saveDanmakuManualSelection(
        playbackRequest: PlaybackRequest,
        anime: TvDanmakuSearchAnime,
        selectedEpisode: TvDanmakuSearchEpisode,
        selectedEpisodeOffset: Int,
        searchKeyword: String,
    ) {
        danmakuManualMatchRepository.saveManualSelection(
            source = playbackRequest.sourceId,
            videoId = playbackRequest.videoId,
            episodeIndex = playbackRequest.episodeIndex,
            selectedDanmakuEpisodeId = selectedEpisode.episodeId,
            searchKeyword = searchKeyword,
            fallbackTitle = playbackRequest.videoTitle,
            orderedEpisodes = anime.episodes.map { episode -> episode.toDataEpisode() },
            selectedEpisodeOffset = selectedEpisodeOffset,
        )
    }

    /**
     * 加载当前播放请求对应的弹幕评论。
     *
     * @param playbackRequest 当前播放请求。
     * @return 播放器可消费的弹幕加载结果，未配置或未匹配时返回空。
     */
    private suspend fun loadDanmakuForPlayback(
        playbackRequest: PlaybackRequest,
    ): TvPlayerDanmakuLoadResult? {
        val repository = danmakuRepository ?: return null
        val manualMatch = danmakuManualMatchRepository.getManualMatch(
            source = playbackRequest.sourceId,
            videoId = playbackRequest.videoId,
            episodeIndex = playbackRequest.episodeIndex,
        ) ?: return null
        if (manualMatch.episodeId <= 0) {
            return null
        }
        return repository.loadDanmakuByEpisodeId(manualMatch.episodeId)
            .toPlayerDanmakuResult()
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
            playbackRepository = TvPlaybackRepository(api = requireGatewayClient().tvApi),
            doubanRepository = doubanRepository,
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
 * 判断详情是否已经包含可播放线路。
 *
 * @return 至少存在一个有剧集的来源时返回 true。
 */
private fun TvVideoDetail?.hasPlayableSource(): Boolean {
    return this?.sources?.any { source -> source.episodes.isNotEmpty() } == true
}

/**
 * 转换弹幕搜索业务结果为设置功能模块模型。
 *
 * @return 弹幕搜索 UI 结果。
 */
private fun TvDanmakuSearchPayload.toFeatureResult(): TvDanmakuSearchResult {
    return TvDanmakuSearchResult(
        success = success,
        errorMessage = errorMessage,
        animes = animes.map { anime -> anime.toFeatureAnime() },
    )
}

/**
 * 转换弹幕动画候选为设置功能模块模型。
 *
 * @return 弹幕动画候选 UI 模型。
 */
private fun TvDanmakuAnimePayload.toFeatureAnime(): TvDanmakuSearchAnime {
    return TvDanmakuSearchAnime(
        animeId = animeId,
        animeTitle = animeTitle,
        type = type,
        typeDescription = typeDescription,
        year = year,
        episodes = episodes.map { episode -> episode.toFeatureEpisode() },
    )
}

/**
 * 转换弹幕剧集候选为设置功能模块模型。
 *
 * @return 弹幕剧集候选 UI 模型。
 */
private fun TvDanmakuEpisodePayload.toFeatureEpisode(): TvDanmakuSearchEpisode {
    return TvDanmakuSearchEpisode(
        episodeId = episodeId,
        episodeTitle = episodeTitle,
    )
}

/**
 * 转换设置功能模块剧集候选为数据层模型。
 *
 * @return 弹幕剧集候选业务模型。
 */
private fun TvDanmakuSearchEpisode.toDataEpisode(): TvDanmakuEpisodePayload {
    return TvDanmakuEpisodePayload(
        episodeId = episodeId,
        episodeTitle = episodeTitle,
    )
}

/**
 * 转换数据层弹幕加载结果为播放器状态模型。
 *
 * @return 播放器弹幕加载结果。
 */
private fun TvDanmakuLoadPayload.toPlayerDanmakuResult(): TvPlayerDanmakuLoadResult {
    return TvPlayerDanmakuLoadResult(
        episodeId = episodeId,
        comments = comments.map { comment -> comment.toPlayerDanmakuComment() },
    )
}

/**
 * 转换数据层弹幕评论为播放器状态模型。
 *
 * @return 播放器弹幕评论。
 */
private fun TvDanmakuCommentPayload.toPlayerDanmakuComment(): TvPlayerDanmakuComment {
    return TvPlayerDanmakuComment(
        cid = cid,
        p = p,
        text = text,
        timestamp = timestamp,
        timeSeconds = timeSeconds,
        type = type,
        color = color,
    )
}
