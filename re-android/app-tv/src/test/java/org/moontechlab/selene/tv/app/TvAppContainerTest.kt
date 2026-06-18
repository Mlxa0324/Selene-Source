package org.moontechlab.selene.tv.app

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.data.storage.TvPreferencesStore
import org.moontechlab.selene.tv.core.network.SeleneTvApi
import org.moontechlab.selene.tv.core.network.SeleneDanmakuApi
import org.moontechlab.selene.tv.core.network.SeleneDoubanApi
import org.moontechlab.selene.tv.core.network.SeleneTvGatewayClient
import org.moontechlab.selene.tv.core.network.SessionPayload
import org.moontechlab.selene.tv.core.network.model.TvDanmakuCommentListResponse
import org.moontechlab.selene.tv.core.network.model.TvDanmakuCommentResponse
import org.moontechlab.selene.tv.core.network.model.TvDanmakuSearchAnimeResponse
import org.moontechlab.selene.tv.core.network.model.TvDanmakuSearchEpisodeResponse
import org.moontechlab.selene.tv.core.network.model.TvDanmakuSearchResponse
import org.moontechlab.selene.tv.core.network.model.TvFavoriteResponse
import org.moontechlab.selene.tv.core.network.model.TvHomeResponse
import org.moontechlab.selene.tv.core.network.model.TvHomeSectionResponse
import org.moontechlab.selene.tv.core.network.model.TvPlayRecordResponse
import org.moontechlab.selene.tv.core.network.model.TvSearchResourceResponse
import org.moontechlab.selene.tv.core.network.model.TvSearchResponse
import org.moontechlab.selene.tv.core.network.model.TvSearchResultResponse
import org.moontechlab.selene.tv.core.network.model.TvVideoCardResponse
import org.moontechlab.selene.tv.core.network.model.DoubanCategoryResponse
import org.moontechlab.selene.tv.core.network.model.DoubanMovieItem
import org.moontechlab.selene.tv.core.network.model.DoubanPic
import org.moontechlab.selene.tv.core.network.model.DoubanRating
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.core.player.api.PlaybackSnapshot
import org.moontechlab.selene.tv.core.player.api.PlayerEngine
import org.moontechlab.selene.tv.core.player.api.PlayerState
import org.moontechlab.selene.tv.core.player.api.TvResizeMode

/**
 * 校验 TV 应用容器的本地后台配置装配。
 */
class TvAppContainerTest {
    /**
     * 本地配置完整时设置页应直接展示地址、账号和密码。
     */
    @Test
    fun createSettingsViewModel_prefills_local_gateway_config() {
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(
                baseUrl = "http://127.0.0.1:3000",
                username = "demo",
                password = "secret",
                danmakuBaseUrl = "https://danmaku.example.com",
            ),
        )
        val viewModel = container.createSettingsViewModel()

