package org.moontechlab.selene.tv.core.design.layout

import kotlin.math.abs

/**
 * 多层横向列表焦点滚动策略。
 *
 * TV 详情/首页/播放器等多层轨道共用：
 * - 同轨左右相邻移动：允许横向推进；
 * - 上下跨层离开再进入：保持原横向偏移，不得复位或强行 pin。
 */
object TvLayeredHorizontalFocusScroll {
    /**
     * 表示当前轨尚无会话内活跃焦点（刚跨层进入或整行失焦后）。
     */
    const val NoActiveIndex: Int = -1

    /**
     * 判断本次获焦是否应触发横向滚动动画。
     *
     * 仅当本轨会话内已有活跃焦点，且新焦点与旧焦点左右相邻一步时才滚动。
     * 上下跨层进入时 [previousActiveIndex] 应为 [NoActiveIndex]，从而抑制横向复位。
     *
     * @param previousActiveIndex 本轨会话上一次活跃焦点下标；无会话时为 [NoActiveIndex]。
     * @param newlyFocusedIndex 本次获焦下标。
     * @return true 表示应执行横向 animate/scroll；false 表示保持现有 offset。
     */
    fun shouldAnimateHorizontalScroll(
        previousActiveIndex: Int,
        newlyFocusedIndex: Int,
    ): Boolean {
        // 跨层进入或首次落点：不推横向列表，避免被移开的轨道看起来“复位”。
        if (previousActiveIndex < 0) {
            return false
        }
        // 仅左右相邻一步才跟手推进；跨多项落点（重建/程序聚焦）也不自动滚。
        return abs(newlyFocusedIndex - previousActiveIndex) == 1
    }
}
