package org.moontechlab.selene.tv.app

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.network.SeleneTvApi
import org.moontechlab.selene.tv.core.network.SeleneTvGatewayClient
import org.moontechlab.selene.tv.core.network.SessionPayload
import org.moontechlab.selene.tv.core.network.model.TvHomeResponse
import org.moontechlab.selene.tv.core.network.model.TvHomeSectionResponse
import org.moontechlab.selene.tv.core.network.model.TvVideoCardResponse

/**
 * 校验 TV 应用容器的本地后台配置装配。
 */
class TvAppContainerTest {
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
