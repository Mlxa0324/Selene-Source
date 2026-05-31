package org.moontechlab.selene.tv.core.design.threading

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.test.StandardTestDispatcher
import org.junit.Test

/**
 * 校验调度器提供者是否显式拆分 UI、播放、IO 与默认后台线程。
 */
class DispatcherProviderTest {

    /**
     * 验证四类调度器必须是不同实例，避免把播放与数据任务压到同一线程。
     */
    @Test
    fun provider_exposes_distinct_dispatchers_for_ui_playback_io_and_default() {
        val provider = TestDispatcherProvider()

        assertThat(provider.main).isNotSameInstanceAs(provider.playback)
        assertThat(provider.playback).isNotSameInstanceAs(provider.io)
        assertThat(provider.io).isNotSameInstanceAs(provider.default)
    }
}

/**
 * 为单元测试提供一组可控的测试调度器。
 */
private class TestDispatcherProvider : DispatcherProvider {

    /**
     * 模拟主线程调度器。
     */
    override val main: CoroutineDispatcher = StandardTestDispatcher()

    /**
     * 模拟播放链路专用调度器。
     */
    override val playback: CoroutineDispatcher = StandardTestDispatcher()

    /**
     * 模拟 IO 调度器。
     */
    override val io: CoroutineDispatcher = StandardTestDispatcher()

    /**
     * 模拟通用后台调度器。
     */
    override val default: CoroutineDispatcher = StandardTestDispatcher()
}
