package org.moontechlab.selene.tv.app

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvVideoDetail
import org.moontechlab.selene.tv.core.data.storage.TvPreferencesStore
import org.moontechlab.selene.tv.core.network.DoubanSubjectHtmlSource
import org.moontechlab.selene.tv.core.network.SeleneTvApi
import org.moontechlab.selene.tv.core.network.SeleneDanmakuApi
import org.moontechlab.selene.tv.core.network.SeleneDoubanApi
import org.moontechlab.selene.tv.core.network.SeleneTvGatewayClient
import org.moontechlab.selene.tv.core.network.SeleneTvSearchStreamClient
import org.moontechlab.selene.tv.core.network.TvSearchCompleteEvent
import org.moontechlab.selene.tv.core.network.TvSearchSourceResultEvent
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
import org.moontechlab.selene.tv.core.network.model.TvPlayRecordUpsertRequest
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
import org.moontechlab.selene.tv.feature.detail.TvDetailEntry
import org.moontechlab.selene.tv.feature.detail.TvDetailRecommendDiagnostic
import org.moontechlab.selene.tv.feature.detail.TvDetailRecommendDiagnosticSink
import org.moontechlab.selene.tv.feature.detail.TvDetailRecommendDiagnosticStage
import org.moontechlab.selene.tv.feature.detail.TvDetailRecommendLoadState
import org.moontechlab.selene.tv.feature.search.TvSearchRecommendCache

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
        assertThat(state.playerKernelKey).isEqualTo("exo")
    }

    /**
     * 设置页首屏必须展示当前真实播放内核，避免 UI 写着 Exo、实际运行仍是 WebView。
     */
    @Test
    fun createSettingsViewModel_prefills_saved_player_kernel() = runTest {
        val preferencesStore = TvPreferencesStore()
        preferencesStore.savePlayerKernel("exo")
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(
                baseUrl = "http://127.0.0.1:3000",
                username = "demo",
                password = "secret",
            ),
            preferencesStore = preferencesStore,
        )

        val state = container.createSettingsViewModel().state.value

        assertThat(state.playerKernelKey).isEqualTo("exo")
    }

    /**
     * 模拟器命中 WebView 黑屏高风险环境时，
     * 容器暴露给导航和设置页的内核必须自动回退到 Exo。
     */
    @Test
    fun player_kernel_falls_back_to_exo_for_emulator_webview_runtime() = runTest {
        val preferencesStore = TvPreferencesStore()
        preferencesStore.savePlayerKernel("webview")
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(
                baseUrl = "http://127.0.0.1:3000",
                username = "demo",
                password = "secret",
            ),
            preferencesStore = preferencesStore,
            playerKernelResolver = RuntimePlayerKernelResolver(
                deviceInfo = TvPlaybackDeviceInfo(
                    fingerprint = "samsung/p3sxxx/p3s:13/TQ2B.230505.005.A1/jenkins08312143:user/release-keys",
                    model = "SM-G998B",
                    manufacturer = "samsung",
                    brand = "samsung",
                    device = "p3s",
                    hardware = "exynos2100",
                    product = "p3sxxx",
                    eglHardware = "emulation",
                    blueStacksImeListenerPort = "9990",
                ),
            ),
        )

        assertThat(container.peekPlayerKernel()).isEqualTo("exo")
        assertThat(container.getPlayerKernel()).isEqualTo("exo")
        assertThat(container.createSettingsViewModel().state.value.playerKernelKey).isEqualTo("exo")
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
     * 资料源入口缺少精确 `source+id` 时，详情页仍应按标题命中最新续播记录恢复集数和时间点。
     */
    @Test
    fun createDetailViewModel_matches_resume_record_by_title_when_route_source_is_metadata_only() = runTest {
        val fakeClient = FakeGatewayClient(
            playRecordsHandler = {
                mapOf(
                    "source-real+play-video" to TvPlayRecordResponse(
                        title = "测试影片",
                        sourceName = "线路 Real",
                        year = "2026",
                        cover = "https://img.test/poster.jpg",
                        index = 3,
                        totalEpisodes = 8,
                        playTime = 125,
                        totalTime = 3_600,
                        saveTime = 30L,
                        searchTitle = "测试影片",
                    ),
                )
            },
            detailHandler = { _, _ ->
                TvSearchResultResponse(
                    id = "douban-123",
                    source = "douban",
                    title = "测试影片",
                    episodes = emptyList(),
                )
            },
            searchHandler = { query ->
                assertThat(query).isEqualTo("测试影片")
                TvSearchResponse(
                    results = listOf(
                        TvSearchResultResponse(
                            id = "play-video",
                            title = "测试影片",
                            episodes = listOf(
                                "https://cdn.test/1.m3u8",
                                "https://cdn.test/2.m3u8",
                                "https://cdn.test/3.m3u8",
                                "https://cdn.test/4.m3u8",
                            ),
                            episodeTitles = listOf("第 1 集", "第 2 集", "第 3 集", "第 4 集"),
                            source = "source-real",
                            sourceName = "线路 Real",
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
            source = "douban",
            videoTitle = "测试影片",
        )

        viewModel.load(videoId = "douban-123")

        val state = viewModel.state.value
        assertThat(state.currentSourceId).isEqualTo("source-real::play-video")
        assertThat(state.currentEpisodeId).isEqualTo("source-real::play-video-2")
        assertThat(state.playbackRequest?.episodeIndex).isEqualTo(2)
        assertThat(state.playbackRequest?.startPositionMs).isEqualTo(125_000L)
    }

    /**
     * 详情页标题补源接入 SSE 时，容器必须把增量线路直接推给 ViewModel，不能等批量搜索结束。
     */
    @Test
    fun createDetailViewModel_streams_more_sources_incrementally() = runTest {
        val queries = mutableListOf<String>()
        val fakeClient = FakeGatewayClient(
            detailHandler = { _, _ -> error("详情接口失败") },
            searchHandler = { query ->
                queries += query
                TvSearchResponse(results = emptyList())
            },
        )
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(
                baseUrl = "http://127.0.0.1:3000",
                username = "demo",
                password = "secret",
            ),
            gatewayClientFactory = { _, _ -> fakeClient },
            searchStreamClientFactory = { _, _ ->
                object : SeleneTvSearchStreamClient {
                    override suspend fun search(
                        query: String,
                        onEvent: (org.moontechlab.selene.tv.core.network.TvSearchStreamEvent) -> Unit,
                    ) {
                        onEvent(
                            TvSearchSourceResultEvent(
                                source = "source-sse",
                                sourceName = "SSE 补源",
                                results = listOf(
                                    TvSearchResultResponse(
                                        id = "search-video-sse",
                                        title = "详情影片",
                                        episodes = listOf("https://cdn.test/sse.m3u8"),
                                        episodeTitles = listOf("正片"),
                                        source = "source-sse",
                                        sourceName = "SSE 补源",
                                        year = "2026",
                                    ),
                                ),
                                timestamp = 1L,
                            ),
                        )
                        onEvent(
                            TvSearchCompleteEvent(
                                totalResults = 1,
                                completedSources = 1,
                                timestamp = 2L,
                            ),
                        )
                    }
                }
            },
        )
        val viewModel = container.createDetailViewModel(
            source = "source-a",
            videoTitle = "详情影片",
        )

        viewModel.load(videoId = "video-1")

        val state = viewModel.state.value
        assertThat(queries).contains("详情影片")
        assertThat(state.detail?.sources?.map { source -> source.id })
            .containsExactly("source-sse::search-video-sse")
        assertThat(state.currentSourceId).isEqualTo("source-sse::search-video-sse")
        assertThat(state.playbackRequest?.url).isEqualTo("https://cdn.test/sse.m3u8")
    }

    /**
     * 最新详情豆瓣 ID 有效时，应优先于精确详情、豆瓣入口和标题解析结果。
     */
    @Test
    fun resolveTvDetailRecommendDoubanId_prefers_latest_detail_id() = runTest {
        var resolverCalls = 0

        val resolved = resolveTvDetailRecommendDoubanId(
            entry = TvDetailEntry(source = "douban", videoId = "entry-id", title = "测试影片"),
            latestDetail = detail(doubanId = " latest-id "),
            exactDetail = detail(doubanId = "exact-id"),
            resolveByTitle = {
                resolverCalls += 1
                "resolver-id"
            },
        )

        assertThat(resolved).isEqualTo("latest-id")
        assertThat(resolverCalls).isEqualTo(0)
    }

    /**
     * 最新详情 ID 无效时，应使用当前入口键对应的精确详情豆瓣 ID。
     */
    @Test
    fun resolveTvDetailRecommendDoubanId_uses_matching_exact_detail_id() = runTest {
        val resolved = resolveTvDetailRecommendDoubanId(
            entry = TvDetailEntry(source = "source-a", videoId = "video-a", title = "测试影片"),
            latestDetail = detail(doubanId = "0"),
            exactDetail = detail(doubanId = " exact-id "),
            resolveByTitle = { "resolver-id" },
        )

        assertThat(resolved).isEqualTo("exact-id")
    }

    /**
     * 详情 ID 都无效时，豆瓣资料入口应直接使用入口视频 ID。
     */
    @Test
    fun resolveTvDetailRecommendDoubanId_uses_douban_entry_video_id() = runTest {
        val resolved = resolveTvDetailRecommendDoubanId(
            entry = TvDetailEntry(source = " DouBan ", videoId = " entry-id ", title = "测试影片"),
            latestDetail = detail(doubanId = " "),
            exactDetail = detail(doubanId = "0"),
            resolveByTitle = { "resolver-id" },
        )

        assertThat(resolved).isEqualTo("entry-id")
    }

    /**
     * 详情和入口身份均无效时，应使用标题年份解析结果并拒绝空值或零值。
     */
    @Test
    fun resolveTvDetailRecommendDoubanId_uses_valid_title_resolver_result() = runTest {
        val resolved = resolveTvDetailRecommendDoubanId(
            entry = TvDetailEntry(source = "source-a", videoId = "video-a", title = "测试影片", year = "2026"),
            latestDetail = detail(doubanId = "0", title = ""),
            exactDetail = detail(doubanId = "", title = "精确标题"),
            resolveByTitle = { lookupDetail ->
                assertThat(lookupDetail?.title).isEqualTo("精确标题")
                " resolver-id "
            },
        )

        assertThat(resolved).isEqualTo("resolver-id")
    }

    /**
     * 所有身份候选均为空或零值时，应记录缺失诊断且不能抓取豆瓣 HTML。
     */
    @Test
    fun createDetailViewModel_reports_missing_douban_id_without_fetching_html() = runTest {
        val diagnostics = mutableListOf<TvDetailRecommendDiagnostic>()
        var htmlFetchCalls = 0
        val fakeClient = FakeGatewayClient(
            detailHandler = { source, id ->
                TvSearchResultResponse(
                    id = id,
                    title = "无豆瓣身份影片",
                    episodes = listOf("https://cdn.test/no-douban.m3u8"),
                    episodeTitles = listOf("正片"),
                    source = source,
                    sourceName = "线路 A",
                    year = "2026",
                    doubanId = 0,
                )
            },
            searchHandler = {
                TvSearchResponse(
                    results = listOf(
                        TvSearchResultResponse(
                            id = "search-no-douban",
                            title = "无豆瓣身份影片",
                            source = "source-b",
                            year = "2026",
                            doubanId = 0,
                        ),
                    ),
                )
            },
        )
        val container = TvAppContainer(
            gatewayConfig = completeGatewayConfig(),
            gatewayClientFactory = { _, _ -> fakeClient },
            doubanApiFactory = { FakeHomeDoubanApi() },
            doubanHtmlSourceFactory = {
                DoubanSubjectHtmlSource {
                    htmlFetchCalls += 1
                    RECOMMENDATION_HTML
                }
            },
            recommendDiagnosticSink = TvDetailRecommendDiagnosticSink { event -> diagnostics += event },
        )
        val viewModel = container.createDetailViewModel(
            source = "source-a",
            videoTitle = "无豆瓣身份影片",
        )

        viewModel.load(videoId = "video-no-douban")

        assertThat(htmlFetchCalls).isEqualTo(0)
        assertThat(viewModel.state.value.recommendLoadState)
            .isEqualTo(TvDetailRecommendLoadState.Empty)
        assertThat(diagnostics.map { event -> event.stage })
            .contains(TvDetailRecommendDiagnosticStage.MissingDoubanId)
    }

    /**
     * 精确详情携带豆瓣 ID 时，容器创建的 ViewModel 应通过假 HTML 数据源返回推荐卡片。
     */
    @Test
    fun createDetailViewModel_returns_recommend_cards_from_fake_html_source() = runTest {
        val fetchedIds = mutableListOf<String>()
        val fakeClient = FakeGatewayClient(
            detailHandler = { source, id ->
                TvSearchResultResponse(
                    id = id,
                    title = "有推荐影片",
                    episodes = listOf("https://cdn.test/recommend.m3u8"),
                    episodeTitles = listOf("正片"),
                    source = source,
                    sourceName = "线路 A",
                    year = "2026",
                    doubanId = 1_292_052,
                )
            },
        )
        val container = TvAppContainer(
            gatewayConfig = completeGatewayConfig(),
            gatewayClientFactory = { _, _ -> fakeClient },
            doubanApiFactory = { FakeHomeDoubanApi() },
            doubanHtmlSourceFactory = {
                DoubanSubjectHtmlSource { doubanId ->
                    fetchedIds += doubanId
                    RECOMMENDATION_HTML
                }
            },
        )
        val viewModel = container.createDetailViewModel(
            source = "source-a",
            videoTitle = "有推荐影片",
        )

        viewModel.load(videoId = "video-with-douban")

        assertThat(fetchedIds).containsExactly("1292052")
        assertThat(viewModel.state.value.recommendCards.map { card -> card.id })
            .containsExactly("1111111", "2222222")
            .inOrder()
        assertThat(viewModel.state.value.recommendLoadState)
            .isEqualTo(TvDetailRecommendLoadState.Loaded)
    }

    /**
     * 详情相关推荐加载成功后应写入搜索页推荐缓存，供搜索「影片推荐」复用。
     */
    @Test
    fun createDetailViewModel_records_recommends_into_search_cache() = runTest {
        val searchCache = TvSearchRecommendCache()
        val fakeClient = FakeGatewayClient(
            detailHandler = { source, id ->
                TvSearchResultResponse(
                    id = id,
                    title = "有推荐影片",
                    episodes = listOf("https://cdn.test/recommend.m3u8"),
                    episodeTitles = listOf("正片"),
                    source = source,
                    sourceName = "线路 A",
                    year = "2026",
                    doubanId = 1_292_052,
                )
            },
        )
        val container = TvAppContainer(
            gatewayConfig = completeGatewayConfig(),
            gatewayClientFactory = { _, _ -> fakeClient },
            doubanApiFactory = { FakeHomeDoubanApi() },
            doubanHtmlSourceFactory = {
                DoubanSubjectHtmlSource { RECOMMENDATION_HTML }
            },
            searchRecommendCache = searchCache,
        )
        val detailViewModel = container.createDetailViewModel(
            source = "source-a",
            videoTitle = "有推荐影片",
        )

        detailViewModel.load(videoId = "video-with-douban")

        assertThat(searchCache.peekCachedRecommends().map { card -> card.id })
            .containsExactly("1111111", "2222222")
            .inOrder()
    }

    /**
     * 搜索页 bootstrap 优先使用详情沉淀的推荐，而不是直接拉豆瓣热门。
     */
    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun createSearchViewModel_prefers_detail_recommend_cache() = runTest {
        val mainDispatcher = StandardTestDispatcher(testScheduler)
        Dispatchers.setMain(mainDispatcher)
        try {
            val searchCache = TvSearchRecommendCache()
            searchCache.recordDetailRecommends(
                source = "src",
                videoId = "v1",
                title = "用户看过",
                recommends = listOf(
                    org.moontechlab.selene.tv.core.data.model.TvVideoCard(
                        id = "from-detail-1",
                        source = "douban",
                        title = "详情相关1",
                        posterUrl = "https://img.test/1.jpg",
                    ),
                ),
            )
            val container = TvAppContainer(
                gatewayConfig = completeGatewayConfig(),
                gatewayClientFactory = { _, _ -> FakeGatewayClient() },
                doubanApiFactory = { FakeHomeDoubanApi() },
                searchRecommendCache = searchCache,
            )
            val searchViewModel = container.createSearchViewModel()

            searchViewModel.bootstrap()
            advanceUntilIdle()

            assertThat(searchViewModel.state.value.recommendCards.map { card -> card.id })
                .containsExactly("from-detail-1")
        } finally {
            Dispatchers.resetMain()
        }
    }

    /**
     * 上一个入口的精确详情晚到时，只能写入自己的键，不能给当前入口提供豆瓣 ID。
     */
    @Test
    fun exact_detail_store_does_not_leak_late_previous_entry_identity() = runTest {
        val store = TvDetailExactDetailStore()
        val previousEntry = TvDetailEntry(source = "source-a", videoId = "previous-video")
        val currentEntry = TvDetailEntry(source = "source-b", videoId = "current-video")

        // 模拟切换当前入口后，上一入口的精确详情才晚到。
        val previousToken = store.beginRequest(previousEntry)
        store.completeRequest(
            previousEntry,
            previousToken,
            detail(doubanId = "previous-douban-id"),
        )
        val resolved = resolveTvDetailRecommendDoubanId(
            entry = currentEntry,
            latestDetail = detail(doubanId = ""),
            exactDetail = store.find(currentEntry),
            resolveByTitle = { "" },
        )

        assertThat(store.find(previousEntry)?.doubanId).isEqualTo("previous-douban-id")
        assertThat(resolved).isNull()
    }

    /**
     * 同一入口后续精确详情为空时，应删除旧详情，避免复用过期豆瓣 ID。
     */
    @Test
    fun exact_detail_store_removes_obsolete_identity_for_same_entry() {
        val store = TvDetailExactDetailStore()
        val entry = TvDetailEntry(source = "source-a", videoId = "video-a")

        val firstToken = store.beginRequest(entry)
        store.completeRequest(entry, firstToken, detail(doubanId = "old-douban-id"))
        val refreshToken = store.beginRequest(entry)
        store.completeRequest(entry, refreshToken, null)

        assertThat(store.find(entry)).isNull()
    }

    /**
     * 同一入口的旧请求晚于新请求完成时，旧非空结果不能覆盖新请求确认的空详情。
     */
    @Test
    fun exact_detail_store_ignores_older_same_entry_completion() {
        val store = TvDetailExactDetailStore()
        val entry = TvDetailEntry(source = "source-a", videoId = "video-a")
        val olderToken = store.beginRequest(entry)
        val newerToken = store.beginRequest(entry)

        store.completeRequest(entry, newerToken, null)
        store.completeRequest(entry, olderToken, detail(doubanId = "stale-douban-id"))

        assertThat(store.find(entry)).isNull()
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

    /**
     * 构造完整本地后台配置。
     *
     * @return 可用于容器测试的完整配置。
     */
    private fun completeGatewayConfig(): TvLocalGatewayConfig {
        return TvLocalGatewayConfig(
            baseUrl = "http://127.0.0.1:3000",
            username = "demo",
            password = "secret",
        )
    }

    /**
     * 构造身份解析测试详情。
     *
     * @param doubanId 豆瓣条目 ID。
     * @param title 详情标题。
     * @return 不含播放源的详情模型。
     */
    private fun detail(
        doubanId: String,
        title: String = "测试影片",
    ): TvVideoDetail {
        return TvVideoDetail(
            id = "detail-video",
            doubanId = doubanId,
            title = title,
            description = "",
            year = "2026",
            sources = emptyList(),
        )
    }

    private companion object {
        /** App 容器推荐接线测试使用的固定豆瓣推荐 HTML。 */
        val RECOMMENDATION_HTML = """
            <div id="recommendations">
              <div class="recommendations-bd">
                <dl>
                  <dt><a href="//movie.douban.com/subject/1111111/"><img alt="推荐甲" src="//img.test/a.jpg"></a></dt>
                  <dd><span class="subject-rate">9.1</span></dd>
                </dl>
                <dl>
                  <dt><a href="/subject/2222222/"><img src="https://img.test/b.jpg" alt="推荐乙"></a></dt>
                </dl>
              </div>
            </div>
        """.trimIndent()
    }
}

/**
 * 测试用后台客户端。
 */
private class FakeGatewayClient(
    private val playRecordsHandler: suspend () -> Map<String, TvPlayRecordResponse> = { emptyMap() },
    private val savePlayRecordHandler: suspend (TvPlayRecordUpsertRequest) -> Unit = {},
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
            return playRecordsHandler()
        }

        /** 记录测试播放历史保存。 */
        override suspend fun savePlayRecord(request: TvPlayRecordUpsertRequest) {
            savePlayRecordHandler(request)
        }

        /** 记录测试播放历史删除。 */
        override suspend fun deletePlayRecord(key: String) = Unit

        /** 记录测试播放历史清空。 */
        override suspend fun clearPlayRecords() = Unit

        /** 返回测试收藏夹。 */
        override suspend fun getFavorites(): Map<String, TvFavoriteResponse> {
            return emptyMap()
        }

        /** 记录测试收藏保存。 */
        override suspend fun saveFavorite(
            request: org.moontechlab.selene.tv.core.network.model.TvFavoriteUpsertRequest,
        ) = Unit

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
