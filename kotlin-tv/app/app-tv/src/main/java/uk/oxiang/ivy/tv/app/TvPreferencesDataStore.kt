package uk.oxiang.ivy.tv.app

import android.content.Context
import androidx.datastore.preferences.preferencesDataStore

/** TV 偏好存储 DataStore 文件名。 */
private const val TV_PREFERENCES_DATASTORE_NAME = "tv_preferences"

/**
 * TV 偏好存储 DataStore 单例扩展属性。
 *
 * 由 [MainActivity] 在应用启动时读取，注入到 [TvAppContainer]，
 * 确保全应用生命周期内只持有一份 DataStore 实例。
 */
val Context.tvPreferencesDataStore by preferencesDataStore(name = TV_PREFERENCES_DATASTORE_NAME)
