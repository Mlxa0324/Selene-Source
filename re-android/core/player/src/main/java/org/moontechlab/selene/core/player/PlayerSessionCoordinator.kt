package org.moontechlab.selene.core.player

data class PlayerSession(
    val detailId: String,
    val sourceKey: String,
    val episodeIndex: Int,
)

class PlayerSessionCoordinator {
    fun createSession(
        detailId: String,
        sourceKey: String,
        episodeIndex: Int,
    ): PlayerSession = PlayerSession(
        detailId = detailId,
        sourceKey = sourceKey,
        episodeIndex = episodeIndex,
    )
}