        val state = viewModel.state.value
        assertThat(state.serverUrl).isEqualTo("http://127.0.0.1:3000")
        assertThat(state.account).isEqualTo("demo")
        assertThat(state.password).isEqualTo("secret")
        assertThat(state.danmakuApi).isEqualTo("https://danmaku.example.com")
    }

    /**
     * 缺少本地配置时首页应进入错误态。
     */
    @Test
    fun createHomeViewModel_reports_error_when_local_config_missing() = runTest {
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(
                baseUrl = "",
                username = "",
                password = "",
            ),
        )
        val viewModel = container.createHomeViewModel()

        viewModel.load()

        assertThat(viewModel.state.value.errorMessage)
            .contains("local.gateway.properties")
    }

    /**
     * 配置完整时首页应先登录再通过豆瓣仓库加载分区数据。
     */
    @Test
    fun createHomeViewModel_logs_in_and_loads_dashboard() = runTest {
        val fakeClient = FakeGatewayClient()
        val fakeDoubanApi = FakeHomeDoubanApi()
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(
                baseUrl = "http://127.0.0.1:3000",
                username = "demo",
                password = "secret",
            ),
            gatewayClientFactory = { _, _ -> fakeClient },
            doubanApiFactory = { fakeDoubanApi },
        )
        val viewModel = container.createHomeViewModel()

        viewModel.load()

        assertThat(fakeClient.loginCalls).isEqualTo(1)
        assertThat(viewModel.state.value.errorMessage).isNull()
        assertThat(
            viewModel.state.value.sections
                .first { section -> section.key == "hot_movies" }
                .videos
                .map { video -> video.title },
        ).containsExactly("热门 movie")
    }

    /**
     * 播放器 ViewModel 必须由容器注入内核并加载详情页传来的播放请求。
     */
    @Test
    fun createPlayerViewModel_loads_playback_request_with_injected_engine() = runTest {
        val engine = RecordingPlayerEngine()
        val request = PlaybackRequest(
            videoId = "movie-1",
            sourceId = "source-a",
            episodeId = "ep-1",
            url = "https://example.com/movie.m3u8",
            startPositionMs = 12_000L,
        )
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(
                baseUrl = "http://127.0.0.1:3000",
                username = "demo",
                password = "secret",
            ),
            playerEngineFactory = { engine },
        )
        val viewModel = container.createPlayerViewModel(request)

        viewModel.loadInitialRequest()

        assertThat(engine.loadedRequest).isEqualTo(request)
        assertThat(viewModel.state.value.playerErrorMessage).isEqualTo(null)
    }

    /**
     * 播放器 ViewModel 必须通过容器读写片头片尾跳过偏好。
     */
    @Test
    fun createPlayerViewModel_uses_skip_duration_preferences() = runTest {
        val preferencesStore = TvPreferencesStore()
        preferencesStore.saveSkipIntroSeconds(12)
        preferencesStore.saveSkipOutroSeconds(18)
        val engine = RecordingPlayerEngine()
        val request = PlaybackRequest(
            videoId = "movie-1",
            sourceId = "source-a",
            episodeId = "ep-1",
            url = "https://example.com/movie.m3u8",
            startPositionMs = 35_000L,
        )
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(
                baseUrl = "http://127.0.0.1:3000",
                username = "demo",
                password = "secret",
            ),
            preferencesStore = preferencesStore,
            playerEngineFactory = { engine },
        )
        val viewModel = container.createPlayerViewModel(request)

        viewModel.loadInitialRequest()
        viewModel.loadSkipDurations()
        viewModel.setSkipIntroToCurrentPosition()

        assertThat(viewModel.state.value.skipIntroSeconds).isEqualTo(35)
        assertThat(viewModel.state.value.skipOutroSeconds).isEqualTo(18)
        assertThat(preferencesStore.getSkipIntroSeconds()).isEqualTo(35)
    }

    /**
     * 详情页精确接口失败时，容器必须继续用标题补源，避免 Tab 卡片进入详情无数据。
     */
    @Test
    fun createDetailViewModel_falls_back_to_title_search_when_exact_detail_fails() = runTest {
        val detailCalls = mutableListOf<Pair<String, String>>()
        val queries = mutableListOf<String>()
        val fakeClient = FakeGatewayClient(
            detailHandler = { source, id ->
                detailCalls += source to id
                error("详情接口失败")
            },
            searchHandler = { query ->
                queries += query
                TvSearchResponse(
                    results = listOf(
                        TvSearchResultResponse(
                            id = "search-video-1",
                            title = "详情影片",
                            episodes = listOf("https://cdn.test/detail.m3u8"),
                            episodeTitles = listOf("正片"),
                            source = "source-b",
                            sourceName = "线路 B",
                            year = "2026",
                        ),
                    ),
                )
            },
        )
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(
                baseUrl = "http://127.0.0.1:3000",
                username = "demo",
                password = "secret",
            ),
            gatewayClientFactory = { _, _ -> fakeClient },
        )
        val viewModel = container.createDetailViewModel(
            source = "source-a",
            videoTitle = "详情影片",
        )

        viewModel.load(videoId = "video-1")

        val state = viewModel.state.value
        assertThat(detailCalls).containsExactly("source-a" to "video-1")
        assertThat(queries).contains("详情影片")
        assertThat(state.errorMessage).isNull()
        assertThat(state.detail?.title).isEqualTo("详情影片")
        assertThat(state.currentSourceId).isEqualTo("source-b::search-video-1")
        assertThat(state.currentEpisodeId).isNotEmpty()
        assertThat(state.playbackRequest?.url).isEqualTo("https://cdn.test/detail.m3u8")
    }

    /**
     * 详情接口返回空集数时，容器必须继续按标题补源，避免详情页停在无选集状态。
     */
    @Test
    fun createDetailViewModel_falls_back_to_title_search_when_exact_detail_has_no_episodes() = runTest {
        val detailCalls = mutableListOf<Pair<String, String>>()
        val queries = mutableListOf<String>()
        val fakeClient = FakeGatewayClient(
            detailHandler = { source, id ->
                detailCalls += source to id
                TvSearchResultResponse(
                    id = id,
                    title = "空线路影片",
                    episodes = emptyList(),
                    source = source,
                    sourceName = "线路 A",
                    year = "2026",
                    poster = "https://img.test/exact.jpg",
                )
            },
            searchHandler = { query ->
                queries += query
                TvSearchResponse(
                    results = listOf(
                        TvSearchResultResponse(
                            id = "search-video-2",
                            title = "空线路影片",
                            episodes = listOf("https://cdn.test/fallback.m3u8"),
                            episodeTitles = listOf("正片"),
                            source = "source-c",
                            sourceName = "线路 C",
                            year = "2026",
                        ),
                    ),
                )
            },
        )
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(
                baseUrl = "http://127.0.0.1:3000",
                username = "demo",
                password = "secret",
            ),
            gatewayClientFactory = { _, _ -> fakeClient },
        )
        val viewModel = container.createDetailViewModel(source = "source-a")

        viewModel.load(videoId = "video-empty")

        val state = viewModel.state.value
        assertThat(detailCalls).containsExactly("source-a" to "video-empty")
        assertThat(queries).contains("空线路影片")
        assertThat(state.errorMessage).isNull()
        assertThat(state.detail?.id).isEqualTo("search-video-2")
        assertThat(state.currentSourceId).isEqualTo("source-c::search-video-2")
        assertThat(state.playbackRequest?.url).isEqualTo("https://cdn.test/fallback.m3u8")
    }

    /**
     * 弹幕手动匹配 ViewModel 必须接入真实弹幕搜索 API。
     */
    @Test
    fun createDanmakuMatchViewModel_searches_remote_danmaku_api() = runTest {
        val danmakuApi = RecordingDanmakuApi()
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(
                baseUrl = "http://127.0.0.1:3000",
                username = "demo",
                password = "secret",
                danmakuBaseUrl = "https://danmaku.example.com",
            ),
            danmakuApiFactory = { rawBaseUrl ->
                assertThat(rawBaseUrl).isEqualTo("https://danmaku.example.com")
                danmakuApi
            },
        )
        val viewModel = container.createDanmakuMatchViewModel(initialQuery = "测试番剧")

        viewModel.submitSearch()

        assertThat(danmakuApi.lastAnimeQuery).isEqualTo("测试番剧")
        assertThat(viewModel.state.value.errorMessage).isNull()
        assertThat(viewModel.state.value.results.first().episodes.first().episodeId)
            .isEqualTo(9001)
    }

    /**
     * 容器保存弹幕手动匹配时必须沿用播放器请求里的播放身份。
     */
    @Test
    fun saveDanmakuManualSelection_uses_playback_request_identity() = runTest {
        val preferencesStore = TvPreferencesStore()
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(
                baseUrl = "http://127.0.0.1:3000",
                username = "demo",
                password = "secret",
            ),
            preferencesStore = preferencesStore,
        )
        val playbackRequest = PlaybackRequest(
            videoId = "video-1",
            videoTitle = "测试影片",
            sourceId = "source-a",
            episodeId = "ep-5",
            episodeIndex = 4,
            episodeTitle = "第 5 集",
            url = "https://cdn.test/5.m3u8",
        )
        val anime = org.moontechlab.selene.tv.feature.settings.TvDanmakuSearchAnime(
            animeId = 101,
            animeTitle = "测试番剧",
            type = "tv",
            typeDescription = "TV",
            year = 2024,
            episodes = listOf(
                org.moontechlab.selene.tv.feature.settings.TvDanmakuSearchEpisode(
                    episodeId = 9001,
                    episodeTitle = "第 1 集",
                ),
                org.moontechlab.selene.tv.feature.settings.TvDanmakuSearchEpisode(
                    episodeId = 9002,
                    episodeTitle = "第 2 集",
                ),
            ),
        )

        container.saveDanmakuManualSelection(
            playbackRequest = playbackRequest,
            anime = anime,
            selectedEpisode = anime.episodes[1],
            selectedEpisodeOffset = 1,
            searchKeyword = "测试番剧",
        )

        val manualMatch = preferencesStore.getDanmakuManualMatch("source-a", "video-1", 4)
        assertThat(manualMatch?.episodeId).isEqualTo(9002)
        assertThat(manualMatch?.searchKeyword).isEqualTo("测试番剧")
        assertThat(preferencesStore.getLastDanmakuManualMatchQueryForTitle("测试影片"))
            .isEqualTo("测试番剧")
    }

    /**
     * 播放器 ViewModel 必须通过手动匹配缓存加载当前剧集弹幕评论。
     */
    @Test
    fun createPlayerViewModel_loads_danmaku_comments_from_manual_match() = runTest {
        val preferencesStore = TvPreferencesStore()
        val danmakuApi = RecordingDanmakuApi(
            commentsResponse = TvDanmakuCommentListResponse(
                count = 1,
                comments = listOf(
                    TvDanmakuCommentResponse(
                        cid = 31,
                        p = "6.5,1,16777215,0",
                        m = "播放器弹幕",
                        t = 1710000100,
                    ),
                ),
            ),
        )
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(
                baseUrl = "http://127.0.0.1:3000",
                username = "demo",
                password = "secret",
                danmakuBaseUrl = "https://danmaku.example.com",
            ),
            preferencesStore = preferencesStore,
            danmakuApiFactory = { danmakuApi },
        )
        val playbackRequest = PlaybackRequest(
            videoId = "video-1",
            videoTitle = "测试影片",
            sourceId = "source-a",
            episodeId = "ep-5",
            episodeIndex = 4,
            episodeTitle = "第 5 集",
            url = "https://cdn.test/5.m3u8",
        )
        preferencesStore.saveDanmakuManualMatch(
            source = "source-a",
            videoId = "video-1",
            episodeIndex = 4,
            episodeId = 9005,
            searchKeyword = "测试番剧",
        )
        val viewModel = container.createPlayerViewModel(playbackRequest)

        viewModel.loadDanmakuForCurrentRequest()

        assertThat(danmakuApi.lastCommentEpisodeId).isEqualTo(9005)
        assertThat(viewModel.state.value.currentDanmakuEpisodeId).isEqualTo(9005)
        assertThat(viewModel.state.value.danmakuComments.first().text).isEqualTo("播放器弹幕")
    }
}

