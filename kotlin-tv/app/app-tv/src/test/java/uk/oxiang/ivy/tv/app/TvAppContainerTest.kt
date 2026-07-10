package uk.oxiang.ivy.tv.app

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Test
import uk.oxiang.ivy.tv.core.common.network.SeleneDanmakuApi
import uk.oxiang.ivy.tv.core.common.network.SeleneTvApi
import uk.oxiang.ivy.tv.core.common.network.SeleneTvGatewayClient
import uk.oxiang.ivy.tv.core.common.network.SessionPayload
import uk.oxiang.ivy.tv.core.player.api.PlaybackRequest
import uk.oxiang.ivy.tv.core.player.api.PlaybackSnapshot
import uk.oxiang.ivy.tv.core.player.api.PlayerEngine
import uk.oxiang.ivy.tv.core.player.api.PlayerState
import uk.oxiang.ivy.tv.core.player.api.TvResizeMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import uk.oxiang.ivy.tv.core.common.network.model.TvDanmakuCommentListResponse
import uk.oxiang.ivy.tv.core.common.network.model.TvDanmakuSearchResponse
import java.io.File

/**
 * [TvAppContainer] 工厂注入契约测试：验证骨架阶段的工厂覆盖、缺配置回退和
 * 各 lazy 属性能否用注入的假实现正确装配，不依赖真实网络或播放器内核。
 */
class TvAppContainerTest {

    private lateinit var tempFile: File

    @Before
    fun setUp() {
        tempFile = File.createTempFile("tv_app_container_test", ".preferences_pb")
    }

    @After
    fun tearDown() {
        tempFile.delete()
    }

    private fun createDataStore() = PreferenceDataStoreFactory.create(produceFile = { tempFile })

    @Test
    fun requireGatewayClient_throwsWhenGatewayConfigIsIncomplete() {
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(baseUrl = "", username = "", password = ""),
            dataStore = createDataStore(),
        )

        assertThat(runCatching { container.requireGatewayClient() }.isFailure).isTrue()
    }

    @Test
    fun requireGatewayClient_returnsInjectedClientWhenConfigIsComplete() {
        val fakeClient = FakeSeleneTvGatewayClient()
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(
                baseUrl = "https://example.com",
                username = "user",
                password = "pass",
            ),
            dataStore = createDataStore(),
            gatewayClientFactory = { _, _ -> fakeClient },
        )

        assertThat(container.requireGatewayClient()).isSameInstanceAs(fakeClient)
    }

    @Test
    fun danmakuRepository_isNullWhenDanmakuBaseUrlIsBlank() {
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(
                baseUrl = "https://example.com",
                username = "user",
                password = "pass",
                danmakuBaseUrl = "",
            ),
            dataStore = createDataStore(),
        )

        assertThat(container.danmakuRepository).isNull()
    }

    @Test
    fun danmakuRepository_isCreatedFromInjectedApiFactoryWhenBaseUrlProvided() {
        var requestedBaseUrl: String? = null
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(
                baseUrl = "https://example.com",
                username = "user",
                password = "pass",
                danmakuBaseUrl = "https://danmaku.example.com",
            ),
            dataStore = createDataStore(),
            danmakuApiFactory = { baseUrl ->
                requestedBaseUrl = baseUrl
                FakeSeleneDanmakuApi
            },
        )

        assertThat(container.danmakuRepository).isNotNull()
        assertThat(requestedBaseUrl).isEqualTo("https://danmaku.example.com")
    }

    @Test
    fun settingsRepository_isNullWhenGatewayClientUnavailable() {
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(baseUrl = "", username = "", password = ""),
            dataStore = createDataStore(),
        )

        assertThat(container.settingsRepository).isNull()
    }

    @Test
    fun createPlayerEngine_returnsInstanceFromInjectedFactory() {
        val fakeEngine = FakePlayerEngine()
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(baseUrl = "", username = "", password = ""),
            dataStore = createDataStore(),
            playerEngineFactory = { fakeEngine },
        )

        assertThat(container.createPlayerEngine()).isSameInstanceAs(fakeEngine)
    }

    @Test
    fun preferencesStore_isBackedByInjectedDataStore() = runTest {
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(baseUrl = "", username = "", password = ""),
            dataStore = createDataStore(),
        )

        container.preferencesStore.saveThemePaletteKey("ivy_green")

        assertThat(container.preferencesStore.themePaletteKeyFlow().first()).isEqualTo("ivy_green")
    }

    /** 测试用假后台网关客户端，避免真实网络请求。 */
    private class FakeSeleneTvGatewayClient : SeleneTvGatewayClient {
        override val tvApi: SeleneTvApi
            get() = error("骨架测试不需要真实 tvApi")

        override suspend fun login(username: String, password: String): SessionPayload {
            return SessionPayload(baseUrl = "https://example.com", account = username, cookie = "")
        }
    }

    /** 测试用假弹幕接口占位，容器只判断是否非空，不需要真实网络返回。 */
    private object FakeSeleneDanmakuApi : SeleneDanmakuApi {
        override suspend fun searchEpisodes(anime: String): TvDanmakuSearchResponse {
            error("骨架测试不需要真实弹幕搜索响应")
        }

        override suspend fun getComments(episodeId: Int, format: String): TvDanmakuCommentListResponse {
            error("骨架测试不需要真实弹幕评论响应")
        }
    }

    /** 测试用假播放器内核，仅验证工厂返回值身份。 */
    private class FakePlayerEngine : PlayerEngine {
        override val state: StateFlow<PlayerState> = MutableStateFlow(PlayerState.Idle)

        override suspend fun load(request: PlaybackRequest) = Unit

        override suspend fun play() = Unit

        override suspend fun pause() = Unit

        override suspend fun seekTo(positionMs: Long) = Unit

        override suspend fun setPlaybackSpeed(speed: Float) = Unit

        override suspend fun setResizeMode(resizeMode: TvResizeMode) = Unit

        override suspend fun captureSnapshot(): PlaybackSnapshot = error("骨架测试不需要真实快照")

        override suspend fun restoreSnapshot(snapshot: PlaybackSnapshot) = Unit

        override suspend fun release() = Unit
    }
}
