package org.moontechlab.selene.tv.core.data.storage

/**
 * TV 本地数据库状态入口。
 */
class TvDatabase {
    /**
     * 数据库是否已经初始化。
     *
     * @return 当前实现始终返回 true。
     */
    fun isReady(): Boolean {
        // 接入 Room 时，这里会收敛历史、收藏和播放记录 DAO。
        return true
    }
}
