package org.moontechlab.selene.core.network

import com.squareup.moshi.Json
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import org.moontechlab.selene.core.model.VideoCardModel
import org.moontechlab.selene.core.model.VideoDetail
import org.moontechlab.selene.core.model.VideoEpisode
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import retrofit2.http.GET
import retrofit2.http.Query

data class SearchResponseDto(
    @Json(name = "results") val results: List<RemoteVideoDto> = emptyList(),
    @Json(name = "pageResults") val pageResults: List<RemoteVideoDto> = emptyList(),
) {
    fun allResults(): List<RemoteVideoDto> = if (results.isNotEmpty()) results else pageResults
}

data class RemoteVideoDto(
    @Json(name = "id") val id: String = "",
    @Json(name = "title") val title: String = "",
    @Json(name = "url") val url: String = "",
    @Json(name = "poster") val poster: String = "",
    @Json(name = "episodes") val episodes: List<String> = emptyList(),
    @Json(name = "episodes_titles") val episodesTitles: List<String> = emptyList(),
    @Json(name = "source") val source: String = "",
    @Json(name = "source_name") val sourceName: String = "",
    @Json(name = "class") val className: String? = null,
    @Json(name = "year") val year: String = "",
    @Json(name = "desc") val desc: String? = null,
    @Json(name = "type_name") val typeName: String? = null,
    @Json(name = "douban_id") val doubanId: Int? = null,
) {
    fun toVideoCardModel(): VideoCardModel = VideoCardModel(
        id = id,
        title = title,
        posterUrl = poster,
        sourceKey = source,
        sourceName = sourceName,
        year = year.ifBlank { null },
        subtitle = buildCardSubtitle(),
    )

    fun toVideoDetail(): VideoDetail = VideoDetail(
        id = id,
        title = title,
        description = desc.orEmpty(),
        posterUrl = poster,
        sourceKey = source,
        sourceName = sourceName,
        year = year.ifBlank { null },
        typeName = typeLabel(),
        doubanId = doubanId,
        episodes = episodes.mapIndexed { index, playUrl ->
            VideoEpisode(
                index = index,
                title = episodesTitles.getOrElse(index) { "第${index + 1}集" },
                playUrl = playUrl,
            )
        },
    )

    private fun buildCardSubtitle(): String? {
        val parts = buildList {
            typeLabel()?.let(::add)
            if (episodes.isNotEmpty()) {
                add("共${episodes.size}集")
            }
        }
        return parts.takeIf { it.isNotEmpty() }?.joinToString(" · ")
    }

    private fun typeLabel(): String? = typeName?.takeIf { it.isNotBlank() } ?: className?.takeIf { it.isNotBlank() }
}

interface SeleneRemoteService {
    suspend fun search(query: String): SearchResponseDto
    suspend fun fetchDetail(sourceKey: String, videoId: String): RemoteVideoDto
}

fun interface SeleneRemoteServiceFactory {
    fun create(baseUrl: String, cookie: String): SeleneRemoteService
}

class RetrofitSeleneApi(
    private val sessionStore: CookieSessionStore,
    private val serviceFactory: SeleneRemoteServiceFactory = RetrofitSeleneRemoteServiceFactory(),
    private val fallbackApi: SeleneApi = DemoSeleneApi(),
) : SeleneApi {
    override suspend fun autoLogin(): Boolean = sessionStore.hasValidSession()

    override suspend fun search(query: String): List<VideoCardModel> {
        val session = sessionStore.currentSession() ?: return fallbackApi.search(query)
        if (session.isLocalMode) return fallbackApi.search(query)
        return serviceFactory
            .create(baseUrl = session.baseUrl, cookie = session.cookie)
            .search(query)
            .allResults()
            .map { it.toVideoCardModel() }
    }

    override suspend fun fetchDetail(videoId: String, sourceKey: String?): VideoDetail {
        val session = sessionStore.currentSession() ?: return fallbackApi.fetchDetail(videoId, sourceKey)
        if (session.isLocalMode || sourceKey.isNullOrBlank()) {
            return fallbackApi.fetchDetail(videoId, sourceKey)
        }
        return serviceFactory
            .create(baseUrl = session.baseUrl, cookie = session.cookie)
            .fetchDetail(sourceKey = sourceKey, videoId = videoId)
            .toVideoDetail()
    }
}

class RetrofitSeleneRemoteServiceFactory : SeleneRemoteServiceFactory {
    override fun create(baseUrl: String, cookie: String): SeleneRemoteService {
        val client = OkHttpClient.Builder()
            .addInterceptor(
                Interceptor { chain ->
                    val request = chain.request().newBuilder()
                        .header("Accept", "application/json")
                        .apply {
                            if (cookie.isNotBlank()) {
                                header("Cookie", cookie)
                            }
                        }
                        .build()
                    chain.proceed(request)
                },
            )
            .addInterceptor(
                HttpLoggingInterceptor().apply {
                    level = HttpLoggingInterceptor.Level.NONE
                },
            )
            .build()
        val moshi = Moshi.Builder()
            .addLast(KotlinJsonAdapterFactory())
            .build()
        val retrofit = Retrofit.Builder()
            .baseUrl(normalizeBaseUrl(baseUrl))
            .client(client)
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .build()
        val service = retrofit.create(RetrofitService::class.java)
        return object : SeleneRemoteService {
            override suspend fun search(query: String): SearchResponseDto = service.search(query)

            override suspend fun fetchDetail(sourceKey: String, videoId: String): RemoteVideoDto =
                service.fetchDetail(sourceKey = sourceKey, videoId = videoId)
        }
    }
}

private interface RetrofitService {
    @GET("api/search")
    suspend fun search(@Query("q") query: String): SearchResponseDto

    @GET("api/detail")
    suspend fun fetchDetail(
        @Query("source") sourceKey: String,
        @Query("id") videoId: String,
    ): RemoteVideoDto
}

private fun normalizeBaseUrl(baseUrl: String): String = buildString {
    append(baseUrl.trim().trimEnd('/'))
    append("/")
}
