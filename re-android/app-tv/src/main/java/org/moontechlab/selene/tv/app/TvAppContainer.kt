package org.moontechlab.selene.tv.app

import android.content.Context
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.util.logging.Logger
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
import org.moontechlab.selene.tv.core.data.repository.BangumiRepository
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
import org.moontechlab.selene.tv.core.network.DoubanSubjectHtmlSource
import org.moontechlab.selene.tv.core.network.SeleneDanmakuApi
import org.moontechlab.selene.tv.core.network.SeleneBangumiApi
import org.moontechlab.selene.tv.core.network.SeleneDoubanApi
import org.moontechlab.selene.tv.core.network.SeleneTvGatewayClient
import org.moontechlab.selene.tv.core.network.SeleneTvNetworkFactory
import org.moontechlab.selene.tv.core.network.SeleneTvSearchStreamClient
import org.moontechlab.selene.tv.core.network.SeleneTvSseSearchClient
import org.moontechlab.selene.tv.core.network.SessionCookieStore
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.core.player.api.PlayerEngine
import org.moontechlab.selene.tv.core.player.webview.WebViewPlayerEngine
import org.moontechlab.selene.tv.core.player.webview.WebViewPlayerSession
import org.moontechlab.selene.tv.core.player.exo.ExoPlayerEngine
import org.moontechlab.selene.tv.core.player.exo.ExoPlayerFactory
import org.moontechlab.selene.tv.feature.favorites.TvFavoritesViewModel
import org.moontechlab.selene.tv.feature.detail.TvDetailEntry
import org.moontechlab.selene.tv.feature.detail.TvDetailRecommendDiagnostic
import org.moontechlab.selene.tv.feature.detail.TvDetailRecommendDiagnosticSink
import org.moontechlab.selene.tv.feature.detail.TvDetailRecommendDiagnosticStage
import org.moontechlab.selene.tv.feature.detail.TvDetailResumeRecord
import org.moontechlab.selene.tv.feature.detail.TvDetailViewModel
import org.moontechlab.selene.tv.feature.history.TvHistoryViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.moontechlab.selene.tv.feature.detail.TvDetailSourcesResult
import org.moontechlab.selene.tv.feature.home.TvHomeSectionProgress
import org.moontechlab.selene.tv.feature.home.TvHomeViewModel
import org.moontechlab.selene.tv.feature.home.TvVideoLibraryUiState
import org.moontechlab.selene.tv.feature.home.TvVideoLibraryViewModel
import org.moontechlab.selene.tv.feature.player.TvPlayerViewModel
import org.moontechlab.selene.tv.feature.player.TvPlayerDanmakuComment
import org.moontechlab.selene.tv.feature.player.TvPlayerDanmakuLoadResult
import org.moontechlab.selene.tv.feature.search.TvSearchBootstrapData
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
 * 按详情入口保存精确详情，避免异步回包跨页面串用豆瓣身份。
 */
internal class TvDetailExactDetailStore {
    /** 以规范化 `source::videoId` 为键的精确详情。 */
    private val detailsByEntry = ConcurrentHashMap<String, TvVideoDetail>()

    /** 为全部精确详情请求生成单调递增版本。 */
    private val requestVersion = AtomicLong(0L)

    /** 每个详情入口当前允许完成写入的最新请求版本。 */
    private val currentVersionByEntry = ConcurrentHashMap<String, Long>()

    /**
     * 开始指定入口的新精确详情请求。
     *
     * @param entry 详情入口。
     * @return 当前请求的唯一版本 token。
     */
    fun beginRequest(entry: TvDetailEntry): Long {
        val entryKey = entry.detailEntryKey()
        val token = requestVersion.incrementAndGet()
        currentVersionByEntry[entryKey] = token
        return token
    }

    /**
     * 完成指定入口的精确详情请求。
     *
     * 只有 token 仍是该入口最新版本时才允许更新缓存，避免旧请求晚到覆盖新结果。
     *
     * @param entry 详情入口。
     * @param token [beginRequest] 返回的请求版本。
     * @param detail 最新精确详情；为空时删除同入口旧值。
     */
    fun completeRequest(
        entry: TvDetailEntry,
        token: Long,
        detail: TvVideoDetail?,
    ) {
        val entryKey = entry.detailEntryKey()
        currentVersionByEntry.compute(entryKey) { _, currentToken ->
            if (currentToken != token) {
                // 同入口已有更新请求时，旧请求结果无论空或非空都必须忽略。
                return@compute currentToken
            }
            if (detail == null) {
                // 同入口最新请求返回空详情时删除旧身份，不能继续复用过期豆瓣 ID。
                detailsByEntry.remove(entryKey)
            } else {
                detailsByEntry[entryKey] = detail
            }
            currentToken
        }
    }

