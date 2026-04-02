package org.moontechlab.selene.core.player

class AndroidVideoPlayerEngine : VideoPlayerEngine {
    var currentUrl: String? = null
        private set

    var playing: Boolean = false
        private set

    var positionMs: Long = 0L
        private set

    override fun load(url: String) {
        currentUrl = url
        positionMs = 0L
    }

    override fun play() {
        playing = true
    }

    override fun pause() {
        playing = false
    }

    override fun seekTo(positionMs: Long) {
        this.positionMs = positionMs
    }
}
