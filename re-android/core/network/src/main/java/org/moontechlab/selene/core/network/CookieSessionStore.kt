package org.moontechlab.selene.core.network

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class CookieSession(
    val baseUrl: String,
    val cookie: String,
    val isLocalMode: Boolean,
)

interface SessionPersistence {
    fun restore(): CookieSession?
    fun persist(session: CookieSession?)
}

private object NoOpSessionPersistence : SessionPersistence {
    override fun restore(): CookieSession? = null

    override fun persist(session: CookieSession?) = Unit
}

class SharedPreferencesSessionPersistence(
    private val sharedPreferences: SharedPreferences,
) : SessionPersistence {
    override fun restore(): CookieSession? {
        val baseUrl = sharedPreferences.getString(KEY_BASE_URL, "") ?: ""
        val cookie = sharedPreferences.getString(KEY_COOKIE, "") ?: ""
        val isLocalMode = sharedPreferences.getBoolean(KEY_LOCAL_MODE, false)
        if (baseUrl.isBlank() && cookie.isBlank() && !isLocalMode) {
            return null
        }
        return CookieSession(
            baseUrl = baseUrl,
            cookie = cookie,
            isLocalMode = isLocalMode,
        )
    }

    override fun persist(session: CookieSession?) {
        sharedPreferences.edit().apply {
            if (session == null) {
                clear()
            } else {
                putString(KEY_BASE_URL, session.baseUrl)
                putString(KEY_COOKIE, session.cookie)
                putBoolean(KEY_LOCAL_MODE, session.isLocalMode)
            }
        }.apply()
    }

    companion object {
        private const val PREFERENCES_NAME = "selene_session"
        private const val KEY_BASE_URL = "base_url"
        private const val KEY_COOKIE = "cookie"
        private const val KEY_LOCAL_MODE = "local_mode"

        fun fromContext(context: Context): SharedPreferencesSessionPersistence {
            val sharedPreferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            return SharedPreferencesSessionPersistence(sharedPreferences = sharedPreferences)
        }
    }
}

class CookieSessionStore(
    private val persistence: SessionPersistence = NoOpSessionPersistence,
) {
    private val sessionState = MutableStateFlow(persistence.restore())

    val session: StateFlow<CookieSession?> = sessionState.asStateFlow()

    suspend fun save(
        baseUrl: String,
        cookie: String,
        isLocalMode: Boolean,
    ) {
        sessionState.value = CookieSession(
            baseUrl = baseUrl,
            cookie = cookie,
            isLocalMode = isLocalMode,
        )
        persistence.persist(sessionState.value)
    }

    suspend fun clear() {
        sessionState.value = null
        persistence.persist(null)
    }

    fun currentSession(): CookieSession? = sessionState.value

    fun hasValidSession(): Boolean {
        val current = sessionState.value ?: return false
        return current.isLocalMode || (current.baseUrl.isNotBlank() && current.cookie.isNotBlank())
    }
}