    /**
     * 读取指定入口的精确详情。
     *
     * @param entry 当前详情入口。
     * @return 仅当前入口键对应的精确详情。
     */
    fun find(entry: TvDetailEntry): TvVideoDetail? {
        return detailsByEntry[entry.detailEntryKey()]
    }
}

/**
 * 按业务优先级解析详情推荐使用的豆瓣 ID。
 *
 * @param entry 当前详情入口。
 * @param latestDetail ViewModel 当前最新详情。
 * @param exactDetail 当前入口键对应的精确详情。
 * @param resolveByTitle 标题和年份兜底解析器。
 * @return 有效豆瓣 ID；全部候选无效时返回空。
 */
internal suspend fun resolveTvDetailRecommendDoubanId(
    entry: TvDetailEntry,
    latestDetail: TvVideoDetail?,
    exactDetail: TvVideoDetail?,
    resolveByTitle: suspend (TvVideoDetail?) -> String,
): String? {
    latestDetail?.doubanId.validDoubanIdOrNull()?.let { return it }
    exactDetail?.doubanId.validDoubanIdOrNull()?.let { return it }

    if (entry.source.trim().equals("douban", ignoreCase = true)) {
        // 豆瓣资料入口的视频 ID 本身就是 subject ID，但空值和 0 仍必须拒绝。
        entry.videoId.validDoubanIdOrNull()?.let { return it }
    }

    val lookupDetail = latestDetail.mergeRecommendLookupMetadata(exactDetail)
        ?.copy(doubanId = "")
    return resolveByTitle(lookupDetail).validDoubanIdOrNull()
}

/**
 * 合并推荐身份解析需要的详情元数据。
 *
 * @param exactDetail 当前入口的精确详情。
 * @return 优先保留最新详情字段、缺失时使用精确详情补齐的查询详情。
 */
private fun TvVideoDetail?.mergeRecommendLookupMetadata(exactDetail: TvVideoDetail?): TvVideoDetail? {
    val latestDetail = this ?: return exactDetail
    val fallbackDetail = exactDetail ?: return latestDetail
    return latestDetail.copy(
        title = latestDetail.title.ifBlank { fallbackDetail.title },
        description = latestDetail.description.ifBlank { fallbackDetail.description },
        posterUrl = latestDetail.posterUrl.ifBlank { fallbackDetail.posterUrl },
        year = latestDetail.year.ifBlank { fallbackDetail.year },
        typeName = latestDetail.typeName.ifBlank { fallbackDetail.typeName },
        categories = if (latestDetail.categories.size >= fallbackDetail.categories.size) {
            latestDetail.categories.ifEmpty { fallbackDetail.categories }
        } else {
            fallbackDetail.categories
        },
        remarks = latestDetail.remarks.ifBlank { fallbackDetail.remarks },
        qualityTag = latestDetail.qualityTag.ifBlank { fallbackDetail.qualityTag },
        rating = latestDetail.rating.ifBlank { fallbackDetail.rating },
        sourceName = latestDetail.sourceName.ifBlank { fallbackDetail.sourceName },
    )
}

/**
 * 构造详情入口稳定键。
 *
 * @return 去除首尾空白后的 `source::videoId`。
 */
internal fun TvDetailEntry.detailEntryKey(): String {
    return "${source.trim()}::${videoId.trim()}"
}

/**
 * 规范化豆瓣 ID 并拒绝无效哨兵值。
 *
 * @return 有效豆瓣 ID；空值或 `0` 返回空。
 */
private fun String?.validDoubanIdOrNull(): String? {
    return this?.trim()?.takeIf { value -> value.isNotEmpty() && value != "0" }
}

/** 详情推荐生产诊断日志。 */
private val TV_DETAIL_RECOMMEND_LOGGER: Logger = Logger.getLogger("TvDetailRecommend")

/** 生产环境默认的低频推荐诊断接收器。 */
private val DEFAULT_TV_DETAIL_RECOMMEND_DIAGNOSTIC_SINK = TvDetailRecommendDiagnosticSink { event ->
    val safeMessage = event.message.toSafeRecommendDiagnosticMessage()
    TV_DETAIL_RECOMMEND_LOGGER.info(
        "stage=${event.stage.name} entry=${event.entryKey} " +
            "trigger=${event.trigger.ifBlank { "-" }} count=${event.count ?: -1} message=$safeMessage",
    )
}

