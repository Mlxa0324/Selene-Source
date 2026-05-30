package org.moontechlab.selene.tv.core.data.storage

/**
 * TV 本地数据库占位。
 */
class TvDatabase {
    /**
     * 数据库是否已经初始化。
     *
     * @return 当前占位实现始终返回 true。
     */
    fun isReady(): Boolean {
        // 后续接入 Room 后，这里会收敛历史、收藏和播放记录 DAO。
        return true
    }
}
