package org.moontechlab.selene.tv.feature.player

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验 TV 全屏播放器底部缓存进度段计算。
 */
class TvPlayerCachedProgressTest {
    /**
     * 缓存段必须合并重叠区间并换算成进度比例。
     */
    @Test
    fun resolveCachedProgressSegments_merges_ranges_and_maps_to_fraction() {
        val segments = resolvePlayerCachedProgressSegments(
            cachedRanges = listOf(
                TvPlayerCachedRange(startMs = 10_000L, endMs = 30_000L),
                TvPlayerCachedRange(startMs = 20_000L, endMs = 50_000L),
            ),
            durationMs = 100_000L,
            positionMs = 0L,
        )

        assertThat(segments).containsExactly(
            TvPlayerCachedProgressSegment(startFraction = 0.1f, endFraction = 0.5f),
        )
    }

    /**
     * 缓存段展示范围必须截断到当前位置后 3 分钟，避免把远端预加载渲染成整条灰线。
     */
    @Test
    fun resolveCachedProgressSegments_caps_to_three_minutes_after_position() {
        val segments = resolvePlayerCachedProgressSegments(
            cachedRanges = listOf(
                TvPlayerCachedRange(startMs = 240_000L, endMs = 420_000L),
            ),
            durationMs = 600_000L,
            positionMs = 120_000L,
        )

        assertThat(segments).containsExactly(
            TvPlayerCachedProgressSegment(startFraction = 0.4f, endFraction = 0.5f),
        )
    }

    /**
     * 无效总时长或反向缓存区间不能产生可绘制分段。
     */
    @Test
    fun resolveCachedProgressSegments_drops_invalid_ranges() {
        val segments = resolvePlayerCachedProgressSegments(
            cachedRanges = listOf(
                TvPlayerCachedRange(startMs = 80_000L, endMs = 60_000L),
            ),
            durationMs = 0L,
            positionMs = 10_000L,
        )

        assertThat(segments).isEmpty()
    }
}