/**
 * 过滤推荐诊断中的 HTML 和常见敏感字段，并限制日志长度。
 *
 * @return 可安全写入低频诊断日志的单行消息。
 */
private fun String?.toSafeRecommendDiagnosticMessage(): String {
    val message = this.orEmpty().trim()
    if (message.isEmpty()) {
        return "-"
    }
    val sensitiveMarkers = listOf("<html", "cookie", "authorization", "password", "token")
    if (sensitiveMarkers.any { marker -> message.contains(marker, ignoreCase = true) }) {
        // 响应正文和鉴权信息统一省略，避免诊断链路泄露隐私数据。
        return "[已省略敏感内容]"
    }
    return message.replace(Regex("""\s+"""), " ").take(MAX_RECOMMEND_DIAGNOSTIC_MESSAGE_LENGTH)
}

/** 推荐诊断消息最大字符数。 */
private const val MAX_RECOMMEND_DIAGNOSTIC_MESSAGE_LENGTH = 160

/**
 * TV 应用依赖容器。
 *
 * @property gatewayConfig 本地后台网关配置。
 * @property appContext 应用级上下文，用于偏好持久化和播放器等长生命周期能力。
 * @property sessionCookieStore 会话存储。
 * @property preferencesStore TV 偏好存储。
 * @property gatewayClientFactory 后台客户端工厂。
 * @property searchStreamClientFactory 后台 SSE 搜索客户端工厂。
 * @property danmakuApiFactory 弹幕服务接口工厂。
 * @property playerEngineFactory 播放器内核工厂。
 * @property playerKernelResolver 运行时真实内核解析器。
 * @property doubanApiFactory 豆瓣分类 API 工厂。
 * @property bangumiApiFactory Bangumi 日历 API 工厂。
 * @property doubanHtmlSourceFactory 豆瓣详情 HTML 数据源工厂。
 * @property recommendDiagnosticSink 详情推荐诊断接收器。
 */
