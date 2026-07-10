package uk.oxiang.ivy.tv.core.design.focus

import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.geometry.Rect
import com.google.common.truth.Truth.assertThat
import org.junit.After
import org.junit.Test

/**
 * [TvFocusMemoryRegistry] 契约测试：焦点记忆分组与跨组方向跳转。
 *
 * 对齐 Flutter `TvFocusable` 静态分组能力：跨组上下方向移动时优先回到目标
 * 分组的记忆项，其次回退到分组内第一个可聚焦项。
 */
class TvFocusMemoryRegistryTest {

    private val registeredEntries = mutableListOf<TvFocusMemoryRegistry.Entry>()

    @After
    fun tearDown() {
        registeredEntries.forEach { entry -> TvFocusMemoryRegistry.unregister(entry) }
        registeredEntries.clear()
    }

    private fun registerEntry(groupKey: Any, rect: Rect): TvFocusMemoryRegistry.Entry {
        val entry = TvFocusMemoryRegistry.Entry(
            groupKey = groupKey,
            focusRequester = FocusRequester(),
            boundsProvider = { rect },
        )
        TvFocusMemoryRegistry.register(entry)
        registeredEntries.add(entry)
        return entry
    }

    @Test
    fun nearestRememberedGroupEntry_prefersLastFocusedItemInTargetGroup() {
        val groupKey = "rail-a"
        val firstItem = registerEntry(groupKey, Rect(0f, 100f, 100f, 200f))
        val secondItem = registerEntry(groupKey, Rect(120f, 100f, 220f, 200f))
        // 模拟用户曾经真实停留在第二张卡片上。
        TvFocusMemoryRegistry.onFocused(secondItem)
        TvFocusMemoryRegistry.onUnfocused(secondItem)

        val target = TvFocusMemoryRegistry.nearestRememberedGroupEntry(
            currentGroupKey = "other-group",
            currentRect = Rect(120f, 0f, 220f, 50f),
            direction = 1,
        )

        assertThat(target).isEqualTo(secondItem)
        assertThat(target).isNotEqualTo(firstItem)
    }

    @Test
    fun nearestRememberedGroupEntry_fallsBackToFirstFocusable_whenNoMemoryRecorded() {
        val groupKey = "rail-b"
        val firstItem = registerEntry(groupKey, Rect(0f, 100f, 100f, 200f))
        registerEntry(groupKey, Rect(120f, 100f, 220f, 200f))
        // 该分组从未真实获焦过，没有记忆条目。

        val target = TvFocusMemoryRegistry.nearestRememberedGroupEntry(
            currentGroupKey = "other-group",
            currentRect = Rect(0f, 0f, 100f, 50f),
            direction = 1,
        )

        assertThat(target).isEqualTo(firstItem)
    }

    @Test
    fun requestRememberedFocusForGroup_returnsFalse_whenGroupEmpty() {
        val requested = TvFocusMemoryRegistry.requestRememberedFocusForGroup("nonexistent-group")

        assertThat(requested).isFalse()
    }

    @Test
    fun groupHasFocusedChild_reflectsRealFocusState() {
        val groupKey = "rail-c"
        val entry = registerEntry(groupKey, Rect(0f, 0f, 100f, 100f))

        assertThat(TvFocusMemoryRegistry.groupHasFocusedChild(groupKey)).isFalse()

        TvFocusMemoryRegistry.onFocused(entry)
        assertThat(TvFocusMemoryRegistry.groupHasFocusedChild(groupKey)).isTrue()

        TvFocusMemoryRegistry.onUnfocused(entry)
        assertThat(TvFocusMemoryRegistry.groupHasFocusedChild(groupKey)).isFalse()
    }

    @Test
    fun clearLastFocusedForGroup_removesMemoryButKeepsRegisteredEntries() {
        val groupKey = "rail-d"
        val entry = registerEntry(groupKey, Rect(0f, 0f, 100f, 100f))
        TvFocusMemoryRegistry.onFocused(entry)
        TvFocusMemoryRegistry.onUnfocused(entry)

        TvFocusMemoryRegistry.clearLastFocusedForGroup(groupKey)

        val target = TvFocusMemoryRegistry.nearestRememberedGroupEntry(
            currentGroupKey = "other-group",
            currentRect = Rect(0f, -50f, 100f, 0f),
            direction = 1,
        )
        // 记忆被清空后应回退到分组内第一个可聚焦项，而不是抛异常或返回旧记忆。
        assertThat(target).isEqualTo(entry)
    }
}