/**
 * 测试用后台客户端。
 */
private class FakeGatewayClient(
    private val searchHandler: suspend (String) -> TvSearchResponse = { TvSearchResponse(results = emptyList()) },
    private val detailHandler: suspend (String, String) -> TvSearchResultResponse = { source, id ->
        TvSearchResultResponse(id = id, source = source, title = "测试详情")
    },
) : SeleneTvGatewayClient {
    /** 登录调用次数。 */
    var loginCalls: Int = 0

    /** TV 数据接口。 */
    override val tvApi: SeleneTvApi = object : SeleneTvApi {
        /**
         * 返回测试首页分区。
         *
         * @return 首页响应。
         */
        override suspend fun getDashboard(): TvHomeResponse {
            return TvHomeResponse(
                sections = listOf(
                    TvHomeSectionResponse(
                        key = "hot_movies",
                        title = "热门电影",
                        videos = listOf(
                            TvVideoCardResponse(
                                id = "movie-1",
                                title = "后台电影",
                                posterUrl = "",
                            ),
                        ),
                    ),
                ),
            )
        }

        /** 返回测试播放历史。 */
        override suspend fun getPlayRecords(): Map<String, TvPlayRecordResponse> {
            return emptyMap()
        }

        /** 记录测试播放历史删除。 */
        override suspend fun deletePlayRecord(key: String) = Unit

        /** 记录测试播放历史清空。 */
        override suspend fun clearPlayRecords() = Unit

        /** 返回测试收藏夹。 */
        override suspend fun getFavorites(): Map<String, TvFavoriteResponse> {
            return emptyMap()
        }

        /** 记录测试收藏删除。 */
        override suspend fun deleteFavorite(key: String) = Unit

        /** 记录测试收藏清空。 */
        override suspend fun clearFavorites() = Unit

        /** 返回测试搜索历史。 */
        override suspend fun getSearchHistory(): List<String> {
            return emptyList()
        }

        /** 返回测试搜索资源。 */
        override suspend fun getSearchResources(): List<TvSearchResourceResponse> {
            return emptyList()
        }

        /** 返回测试搜索响应。 */
        override suspend fun search(query: String): TvSearchResponse {
            return searchHandler(query)
        }

        /** 返回测试详情。 */
        override suspend fun getDetail(
            source: String,
            id: String,
        ): TvSearchResultResponse {
            return detailHandler(source, id)
        }
    }

    /**
     * 记录登录调用并返回测试会话。
     *
     * @param username 登录账号。
     * @param password 登录密码。
     * @return 测试会话。
     */
    override suspend fun login(
        username: String,
        password: String,
    ): SessionPayload {
        loginCalls += 1
        return SessionPayload(
            baseUrl = "http://127.0.0.1:3000",
            account = username,
            cookie = "sid=fake",
        )
    }
}

