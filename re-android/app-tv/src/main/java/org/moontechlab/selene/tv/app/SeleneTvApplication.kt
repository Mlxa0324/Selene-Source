package org.moontechlab.selene.tv.app

import android.app.Application

/**
 * TV 原生工程的应用入口。
 *
 * 当前阶段只负责承载全局 Application 生命周期，
 * 后续需要初始化日志、网络或播放器组件时再在这里扩展。
 */
class SeleneTvApplication : Application()
