package org.moontechlab.selene.feature.player

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.moontechlab.selene.core.datastore.FavoriteItem
import org.moontechlab.selene.core.datastore.FavoritesRepository
import org.moontechlab.selene.core.datastore.PlaybackHistoryItem
import org.moontechlab.selene.core.datastore.PlaybackHistoryRepository
import org.moontechlab.selene.core.download.DownloadsRepository
import org.moontechlab.selene.core.model.VideoEpisode
import org.moontechlab.selene.core.player.AndroidVideoPlayerEngine

class PlayerViewModel(
    private val engine: AndroidVideoPlayerEngine = AndroidVideoPlayerEngine(),
    private val favoritesRepository: FavoritesRepository = FavoritesRepository(),
    private val historyRepository: PlaybackHistoryRepository = PlaybackHistoryRepository(),
    private val downloadsRepository: DownloadsRepository = DownloadsRepository(),
) : ViewModel() {
    private val mutableUiState = MutableStateFlow(PlayerUiState())
    val uiState = mutableUiState.asStateFlow()
    private var currentVideoId: String = ""
    private var currentVideoTitle: String = ""
    private var currentSourceKey: String = ""
    private var currentSourceName: String = ""
    private var currentEpisodeTitle: String = ""
    private var currentPlayUrl: String = ""

    fun loadEpisode(
        videoId: String,
        title: String,
        sourceKey: String = "",
        sourceName: String = "",
        episode: VideoEpisode,
    ) {
        engine.load(episode.playUrl)
        currentVideoId = videoId
        currentVideoTitle = title
        currentSourceKey = sourceKey
        currentSourceName = sourceName
        currentEpisodeTitle = episode.title
        currentPlayUrl = episode.playUrl
        historyRepository.record(
            PlaybackHistoryItem(
                videoId = videoId,
                title = title,
                sourceKey = sourceKey,
                sourceName = sourceName,
                episodeTitle = episode.title,
                playUrl = episode.playUrl,
                progressPercent = 0,
            ),
        )
        mutableUiState.value = PlayerUiState(
            title = "$title - ${episode.title}",
            isPlaying = false,
            currentUrl = episode.playUrl,
            isFavorite = favoritesRepository.isFavorite(videoId),
            hasDownloadTask = downloadsRepository.hasTask(videoId, episode.playUrl),
        )
    }

    fun play() {
        engine.play()
        mutableUiState.value = mutableUiState.value.copy(isPlaying = true)
    }

    fun pause() {
        engine.pause()
        mutableUiState.value = mutableUiState.value.copy(isPlaying = false)
    }

    fun toggleFavorite() {
        if (currentVideoId.isBlank()) return
        favoritesRepository.toggle(
            FavoriteItem(
                videoId = currentVideoId,
                title = currentVideoTitle,
                sourceKey = currentSourceKey,
                sourceName = currentSourceName.ifBlank { "播放器" },
                subtitle = currentEpisodeTitle,
            ),
        )
        mutableUiState.value = mutableUiState.value.copy(
            isFavorite = favoritesRepository.isFavorite(currentVideoId),
        )
    }

    fun addDownload() {
        if (currentVideoId.isBlank() || currentPlayUrl.isBlank()) return
        downloadsRepository.addTask(
            videoId = currentVideoId,
            title = currentVideoTitle,
            episodeTitle = currentEpisodeTitle,
            playUrl = currentPlayUrl,
        )
        mutableUiState.value = mutableUiState.value.copy(hasDownloadTask = true)
    }
}
