package org.moontechlab.selene.core.player

interface VideoPlayerEngine {
    fun load(url: String)
    fun play()
    fun pause()
    fun seekTo(positionMs: Long)
}
