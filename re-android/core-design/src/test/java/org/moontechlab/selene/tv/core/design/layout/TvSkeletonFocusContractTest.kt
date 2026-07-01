package org.moontechlab.selene.tv.core.design.layout

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 TV 加载骨架的遥控器焦点契约。
 */
class TvSkeletonFocusContractTest {
    /**
     * 加载骨架必须支持内容入口焦点请求器，避免顶部导航下探 loading 页失焦。
     */
    @Test
    fun skeletons_accept_content_focus_requester() {
        val source = readSkeletonSource()

        assertThat(source).contains("contentFocusRequester: FocusRequester? = null")
        assertThat(source).contains("loadingFocusTarget(contentFocusRequester)")
        assertThat(source).contains("focusRequester(contentFocusRequester).focusable()")
    }

    /**
     * 通用网格骨架必须把入口请求器继续传给视频库骨架。
     */
    @Test
    fun poster_grid_skeleton_delegates_content_focus_requester() {
        val source = readSkeletonSource()
        val gridSkeletonSource = source.substringAfter("fun TvPosterGridSkeleton(")
            .substringBefore("/**\n * 为可见加载骨架提供内容入口焦点目标。")

        assertThat(gridSkeletonSource).contains("contentFocusRequester = contentFocusRequester")
    }

    /**
     * 读取骨架屏源码。
     *
     * @return 当前 TvSkeleton 源码文本。
     */
    private fun readSkeletonSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/core/design/layout/TvSkeleton.kt")
            .readText()
    }
}