class TvAppContainer(
    private val gatewayConfig: TvLocalGatewayConfig,
    private val appContext: Context? = null,
    private val sessionCookieStore: SessionCookieStore = SessionCookieStore(),
    private val preferencesStore: TvPreferencesStore = TvPreferencesStore(appContext),
    private val gatewayClientFactory: (String, SessionCookieStore) -> SeleneTvGatewayClient = { baseUrl, store ->
        SeleneTvNetworkFactory.create(
            rawBaseUrl = baseUrl,
            sessionCookieStore = store,
        )
    },
    private val searchStreamClientFactory: (String, SessionCookieStore) -> SeleneTvSearchStreamClient = { baseUrl, store ->
        SeleneTvSseSearchClient(
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
    private val playerKernelResolver: RuntimePlayerKernelResolver = RuntimePlayerKernelResolver(),
    private val doubanApiFactory: () -> SeleneDoubanApi = {
        SeleneTvNetworkFactory.createDoubanApi()
    },
    private val bangumiApiFactory: () -> SeleneBangumiApi = {
        SeleneTvNetworkFactory.createBangumiApi()
    },
    private val doubanHtmlSourceFactory: () -> DoubanSubjectHtmlSource = {
        SeleneTvNetworkFactory.createDoubanHtmlApi()
    },
    private val recommendDiagnosticSink: TvDetailRecommendDiagnosticSink = DEFAULT_TV_DETAIL_RECOMMEND_DIAGNOSTIC_SINK,
) {
    /** 后台客户端按需创建，避免缺配置时启动阶段直接抛错。 */
    private val gatewayClient: SeleneTvGatewayClient? by lazy {
        if (gatewayConfig.isComplete) {
            gatewayClientFactory(gatewayConfig.baseUrl, sessionCookieStore)
        } else {
            null
        }
    }

    /** 标题补源 SSE 客户端，详情页用于边搜边追加线路。 */
    private val searchStreamClient: SeleneTvSearchStreamClient? by lazy {
        if (gatewayConfig.isComplete) {
            searchStreamClientFactory(gatewayConfig.baseUrl, sessionCookieStore)
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

    /** 应用级 IO 任务作用域。 */
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /**
     * 播放进度已写入远端、首页“继续观看”尚未刷新。
     *
     * 详情/全屏任意路径保存成功后置位；首页 ON_RESUME 消费后局部刷新续播块。
     */
    private val continueWatchingDirty = AtomicBoolean(false)

    /** 豆瓣代理 API 接口。 */
    private val doubanApi by lazy {
        doubanApiFactory()
    }

    /** 豆瓣详情页 HTML 抓取接口。 */
    private val doubanHtmlSource by lazy {
        doubanHtmlSourceFactory()
    }

    /** 豆瓣分类数据仓库。 */
    internal val doubanRepository: DoubanRepository by lazy {
        DoubanRepository(api = doubanApi, htmlSource = doubanHtmlSource)
    }

    /** Bangumi 日历 API 接口。 */
    private val bangumiApi by lazy {
        bangumiApiFactory()
    }

    /** Bangumi 新番放送仓库。 */
    internal val bangumiRepository: BangumiRepository by lazy {
        BangumiRepository(api = bangumiApi)
    }

    /**
     * 清除豆瓣仓库内存缓存。
     */
    fun clearDoubanCache() {
        doubanRepository.clearCache()
        bangumiRepository.clearCache()
    }

    /**
     * 创建首页 ViewModel。
     *
     * @return 首页 ViewModel。
     */
    fun createHomeViewModel(): TvHomeViewModel {
        return TvHomeViewModel(
            loadHome = ::loadHome,
            loadContinueWatching = ::loadContinueWatching,
            // 分区流式回填：哪个接口先返回就先展示哪块。
            observeHome = ::observeHome,
        )
    }

    /**
     * 创建搜索 ViewModel。
     *
     * @return 搜索 ViewModel。
     */
    fun createSearchViewModel(): TvSearchViewModel {
        return TvSearchViewModel(
            loadBootstrap = {
                ensureSession()
                val repository = TvSearchRepository(requireGatewayClient().tvApi)
                val history = runCatching { repository.readSearchHistory() }.getOrDefault(emptyList())
                // 搜索页推荐优先复用豆瓣热门分类，对齐 Flutter 首页缓存兜底语义。
                val recommends = runCatching {
                    doubanRepository.loadCategory(
                        DoubanCategoryParams(
                            kind = "tv",
                            category = "热门",
                            type = "tv",
                        ),
                    )
                }.getOrDefault(emptyList())
                TvSearchBootstrapData(
                    searchHistory = history,
                    // Flutter 当前热词暂为空，Kotlin 先提供稳定兜底词方便遥控操作。
                    hotQueries = listOf("热门电影", "高分剧集", "动漫新番", "综艺更新"),
                    recommendCards = recommends.take(20),
                )
            },
            loadSuggestions = { query ->
                // 后端暂无首字母联想接口时，先用历史 + 热词本地过滤，保证交互链路完整。
                val currentHistory = runCatching {
                    ensureSession()
                    TvSearchRepository(requireGatewayClient().tvApi).readSearchHistory()
                }.getOrDefault(emptyList())
                val seeds = currentHistory + listOf(
                    "热门电影", "高分剧集", "动漫新番", "综艺更新",
                    "庆余年", "繁花", "三体", "漫长的季节", "狂飙",
                )
                seeds.filter { word ->
                    word.replace(" ", "").contains(query, ignoreCase = true) ||
                        pinyinInitialsMatch(word, query)
                }.distinct().take(18)
            },
            searchStream = searchStreamClient,
            batchSearch = { query ->
                ensureSession()
                TvSearchRepository(requireGatewayClient().tvApi).search(query).results
            },
            clearSearchHistory = {
                // 远端暂无清空接口时，本地清空 UI 历史即可。
                true
            },
            saveSearchHistory = {
                // 历史写入依赖后端接口，当前先保留 UI 内状态。
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
        val exactDetailStore = TvDetailExactDetailStore()
        return TvDetailViewModel(
            initialEntry = initialEntry,
            playerEngine = playerEngine,
            recommendDiagnosticSink = recommendDiagnosticSink,
            loadExactSources = { entry ->
                val requestToken = exactDetailStore.beginRequest(entry)
                ensureSession()
                val repo = TvDetailRepository(requireGatewayClient().tvApi)
                // 精确详情即使没有剧集，也能提供标题、年份、简介和封面。
                val exactDetail = repo.loadDetail(source = entry.source, id = entry.videoId)
                exactDetailStore.completeRequest(entry, requestToken, exactDetail)
                TvDetailSourcesResult(
                    sources = exactDetail?.sources
                        .orEmpty()
                        .filter { videoSource -> videoSource.episodes.isNotEmpty() },
                    detail = exactDetail,
                )
            },
            loadMoreSources = { entry, onIncremental ->
                ensureSession()
                val fallbackDetail = exactDetailStore.find(entry)
                val fallbackTitle = entry.resolvedSearchTitle
                    .ifBlank { fallbackDetail?.title.orEmpty() }
                    .ifBlank { entry.videoId }
                val repo = TvDetailRepository(
                    api = requireGatewayClient().tvApi,
                    searchStreamClient = searchStreamClient,
                )
                val sources = repo.loadMoreSourcesByEntry(
                    title = fallbackTitle,
                    searchTitle = fallbackTitle,
                    year = entry.year.ifBlank { fallbackDetail?.year.orEmpty() },
                    onIncremental = onIncremental,
                )
                // 精确详情缺简介时，用标题搜索结果回填 desc，避免右侧一直“暂无简介”。
                val metadata = if (fallbackDetail?.description.isNullOrBlank()) {
                    runCatching {
                        repo.loadDetailBySearchTitle(
                            title = fallbackTitle,
                            fallbackId = entry.videoId,
                            year = entry.year.ifBlank { fallbackDetail?.year.orEmpty() },
                            posterUrl = entry.posterUrl.ifBlank { fallbackDetail?.posterUrl.orEmpty() },
                        )
                    }.getOrNull()
                } else {
                    fallbackDetail
                }
                TvDetailSourcesResult(
                    sources = sources,
                    detail = metadata ?: fallbackDetail,
                )
            },
            loadFavoriteState = { entry ->
                ensureSession()
                TvFavoritesRepository(requireGatewayClient().tvApi)
                    .isFavorite(source = entry.source, videoId = entry.videoId)
            },
            saveFavoriteState = { entry, detail, favorited ->
                if (entry != null && entry.videoId.isNotBlank()) {
                    ensureSession()
                    val repo = TvFavoritesRepository(requireGatewayClient().tvApi)
                    if (favorited) {
                        val currentSource = detail?.sources
                            ?.firstOrNull { source -> source.source == entry.source }
                            ?: detail?.sources?.firstOrNull()
                        repo.saveFavorite(
                            source = entry.source.ifBlank { currentSource?.source.orEmpty() },
                            videoId = entry.videoId,
                            title = detail?.title.orEmpty()
                                .ifBlank { entry.title }
                                .ifBlank { entry.videoId },
                            sourceName = currentSource?.name
                                .orEmpty()
                                .ifBlank { detail?.sourceName.orEmpty() },
                            year = detail?.year.orEmpty().ifBlank { entry.year },
                            cover = detail?.posterUrl.orEmpty().ifBlank { entry.posterUrl },
                            totalEpisodes = currentSource?.episodes?.size
                                ?: detail?.sources?.maxOfOrNull { source -> source.episodes.size }
                                ?: 0,
                            origin = "detail",
                        )
                    } else {
                        repo.deleteFavorite(
                            source = entry.source,
                            videoId = entry.videoId,
                        )
                    }
                }
            },
            loadResumeRecord = { entry ->
                val record = resolveResumeRecord(
                    entry = entry,
                    cards = loadContinueWatching(),
                )
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
            savePlaybackProgress = { request, positionMs, durationMs ->
                ioScope.launch {
                    persistPlaybackProgress(
                        request = request,
                        positionMs = positionMs,
                        durationMs = durationMs,
                    )
                }
            },
            loadRecommends = { entry, detail ->
                val exactDetail = exactDetailStore.find(entry)
                val resolvedDoubanId = resolveTvDetailRecommendDoubanId(
                    entry = entry,
                    latestDetail = detail,
                    exactDetail = exactDetail,
                    resolveByTitle = { lookupDetail ->
                        ensureSession()
                        TvDetailRepository(requireGatewayClient().tvApi).resolveDoubanId(
                            detail = lookupDetail,
                            entrySource = "",
                            entryVideoId = "",
                            title = lookupDetail?.title.orEmpty().ifBlank { entry.title },
                            searchTitle = entry.resolvedSearchTitle,
                            year = lookupDetail?.year.orEmpty().ifBlank { entry.year },
                        )
                    },
                )
                if (resolvedDoubanId == null) {
                    // 身份解析在 App 层完成，缺失事件也由同一层记录，避免 ViewModel 猜测业务 ID。
                    runCatching {
                        recommendDiagnosticSink.record(
                            TvDetailRecommendDiagnostic(
                                stage = TvDetailRecommendDiagnosticStage.MissingDoubanId,
                                entryKey = entry.detailEntryKey(),
                                trigger = "identity-resolution",
                            ),
                        )
                    }
                    emptyList()
                } else {
                    doubanRepository.loadDetailRecommends(resolvedDoubanId)
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
            savePlaybackProgress = { request, positionMs, durationMs ->
                ioScope.launch {
                    persistPlaybackProgress(
                        request = request,
                        positionMs = positionMs,
                        durationMs = durationMs,
                    )
                }
            },
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
     * 创建 ExoPlayer 播放内核。
     *
     * @param context Android 上下文。
     * @return ExoPlayer 内核引擎。
     */
    fun createExoPlayerEngine(context: Context): PlayerEngine {
        val adapter = ExoPlayerFactory.create(context)
        return ExoPlayerEngine(
            player = adapter,
            dispatchers = AppDispatchers.createDefault(),
        )
    }

    /**
     * 解析当前播放器偏好对应的真实运行内核。
     *
     * @param preferredKernel 用户保存的内核偏好。
     * @return 当前环境下的真实运行内核决策。
     */
    internal fun resolvePlayerKernelDecision(preferredKernel: String): RuntimePlayerKernelDecision {
        return playerKernelResolver.resolve(preferredKernel)
    }

    /**
     * 读取当前播放内核设置的真实运行决策。
     *
     * @return 当前环境下的真实播放内核决策。
     */
    internal suspend fun getPlayerKernelDecision(): RuntimePlayerKernelDecision {
        return resolvePlayerKernelDecision(preferencesStore.getPlayerKernel())
    }

    /**
     * 读取当前播放内核设置的同步决策快照。
     *
     * @return 当前环境下的真实播放内核决策。
     */
    internal fun peekPlayerKernelDecision(): RuntimePlayerKernelDecision {
        return resolvePlayerKernelDecision(preferencesStore.peekPlayerKernel())
    }

    /**
     * 读取当前播放内核设置。
     *
     * @return 播放内核标识（exo 或 webview）。
     */
    suspend fun getPlayerKernel(): String {
        return getPlayerKernelDecision().effectiveKernel
    }

    /**
     * 读取当前播放内核设置的同步快照。
     *
     * 导航图首次组合时需要先拿到一个稳定默认值，
     * 这里直接返回真实生效内核，避免高风险环境短暂误走 WebView 黑屏链路。
     *
     * @return 当前播放内核标识（exo 或 webview）。
     */
    fun peekPlayerKernel(): String {
        return peekPlayerKernelDecision().effectiveKernel
    }

    /**
     * 读取详情等页面进入时使用的背景色同步快照。
     *
     * @return 设置页当前保存的背景色标识。
     */
    fun peekBackgroundKey(): String {
        return preferencesStore.peekBackgroundKey()
    }

    /**
     * 保存播放器内核偏好，并返回当前环境下真实会生效的内核。
     *
     * @param kernel 用户选择的内核标识。
     * @return 当前环境下真实生效的内核。
     */
    suspend fun savePlayerKernel(kernel: String): String {
        preferencesStore.savePlayerKernel(kernel)
        return resolvePlayerKernelDecision(kernel).effectiveKernel
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
                // 对齐 Flutter：每日放送走 Bangumi calendar，并按“星期”筛选。
                // 分页只在第一页返回，避免重复拼接同一天数据。
                if (page > 0) {
                    emptyList()
                } else {
                    val weekday = sel["星期"]?.toIntOrNull()
                        ?: java.util.Calendar.getInstance().let { calendar ->
                            when (calendar.get(java.util.Calendar.DAY_OF_WEEK)) {
                                java.util.Calendar.MONDAY -> 1
                                java.util.Calendar.TUESDAY -> 2
                                java.util.Calendar.WEDNESDAY -> 3
                                java.util.Calendar.THURSDAY -> 4
                                java.util.Calendar.FRIDAY -> 5
                                java.util.Calendar.SATURDAY -> 6
                                else -> 7
                            }
                        }
                    bangumiRepository.loadCalendarByWeekday(weekday)
                }
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
        val currentPlayerKernel = peekPlayerKernel()
        val currentBackgroundKey = peekBackgroundKey()
        return TvSettingsViewModel(
            initialState = TvSettingsUiState(
                serverUrl = gatewayConfig.baseUrl,
                account = gatewayConfig.username,
                password = gatewayConfig.password,
                danmakuApi = gatewayConfig.danmakuBaseUrl,
                // 设置页首屏展示必须与当前真实播放内核一致，避免界面显示 Exo、实际仍走 WebView。
                playerKernelKey = currentPlayerKernel,
                // 设置页重新进入时保留当前背景选项，与详情页使用同一份配置。
                backgroundKey = currentBackgroundKey,
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
                savePlayerKernel(kernel)
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
        return createHomeRepository().loadHome()
    }

    /**
     * 单独读取继续观看列表。
     *
     * @return 最新播放历史卡片列表。
     */
    private suspend fun loadContinueWatching(): List<TvVideoCard> {
        ensureSession()
        return TvPlaybackRepository(api = requireGatewayClient().tvApi).readContinueWatching()
    }

    /**
     * 立即持久化当前播放进度。
     *
     * @param request 当前播放请求。
     * @param positionMs 当前播放位置，单位毫秒。
     * @param durationMs 当前总时长，单位毫秒。
     */
    suspend fun persistPlaybackProgress(
        request: PlaybackRequest?,
        positionMs: Long,
        durationMs: Long,
    ) {
        val safeRequest = request ?: return
        // 0 进度不写库，避免误覆盖已有续播。
        if (positionMs <= 0L) {
            return
        }
        runCatching {
            ensureSession()
            TvPlaybackRepository(api = requireGatewayClient().tvApi)
                .savePlayRecord(
                    safeRequest.toPlayRecordCard(
                        positionMs = positionMs,
                        durationMs = durationMs,
                    ),
                )
        }.onSuccess {
            // 写库成功后标记首页续播脏，返回首页时局部刷新，而不是整页重载。
            continueWatchingDirty.set(true)
        }.onFailure {
            // 进度保存失败不阻塞详情/播放器返回，后续 10 秒轮询会继续兜底补写。
        }
    }

    /**
     * 首页恢复时消费“继续观看需刷新”标记。
     *
     * @return true 表示本次应刷新续播分区。
     */
    fun consumeContinueWatchingDirty(): Boolean {
        return continueWatchingDirty.getAndSet(false)
    }

    /**
     * 仅查询是否有未刷新的续播写库（不消费）。
     */
    fun isContinueWatchingDirty(): Boolean {
        return continueWatchingDirty.get()
    }

    /**
     * 在应用级 IO 作用域后台保存播放进度。
     *
     * @param request 当前播放请求。
     * @param positionMs 当前播放位置，单位毫秒。
     * @param durationMs 当前总时长，单位毫秒。
     * @param onFinished 保存流程结束后的主线程回调。
     */
    fun persistPlaybackProgressAsync(
        request: PlaybackRequest?,
        positionMs: Long,
        durationMs: Long,
        onFinished: () -> Unit = {},
    ) {
        ioScope.launch {
            persistPlaybackProgress(
                request = request,
                positionMs = positionMs,
                durationMs = durationMs,
            )
            withContext(Dispatchers.Main.immediate) {
                onFinished()
            }
        }
    }

    /**
     * 观察首页分区流式加载进度。
     *
     * @return 分区先到先显示的进度流。
     */
    private fun observeHome(): Flow<TvHomeSectionProgress> {
        return flow {
            // 流式订阅前先确保会话，避免首包失败。
            ensureSession()
            createHomeRepository().observeHome().collect { progress ->
                emit(
                    TvHomeSectionProgress(
                        sections = progress.payload.sections,
                        readyKeys = progress.payload.sections.map { section -> section.key }.toSet(),
                        isComplete = progress.isComplete,
                    ),
                )
            }
        }
    }

    /**
     * 创建首页仓库。
     *
     * @return 首页数据仓库。
     */
    private fun createHomeRepository(): TvHomeRepository {
        return TvHomeRepository(
            playbackRepository = TvPlaybackRepository(api = requireGatewayClient().tvApi),
            doubanRepository = doubanRepository,
            bangumiRepository = bangumiRepository,
        )
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
 * 按详情入口解析当前最可信的续播记录。
 *
 * 兼容 Flutter TV 语义：精确 `source+id` 优先，其次允许资料源入口按标题回源命中最新记录。
 *
 * @param entry 当前详情入口。
 * @param cards 已按保存时间倒序的播放记录列表。
 * @return 最适合当前详情入口的续播记录。
 */
private fun resolveResumeRecord(
    entry: TvDetailEntry,
    cards: List<TvVideoCard>,
): TvVideoCard? {
    cards.firstOrNull { card ->
        card.source == entry.source && card.id == entry.videoId
    }?.let { return it }

    val entryTitleKeys = buildSet {
        add(entry.title.resumeMatchKey())
        add(entry.searchTitle.resumeMatchKey())
        add(entry.resolvedSearchTitle.resumeMatchKey())
    }.filter { key -> key.isNotBlank() }
    val entryYear = entry.year.trim()
    fun TvVideoCard.matchesEntryTitle(): Boolean {
        val cardTitleKey = title.resumeMatchKey()
        val cardSearchTitleKey = searchTitle.resumeMatchKey()
        return entryTitleKeys.any { key ->
            key == cardTitleKey || key == cardSearchTitleKey
        }
    }

    if (entry.videoId.isNotBlank()) {
        cards.firstOrNull { card ->
            card.id == entry.videoId && card.matchesEntryTitle() && card.matchesEntryYear(entryYear)
        }?.let { return it }
    }

    if (entry.source.isMetadataOnlySource()) {
        cards.firstOrNull { card ->
            card.matchesEntryTitle() && card.matchesEntryYear(entryYear)
        }?.let { return it }
    }

    cards.firstOrNull { card ->
        card.id == entry.videoId
    }?.let { return it }

    return null
}

/**
 * 将播放请求转换成可直接保存的播放历史卡片。
 *
 * @param positionMs 当前播放位置，单位毫秒。
 * @param durationMs 当前总时长，单位毫秒。
 * @return Flutter `/api/playrecords` 兼容卡片模型。
 */
private fun PlaybackRequest.toPlayRecordCard(
    positionMs: Long,
    durationMs: Long,
): TvVideoCard {
    val safePositionSeconds = positionMs
        .coerceAtLeast(0L)
        .div(1_000L)
        .coerceAtMost(Int.MAX_VALUE.toLong())
        .toInt()
    val safeDurationSeconds = durationMs
        .coerceAtLeast(positionMs.coerceAtLeast(0L) + 1_000L)
        .div(1_000L)
        .coerceAtMost(Int.MAX_VALUE.toLong())
        .toInt()
    return TvVideoCard(
        id = videoId,
        source = sourceId,
        title = videoTitle,
        sourceName = sourceName,
        year = videoYear,
        posterUrl = posterUrl,
        totalEpisodes = totalEpisodes.coerceAtLeast(0),
        episodeIndex = (episodeIndex + 1).coerceAtLeast(1),
        playTime = safePositionSeconds,
        totalTime = safeDurationSeconds,
        saveTime = System.currentTimeMillis(),
        searchTitle = searchTitle.ifBlank { videoTitle },
    )
}

/**
 * 统一规范化续播标题匹配键。
 *
 * @return 去空白、小写后的比较键。
 */
private fun String.resumeMatchKey(): String {
    return replace(Regex("\\s+"), "").trim().lowercase()
}

/**
 * 判断详情入口来源是否属于资料源。
 *
 * @return 资料源或空来源时返回 true。
 */
private fun String.isMetadataOnlySource(): Boolean {
    val normalized = trim().lowercase()
    return normalized.isBlank() || normalized == "douban" || normalized == "bangumi"
}

/**
 * 判断播放记录年份是否兼容当前详情入口。
 *
 * @param entryYear 当前详情入口年份。
 * @return 任一侧缺失年份时放行；否则要求完全一致。
 */
private fun TvVideoCard.matchesEntryYear(entryYear: String): Boolean {
    val normalizedEntryYear = entryYear.trim().lowercase()
    val normalizedCardYear = year.trim().lowercase()
    return normalizedEntryYear.isBlank() ||
        normalizedCardYear.isBlank() ||
        normalizedEntryYear == normalizedCardYear
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

/**
 * 粗粒度首字母匹配：仅当候选词中文首字母序列包含 query 时命中。
 *
 * 这里不做完整拼音库，先提供可测的本地联想路径。
 *
 * @param word 候选词。
 * @param query 首字母查询。
 * @return 是否命中。
 */
private fun pinyinInitialsMatch(word: String, query: String): Boolean {
    if (query.isBlank()) {
        return false
    }
    // 无拼音库时退化为包含判断，避免误伤英文种子词。
    return word.uppercase().startsWith(query.uppercase())
}