/**
 * 测试用播放器内核。
 */
private class RecordingPlayerEngine : PlayerEngine {
    /** 最近一次加载的播放请求。 */
    var loadedRequest: PlaybackRequest? = null

    /** 当前播放器状态。 */
    override val state: StateFlow<PlayerState> = MutableStateFlow(PlayerState.Idle)

    /**
     * 记录加载请求。
     *
     * @param request 播放请求。
     */
    override suspend fun load(request: PlaybackRequest) {
        loadedRequest = request
    }

    /** 测试无需真实播放。 */
    override suspend fun play() = Unit

    /** 测试无需真实暂停。 */
    override suspend fun pause() = Unit

    /**
     * 测试无需真实跳转。
     *
     * @param positionMs 目标播放位置。
     */
    override suspend fun seekTo(positionMs: Long) = Unit

    /**
     * 测试无需真实倍速切换。
     *
     * @param speed 目标倍速。
     */
    override suspend fun setPlaybackSpeed(speed: Float) = Unit

    /**
     * 测试无需真实画面比例切换。
     *
     * @param resizeMode 目标画面比例。
     */
    override suspend fun setResizeMode(resizeMode: TvResizeMode) = Unit

    /**
     * 测试无需捕获快照。
     *
     * @return 空闲内核不提供快照。
     */
    override suspend fun captureSnapshot(): PlaybackSnapshot {
        error("测试内核未加载快照")
    }

