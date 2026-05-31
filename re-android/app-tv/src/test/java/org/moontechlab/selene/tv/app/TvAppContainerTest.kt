package org.moontechlab.selene.tv.app

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.network.SeleneTvApi
import org.moontechlab.selene.tv.core.network.SeleneTvGatewayClient
import org.moontechlab.selene.tv.core.network.SessionPayload
import org.moontechlab.selene.tv.core.network.model.TvFavoriteResponse
import org.moontechlab.selene.tv.core.network.model.TvHomeResponse
import org.moontechlab.selene.tv.core.network.model.TvHomeSectionResponse
import org.moontechlab.selene.tv.core.network.model.TvPlayRecordResponse
import org.moontechlab.selene.tv.core.network.model.TvSearchResourceResponse
import org.moontechlab.selene.tv.core.network.model.TvSearchResponse
import org.moontechlab.selene.tv.core.network.model.TvVideoCardResponse

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
            ),
        )
        val viewModel = container.createSettingsViewModel()

        val state = viewModel.state.value
        assertThat(state.serverUrl).isEqualTo("http://127.0.0.1:3000")
        assertThat(state.account).isEqualTo("demo")
        assertThat(state.password).isEqualTo("secret")
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
     * 配置完整时首页应先登录再加载后台分区。
     */
    @Test
    fun createHomeViewModel_logs_in_and_loads_dashboard() = runTest {
        val fakeClient = FakeGatewayClient()
        val container = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig(
                baseUrl = "http://127.0.0.1:3000",
                username = "demo",
                password = "secret",
            ),
            gatewayClientFactory = { _, _ -> fakeClient },
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
        ).containsExactly("后台电影")
    }
}

/**
 * 测试用后台客户端。
 */
private class FakeGatewayClient : SeleneTvGatewayClient {
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
            return TvSearchResponse(results = emptyList())
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
