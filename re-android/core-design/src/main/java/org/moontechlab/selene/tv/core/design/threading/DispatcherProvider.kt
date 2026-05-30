package org.moontechlab.selene.tv.core.design.threading

import kotlinx.coroutines.CoroutineDispatcher

/**
 * 提供 TV 原生工程的协程调度器分层。
 */
interface DispatcherProvider {
    /**
     * 主线程调度器，用于 Compose UI、焦点和遥控器事件分发。
     */
    val main: CoroutineDispatcher

    /**
     * 播放链路调度器，用于播放器 load、seek、切源和切内核。
     */
    val playback: CoroutineDispatcher

    /**
     * IO 调度器，用于接口请求、配置读取和本地持久化。
     */
    val io: CoroutineDispatcher

    /**
     * 默认后台调度器，用于地址解析、结果去重和规则计算。
     */
    val default: CoroutineDispatcher
}
