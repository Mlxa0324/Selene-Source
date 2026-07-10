package uk.oxiang.ivy.tv.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent

/**
 * TV 应用唯一入口 Activity。
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val appContainer = TvAppContainer(
            gatewayConfig = TvLocalGatewayConfig.fromBuildConfig(),
            dataStore = applicationContext.tvPreferencesDataStore,
        )
        setContent {
            TvApp(appContainer = appContainer)
        }
    }
}