    /**
     * 测试无需恢复快照。
     *
     * @param snapshot 播放快照。
     */
    override suspend fun restoreSnapshot(snapshot: PlaybackSnapshot) = Unit

    /** 测试无需释放资源。 */
    override suspend fun release() = Unit
}

/**
 * 测试用弹幕 API。
 */
private class RecordingDanmakuApi(
    private val commentsResponse: TvDanmakuCommentListResponse = TvDanmakuCommentListResponse(),
) : SeleneDanmakuApi {
    /** 最近一次搜索词。 */
    var lastAnimeQuery: String? = null

    /** 最近一次评论请求剧集 ID。 */
    var lastCommentEpisodeId: Int? = null

    /**
     * 返回固定弹幕搜索结果。
     *
     * @param anime 动画搜索词。
     * @return 弹幕搜索响应。
     */
    override suspend fun searchEpisodes(anime: String): TvDanmakuSearchResponse {
        lastAnimeQuery = anime
        return TvDanmakuSearchResponse(
            success = true,
            errorMessage = "",
            animes = listOf(
                TvDanmakuSearchAnimeResponse(
                    animeId = 101,
                    animeTitle = anime,
                    type = "tv",
                    typeDescription = "TV",
                    year = 2024,
                    episodes = listOf(
                        TvDanmakuSearchEpisodeResponse(
                            episodeId = 9001,
                            episodeTitle = "第 1 集",
                        ),
                    ),
                ),
            ),
        )
    }

    /**
     * 返回固定弹幕评论列表。
     *
     * @param episodeId 弹幕剧集 ID。
     * @param format 评论格式。
     * @return 固定评论响应。
     */
    override suspend fun getComments(
        episodeId: Int,
        format: String,
    ): TvDanmakuCommentListResponse {
        lastCommentEpisodeId = episodeId
        return commentsResponse
    }
}

/**
 * 测试用豆瓣代理 API —— 返回固定首页数据。
 */
private class FakeHomeDoubanApi : SeleneDoubanApi {
    private val testPic = DoubanPic(normal = "test.jpg", large = "test-lg.jpg")
    private val testRating = DoubanRating(value = 8.5)

    override suspend fun getCategoryData(
        kind: String, start: Int, limit: Int, category: String, type: String,
    ): DoubanCategoryResponse {
        return DoubanCategoryResponse(
            items = listOf(
                DoubanMovieItem(
                    id = "$kind-$category",
                    title = "$category $kind",
                    pic = testPic,
                    rating = testRating,
                    cardSubtitle = "2025",
                ),
            ),
        )
    }

    override suspend fun getRecommends(
        kind: String, refresh: Int, start: Int, count: Int,
        selectedCategories: String, uncollect: Boolean, scoreRange: String,
        tags: String, sort: String,
    ): DoubanCategoryResponse {
        return DoubanCategoryResponse(
            items = listOf(
                DoubanMovieItem(
                    id = "rec-$kind",
                    title = "推荐 $kind",
                    pic = testPic,
                    rating = testRating,
                    cardSubtitle = "2025",
                ),
            ),
        )
    }
}
