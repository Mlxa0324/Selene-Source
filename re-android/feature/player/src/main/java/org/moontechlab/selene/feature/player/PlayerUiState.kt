package org.moontechlab.selene.feature.player

data class PlayerUiState(
    val title: String = "播放器",
    val isPlaying: Boolean = false,
    val currentUrl: String = "",
    val isFavorite: Boolean = false,
    val hasDownloadTask: Boolean = false,
)
