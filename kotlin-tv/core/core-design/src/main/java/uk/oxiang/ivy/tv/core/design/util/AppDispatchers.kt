package uk.oxiang.ivy.tv.core.design.util

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi

/**
 * TV 原生工程默认调度器实现。
 *
 * @property main 主线程调度器。
 * @property playback 播放链路专用调度器。
 * @property io IO 调度器。
 * @property default 默认后台调度器。
 */
data class AppDispatchers(
    override val main: CoroutineDispatcher,
    override val playback: CoroutineDispatcher,
    override val io: CoroutineDispatcher,
    override val default: CoroutineDispatcher,
) : DispatcherProvider {
    companion object {
        /**
         * 创建应用默认调度器分层。
         *
         * @return 默认调度器集合。
         */
        @OptIn(ExperimentalCoroutinesApi::class)
        fun createDefault(): AppDispatchers {
            // 播放控制独立线程，避免 seek 和切内核任务挤占主线程。
            val playbackDispatcher = Dispatchers.Default.limitedParallelism(1)
            return AppDispatchers(
                main = Dispatchers.Main,
                playback = playbackDispatcher,
                io = Dispatchers.IO,
                default = Dispatchers.Default,
            )
        }
    }
}
