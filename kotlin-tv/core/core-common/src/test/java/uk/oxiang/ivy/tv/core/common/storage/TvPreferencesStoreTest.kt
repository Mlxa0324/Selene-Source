package uk.oxiang.ivy.tv.core.common.storage

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Test
import java.io.File

/**
 * [TvPreferencesStore] 契约测试：三维独立主题 key 默认值/读写往返、
 * 服务器会话与弹幕手动匹配记录的持久化往返。
 *
 * 使用临时文件 DataStore 作为测试替身，验证真实的序列化/反序列化路径，
 * 而不是内存 Map 模拟。
 */
class TvPreferencesStoreTest {

    private lateinit var tempFile: File
    private lateinit var store: TvPreferencesStore

    @Before
    fun setUp() {
        tempFile = File.createTempFile("tv_preferences_test", ".preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            produceFile = { tempFile },
        )
        store = TvPreferencesStore(dataStore)
    }

    @After
    fun tearDown() {
        tempFile.delete()
    }

    @Test
    fun themePaletteKeyFlow_defaultsToNetflixRed_whenNeverSaved() = runTest {
        val value = store.themePaletteKeyFlow().first()

        assertThat(value).isEqualTo("netflix_red")
    }

    @Test
    fun themeBackgroundKeyFlow_defaultsToDeepBlue_whenNeverSaved() = runTest {
        val value = store.themeBackgroundKeyFlow().first()

        assertThat(value).isEqualTo("deep_blue")
    }

    @Test
    fun focusEffectModeKeyFlow_defaultsToMagnifier_whenNeverSaved() = runTest {
        val value = store.focusEffectModeKeyFlow().first()

        assertThat(value).isEqualTo("magnifier")
    }

    @Test
    fun threeThemeDimensions_persistIndependently_andRoundTrip() = runTest {
        store.saveThemePaletteKey("soft_blue")
        store.saveThemeBackgroundKey("deep_black")
        store.saveFocusEffectModeKey("smooth_frame")

        assertThat(store.themePaletteKeyFlow().first()).isEqualTo("soft_blue")
        assertThat(store.themeBackgroundKeyFlow().first()).isEqualTo("deep_black")
        assertThat(store.focusEffectModeKeyFlow().first()).isEqualTo("smooth_frame")
    }

    @Test
    fun session_roundTrips_throughSaveAndLoad() = runTest {
        assertThat(store.loadSession()).isNull()

        store.saveSession(baseUrl = "https://example.com", account = "admin", cookie = "session=abc123")

        val loaded = store.loadSession()
        assertThat(loaded).isNotNull()
        assertThat(loaded!!.baseUrl).isEqualTo("https://example.com")
        assertThat(loaded.account).isEqualTo("admin")
        assertThat(loaded.cookie).isEqualTo("session=abc123")
    }

    @Test
    fun danmakuManualMatch_roundTrips_andIsAddressableByCompositeKey() = runTest {
        val record = TvDanmakuManualMatchRecord(
            source = "vod1",
            videoId = "abc123",
            episodeIndex = 2,
            episodeId = 999,
            searchKeyword = "手动匹配词",
        )

        store.saveDanmakuManualMatch(record)

        val loaded = store.getDanmakuManualMatch(source = "vod1", videoId = "abc123", episodeIndex = 2)
        assertThat(loaded).isEqualTo(record)

        val missing = store.getDanmakuManualMatch(source = "vod1", videoId = "abc123", episodeIndex = 3)
        assertThat(missing).isNull()
    }

    @Test
    fun danmakuTitleQuery_roundTrips_andIsCaseAndWhitespaceInsensitive() = runTest {
        store.saveLastDanmakuManualMatchQueryForTitle(title = "  Test Title  ", searchKeyword = "关键词")

        val loaded = store.getLastDanmakuManualMatchQueryForTitle("test title")

        assertThat(loaded).isEqualTo("关键词")
    }
}
