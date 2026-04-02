package org.moontechlab.selene.app

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.navigation.compose.rememberNavController
import org.moontechlab.selene.app.navigation.SeleneNavGraph
import org.moontechlab.selene.core.datastore.AppPreferencesRepository
import org.moontechlab.selene.core.datastore.SharedPreferencesAppPreferencesPersistence
import org.moontechlab.selene.core.ui.theme.SeleneTheme

@Composable
fun SeleneApp() {
    val context = LocalContext.current.applicationContext
    val navController = rememberNavController()
    val preferencesRepository = remember(context) {
        AppPreferencesRepository(
            persistence = SharedPreferencesAppPreferencesPersistence.fromContext(context),
        )
    }
    val preferences by preferencesRepository.preferences.collectAsState()
    SeleneTheme(darkTheme = preferences.darkTheme) {
        Surface(color = MaterialTheme.colorScheme.background) {
            SeleneNavGraph(
                navController = navController,
                preferencesRepository = preferencesRepository,
            )
        }
    }
}
