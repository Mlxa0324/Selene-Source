package org.moontechlab.selene

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import java.net.HttpURLConnection
import java.net.URL

data class MediaPlaybackNotificationState(
    val title: String,
    val subtitle: String,
    val artworkUrl: String?,
    val url: String,
    val headers: Map<String, String>,
    val durationMs: Long,
    val positionMs: Long,
    val speed: Float,
    val hasPrevious: Boolean,
    val hasNext: Boolean,
    val isPlaying: Boolean,
    val isActive: Boolean,
    val controlsFlutterOnly: Boolean,
)

class MediaPlaybackService : Service() {
    private lateinit var mediaSession: MediaSessionCompat
    private var player: ExoPlayer? = null
    private var currentState = defaultPlaybackState()
    private var playbackPhase: String = PHASE_IDLE
    private var lastErrorCode: String? = null
    private var lastErrorMessage: String? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var artworkBitmap: Bitmap? = null
    private var artworkLoadVersion: Int = 0
    private var lastArtworkUrl: String? = null

    private val playerListener = object : Player.Listener {
        override fun onIsPlayingChanged(isPlaying: Boolean) {
            if (isPlaying) {
                playbackPhase = PHASE_READY
                lastErrorCode = null
                lastErrorMessage = null
                android.util.Log.d(LOG_TAG, "onIsPlayingChanged=true")
            }
            syncStateFromPlayer(forceNotificationUpdate = true)
        }

        override fun onPlaybackStateChanged(playbackState: Int) {
            when (playbackState) {
                Player.STATE_BUFFERING -> {
                    android.util.Log.d(LOG_TAG, "player state=BUFFERING")
                }

                Player.STATE_READY -> {
                    android.util.Log.d(
                        LOG_TAG,
                        "player state=READY playWhenReady=${player?.playWhenReady} isPlaying=${player?.isPlaying}",
                    )
                    if (player?.playWhenReady == true) {
                        playbackPhase = PHASE_READY
                        lastErrorCode = null
                        lastErrorMessage = null
                    }
                }

                Player.STATE_ENDED -> {
                    currentState = currentState.copy(isPlaying = false)
                    android.util.Log.d(LOG_TAG, "player state=ENDED")
                }
            }
            syncStateFromPlayer(forceNotificationUpdate = true)
        }

        override fun onPlayerError(error: PlaybackException) {
            playbackPhase = PHASE_ERROR
            lastErrorCode = error.errorCodeName
            lastErrorMessage = error.message ?: error.cause?.message
            android.util.Log.e(
                LOG_TAG,
                "onPlayerError code=${error.errorCodeName} message=${error.message}",
                error,
            )
            currentState = currentState.copy(
                isActive = false,
                isPlaying = false,
            )
            updateMediaSessionState()
            updateCachedPlaybackState()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    override fun onCreate() {
        super.onCreate()
        runningService = this
        mediaSession = MediaSessionCompat(this, "SeleneMediaSession").apply {
            setFlags(
                MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                    MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS,
            )
            setCallback(
                object : MediaSessionCompat.Callback() {
                    override fun onPlay() {
                        handleTransportAction(ACTION_MEDIA_PLAY, null)
                    }

                    override fun onPause() {
                        handleTransportAction(ACTION_MEDIA_PAUSE, null)
                    }

                    override fun onSeekTo(pos: Long) {
                        handleTransportAction(ACTION_MEDIA_SEEK, pos)
                    }
                },
            )
            isActive = true
        }
        createNotificationChannelIfNeeded()
        updateMediaSessionState()
        updateCachedPlaybackState()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_BACKGROUND_PLAYBACK -> {
                currentState = currentStateFromBackgroundIntent(intent).copy(isActive = true)
                playbackPhase = PHASE_STARTING
                lastErrorCode = null
                lastErrorMessage = null
                android.util.Log.d(
                    LOG_TAG,
                    "start background playback url=${currentState.url.take(120)} hasHeaders=${currentState.headers.isNotEmpty()} position=${currentState.positionMs} speed=${currentState.speed}",
                )
                refreshArtworkIfNeeded()
                updateCachedPlaybackState()
                startForeground(NOTIFICATION_ID, buildNotification())
                startPlaybackFromCurrentState()
                return START_STICKY
            }

            ACTION_SYNC_SESSION -> {
                currentState = currentStateFromSyncIntent(intent).copy(
                    isActive = true,
                    controlsFlutterOnly = true,
                )
                refreshArtworkIfNeeded()
                updateMediaSessionState()
                updateCachedPlaybackState()
                startForeground(NOTIFICATION_ID, buildNotification())
                return START_STICKY
            }

            ACTION_STOP -> {
                stopPlaybackAndService()
                return START_NOT_STICKY
            }

            ACTION_STOP_SESSION -> {
                stopSessionOnly()
                return START_NOT_STICKY
            }

            ACTION_MEDIA_PLAY,
            ACTION_MEDIA_PAUSE,
            ACTION_MEDIA_TOGGLE_PLAY_PAUSE,
            ACTION_MEDIA_PREVIOUS,
            ACTION_MEDIA_NEXT,
            ACTION_MEDIA_SEEK,
            -> {
                handleTransportAction(
                    action = intent.action ?: "",
                    positionMs = intent.getLongExtra(EXTRA_POSITION_MS, -1L)
                        .takeIf { it >= 0L },
                )
                return START_STICKY
            }

            else -> {
                if (currentState.isActive) {
                    startForeground(NOTIFICATION_ID, buildNotification())
                    return START_STICKY
                }
                return START_NOT_STICKY
            }
        }
    }

    override fun onDestroy() {
        player?.removeListener(playerListener)
        player?.release()
        player = null
        mediaSession.release()
        currentState = defaultPlaybackState()
        playbackPhase = PHASE_IDLE
        lastErrorCode = null
        lastErrorMessage = null
        artworkBitmap = null
        lastArtworkUrl = null
        updateCachedPlaybackState()
        runningService = null
        super.onDestroy()
    }

    private fun ensurePlayer(): ExoPlayer {
        player?.let { return it }
        val newPlayer = ExoPlayer.Builder(this).build().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                    .build(),
                true,
            )
            setHandleAudioBecomingNoisy(true)
            setWakeMode(C.WAKE_MODE_NETWORK)
            addListener(playerListener)
        }
        player = newPlayer
        return newPlayer
    }

    private fun startPlaybackFromCurrentState() {
        if (currentState.url.isBlank()) {
            stopPlaybackAndService()
            return
        }
        android.util.Log.d(
            LOG_TAG,
            "prepare media item host=${runCatching { android.net.Uri.parse(currentState.url).host }.getOrNull()} hasHeaders=${currentState.headers.isNotEmpty()}",
        )
        val exoPlayer = ensurePlayer()
        val dataSourceFactory = DefaultHttpDataSource.Factory()
            .setUserAgent("Selene")
            .setAllowCrossProtocolRedirects(true)
            .apply {
                if (currentState.headers.isNotEmpty()) {
                    setDefaultRequestProperties(currentState.headers)
                }
            }
        val mediaSourceFactory = DefaultMediaSourceFactory(dataSourceFactory)
        val mediaItem = MediaItem.Builder()
            .setUri(currentState.url)
            .build()
        exoPlayer.setMediaSource(mediaSourceFactory.createMediaSource(mediaItem))
        exoPlayer.setPlaybackParameters(
            PlaybackParameters(currentState.speed.coerceIn(0.5f, 3.0f)),
        )
        exoPlayer.prepare()
        if (currentState.positionMs > 0L) {
            exoPlayer.seekTo(currentState.positionMs)
        }
        exoPlayer.playWhenReady = true
        syncStateFromPlayer(forceNotificationUpdate = true)
    }

    private fun stopPlaybackAndService() {
        val exoPlayer = player
        if (exoPlayer != null) {
            currentState = currentState.copy(
                positionMs = exoPlayer.currentPosition.coerceAtLeast(0L),
                durationMs = resolveDurationMs(exoPlayer),
                isPlaying = false,
                isActive = false,
            )
            exoPlayer.pause()
            exoPlayer.stop()
            exoPlayer.clearMediaItems()
        } else {
            currentState = currentState.copy(
                isPlaying = false,
                isActive = false,
            )
        }
        playbackPhase = PHASE_IDLE
        lastErrorCode = null
        lastErrorMessage = null
        updateMediaSessionState()
        updateCachedPlaybackState()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun stopSessionOnly() {
        if (!currentState.controlsFlutterOnly) {
            return
        }
        currentState = defaultPlaybackState()
        playbackPhase = PHASE_IDLE
        lastErrorCode = null
        lastErrorMessage = null
        updateMediaSessionState()
        updateCachedPlaybackState()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun handleTransportAction(action: String, positionMs: Long?) {
        val exoPlayer = player
        if (currentState.controlsFlutterOnly || exoPlayer == null) {
            currentState = when (action) {
                ACTION_MEDIA_PLAY -> currentState.copy(isPlaying = true)
                ACTION_MEDIA_PAUSE -> currentState.copy(isPlaying = false)
                ACTION_MEDIA_TOGGLE_PLAY_PAUSE -> currentState.copy(
                    isPlaying = !currentState.isPlaying,
                )
                ACTION_MEDIA_PREVIOUS,
                ACTION_MEDIA_NEXT,
                -> currentState
                ACTION_MEDIA_SEEK -> currentState.copy(
                    positionMs = (positionMs ?: currentState.positionMs).coerceAtLeast(0L),
                )
                else -> currentState
            }
            updateMediaSessionState()
            updateCachedPlaybackState()
            MainActivity.dispatchMediaSessionActionFromService(
                action = actionNameForFlutter(action),
                positionMs = positionMs,
            )
            startForeground(NOTIFICATION_ID, buildNotification())
            return
        }
        when (action) {
            ACTION_MEDIA_PLAY -> exoPlayer.play()
            ACTION_MEDIA_PAUSE -> exoPlayer.pause()
            ACTION_MEDIA_TOGGLE_PLAY_PAUSE -> {
                if (exoPlayer.isPlaying) {
                    exoPlayer.pause()
                } else {
                    exoPlayer.play()
                }
            }

            ACTION_MEDIA_SEEK -> {
                positionMs?.let { exoPlayer.seekTo(it.coerceAtLeast(0L)) }
            }
        }
        syncStateFromPlayer(forceNotificationUpdate = true)
    }

    private fun syncStateFromPlayer(forceNotificationUpdate: Boolean) {
        val exoPlayer = player
        currentState = currentState.copy(
            durationMs = resolveDurationMs(exoPlayer),
            positionMs = exoPlayer?.currentPosition?.coerceAtLeast(0L)
                ?: currentState.positionMs,
            isPlaying = exoPlayer?.isPlaying ?: currentState.isPlaying,
            isActive = currentState.isActive,
        )
        updateMediaSessionState()
        updateCachedPlaybackState()
        if (currentState.isActive && forceNotificationUpdate) {
            startForeground(NOTIFICATION_ID, buildNotification())
        }
    }

    private fun updateCachedPlaybackState() {
        cachedPlaybackState = mapOf(
            "isActive" to currentState.isActive,
            "isPlaying" to currentState.isPlaying,
            "positionMs" to currentState.positionMs,
            "durationMs" to currentState.durationMs,
            "phase" to playbackPhase,
            "errorCode" to lastErrorCode,
            "errorMessage" to lastErrorMessage,
        )
    }

    private fun updateMediaSessionState() {
        val playbackActions = PlaybackStateCompat.ACTION_PLAY or
            PlaybackStateCompat.ACTION_PAUSE or
            PlaybackStateCompat.ACTION_PLAY_PAUSE or
            PlaybackStateCompat.ACTION_SEEK_TO
        var resolvedActions = playbackActions
        if (currentState.hasPrevious) {
            resolvedActions = resolvedActions or PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
        }
        if (currentState.hasNext) {
            resolvedActions = resolvedActions or PlaybackStateCompat.ACTION_SKIP_TO_NEXT
        }
        val playbackState = PlaybackStateCompat.Builder()
            .setActions(resolvedActions)
            .setState(
                if (currentState.isPlaying) {
                    PlaybackStateCompat.STATE_PLAYING
                } else {
                    PlaybackStateCompat.STATE_PAUSED
                },
                currentState.positionMs,
                if (currentState.isPlaying) currentState.speed else 0.0f,
            )
            .build()
        mediaSession.setPlaybackState(playbackState)

        val metadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, currentState.title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, currentState.subtitle)
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_TITLE, currentState.title)
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE, currentState.subtitle)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, currentState.durationMs)
            .apply {
                currentState.artworkUrl?.takeIf { it.isNotBlank() }?.let { url ->
                    putString(MediaMetadataCompat.METADATA_KEY_ALBUM_ART_URI, url)
                    putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_ICON_URI, url)
                }
                artworkBitmap?.let { bitmap ->
                    putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, bitmap)
                    putBitmap(MediaMetadataCompat.METADATA_KEY_DISPLAY_ICON, bitmap)
                }
            }
            .build()
        mediaSession.setMetadata(metadata)
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val actions = mutableListOf<NotificationCompat.Action>()
        val compactIndices = mutableListOf<Int>()

        if (currentState.hasPrevious) {
            actions += NotificationCompat.Action(
                android.R.drawable.ic_media_previous,
                "上一集",
                createServicePendingIntent(ACTION_MEDIA_PREVIOUS),
            )
            compactIndices += actions.lastIndex
        }

        actions += NotificationCompat.Action(
            if (currentState.isPlaying) {
                android.R.drawable.ic_media_pause
            } else {
                android.R.drawable.ic_media_play
            },
            if (currentState.isPlaying) "暂停" else "播放",
            createServicePendingIntent(
                if (currentState.isPlaying) {
                    ACTION_MEDIA_PAUSE
                } else {
                    ACTION_MEDIA_PLAY
                },
            ),
        )
        compactIndices += actions.lastIndex

        if (currentState.hasNext) {
            actions += NotificationCompat.Action(
                android.R.drawable.ic_media_next,
                "下一集",
                createServicePendingIntent(ACTION_MEDIA_NEXT),
            )
        }

        actions += NotificationCompat.Action(
            android.R.drawable.ic_menu_close_clear_cancel,
            "关闭",
            createServicePendingIntent(
                if (currentState.controlsFlutterOnly) ACTION_STOP_SESSION else ACTION_STOP,
            ),
        )

        val style = androidx.media.app.NotificationCompat.MediaStyle()
            .setMediaSession(mediaSession.sessionToken)
            .setShowActionsInCompactView(*compactIndices.toIntArray())

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(currentState.title.ifBlank { "Selene" })
            .setContentText(
                currentState.subtitle.ifBlank {
                    if (currentState.isPlaying) "后台音频播放中" else "后台音频已暂停"
                },
            )
            .setSmallIcon(
                if (currentState.isPlaying) {
                    android.R.drawable.ic_media_play
                } else {
                    android.R.drawable.ic_media_pause
                },
            )
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setOnlyAlertOnce(true)
            .setOngoing(currentState.isPlaying)
            .setContentIntent(contentIntent)
            .setDeleteIntent(
                createServicePendingIntent(
                    if (currentState.controlsFlutterOnly) ACTION_STOP_SESSION else ACTION_STOP,
                ),
            )
            .setStyle(style)
            .apply {
                artworkBitmap?.let(::setLargeIcon)
            }

        actions.forEach(builder::addAction)
        return builder.build()
    }

    private fun createServicePendingIntent(
        action: String,
        positionMs: Long? = null,
    ): PendingIntent {
        val intent = Intent(this, MediaPlaybackService::class.java).apply {
            this.action = action
            positionMs?.let { putExtra(EXTRA_POSITION_MS, it) }
        }
        val requestCode = (action.hashCode() * 31) + (positionMs?.hashCode() ?: 0)
        return PendingIntent.getService(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createNotificationChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        val channel = manager.getNotificationChannel(CHANNEL_ID)
        if (channel != null) {
            return
        }
        val newChannel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "保持 Android 后台音频播放与锁屏控制"
            setShowBadge(false)
        }
        manager.createNotificationChannel(newChannel)
    }

    private fun currentStateFromBackgroundIntent(intent: Intent): MediaPlaybackNotificationState {
        return MediaPlaybackNotificationState(
            title = intent.getStringExtra(EXTRA_TITLE).orEmpty().ifBlank { "Selene" },
            subtitle = intent.getStringExtra(EXTRA_SUBTITLE).orEmpty(),
            artworkUrl = intent.getStringExtra(EXTRA_ARTWORK_URL),
            url = intent.getStringExtra(EXTRA_URL).orEmpty(),
            headers = readHeaders(intent),
            durationMs = intent.getLongExtra(EXTRA_DURATION_MS, 0L).coerceAtLeast(0L),
            positionMs = intent.getLongExtra(EXTRA_POSITION_MS, 0L).coerceAtLeast(0L),
            speed = intent.getFloatExtra(EXTRA_SPEED, 1.0f),
            hasPrevious = false,
            hasNext = false,
            isPlaying = true,
            isActive = true,
            controlsFlutterOnly = false,
        )
    }

    private fun currentStateFromSyncIntent(intent: Intent): MediaPlaybackNotificationState {
        return MediaPlaybackNotificationState(
            title = intent.getStringExtra(EXTRA_TITLE).orEmpty().ifBlank { "Selene" },
            subtitle = intent.getStringExtra(EXTRA_SUBTITLE).orEmpty(),
            artworkUrl = intent.getStringExtra(EXTRA_ARTWORK_URL),
            url = "",
            headers = emptyMap(),
            durationMs = intent.getLongExtra(EXTRA_DURATION_MS, 0L).coerceAtLeast(0L),
            positionMs = intent.getLongExtra(EXTRA_POSITION_MS, 0L).coerceAtLeast(0L),
            speed = 1.0f,
            hasPrevious = intent.getBooleanExtra(EXTRA_HAS_PREVIOUS, false),
            hasNext = intent.getBooleanExtra(EXTRA_HAS_NEXT, false),
            isPlaying = intent.getBooleanExtra(EXTRA_IS_PLAYING, false),
            isActive = true,
            controlsFlutterOnly = true,
        )
    }

    @Suppress("DEPRECATION")
    private fun readHeaders(intent: Intent): Map<String, String> {
        val rawHeaders = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getSerializableExtra(EXTRA_HEADERS, HashMap::class.java)
        } else {
            intent.getSerializableExtra(EXTRA_HEADERS) as? HashMap<*, *>
        }
        if (rawHeaders !is Map<*, *>) {
            return emptyMap()
        }
        return rawHeaders.entries.mapNotNull { entry ->
            val key = entry.key?.toString()?.trim().orEmpty()
            val value = entry.value?.toString()?.trim().orEmpty()
            if (key.isEmpty()) {
                null
            } else {
                key to value
            }
        }.toMap()
    }

    private fun resolveDurationMs(exoPlayer: ExoPlayer?): Long {
        val durationMs = exoPlayer?.duration ?: currentState.durationMs
        return if (durationMs == C.TIME_UNSET || durationMs < 0L) {
            currentState.durationMs
        } else {
            durationMs
        }
    }

    private fun refreshArtworkIfNeeded() {
        val artworkUrl = currentState.artworkUrl?.takeIf { it.isNotBlank() }
        if (artworkUrl == lastArtworkUrl) {
            return
        }
        lastArtworkUrl = artworkUrl
        artworkLoadVersion += 1
        val requestVersion = artworkLoadVersion
        if (artworkUrl == null) {
            artworkBitmap = null
            updateMediaSessionState()
            if (currentState.isActive) {
                startForeground(NOTIFICATION_ID, buildNotification())
            }
            return
        }
        Thread {
            val bitmap = fetchArtworkBitmap(artworkUrl)
            mainHandler.post {
                if (requestVersion != artworkLoadVersion) {
                    return@post
                }
                artworkBitmap = bitmap
                updateMediaSessionState()
                if (currentState.isActive) {
                    startForeground(NOTIFICATION_ID, buildNotification())
                }
            }
        }.start()
    }

    private fun fetchArtworkBitmap(artworkUrl: String): Bitmap? {
        return runCatching {
            val connection = (URL(artworkUrl).openConnection() as HttpURLConnection).apply {
                connectTimeout = 5000
                readTimeout = 5000
                instanceFollowRedirects = true
            }
            try {
                connection.inputStream.use { input ->
                    BitmapFactory.decodeStream(input)
                }
            } finally {
                connection.disconnect()
            }
        }.getOrNull()
    }

    companion object {
        const val ACTION_START_BACKGROUND_PLAYBACK =
            "org.moontechlab.selene.action.START_BACKGROUND_PLAYBACK"
        const val ACTION_SYNC_SESSION = "org.moontechlab.selene.action.SYNC_SESSION"
        const val ACTION_STOP = "org.moontechlab.selene.action.MEDIA_SESSION_STOP"
        const val ACTION_STOP_SESSION = "org.moontechlab.selene.action.MEDIA_SESSION_STOP_ONLY"
        const val ACTION_MEDIA_PLAY = "org.moontechlab.selene.action.MEDIA_PLAY"
        const val ACTION_MEDIA_PAUSE = "org.moontechlab.selene.action.MEDIA_PAUSE"
        const val ACTION_MEDIA_TOGGLE_PLAY_PAUSE =
            "org.moontechlab.selene.action.MEDIA_TOGGLE_PLAY_PAUSE"
        const val ACTION_MEDIA_PREVIOUS = "org.moontechlab.selene.action.MEDIA_PREVIOUS"
        const val ACTION_MEDIA_NEXT = "org.moontechlab.selene.action.MEDIA_NEXT"
        const val ACTION_MEDIA_SEEK = "org.moontechlab.selene.action.MEDIA_SEEK"

        const val EXTRA_TITLE = "title"
        const val EXTRA_SUBTITLE = "subtitle"
        const val EXTRA_ARTWORK_URL = "artworkUrl"
        const val EXTRA_URL = "url"
        const val EXTRA_HEADERS = "headers"
        const val EXTRA_DURATION_MS = "durationMs"
        const val EXTRA_POSITION_MS = "positionMs"
        const val EXTRA_SPEED = "speed"
        const val EXTRA_IS_PLAYING = "isPlaying"
        const val EXTRA_HAS_PREVIOUS = "hasPrevious"
        const val EXTRA_HAS_NEXT = "hasNext"

        private const val LOG_TAG = "ScreenOffPlayback"
        private const val CHANNEL_ID = "selene_media_playback_channel"
        private const val CHANNEL_NAME = "媒体播放"
        private const val NOTIFICATION_ID = 10087
        private const val PHASE_IDLE = "idle"
        private const val PHASE_STARTING = "starting"
        private const val PHASE_READY = "ready"
        private const val PHASE_ERROR = "error"

        @Volatile
        private var runningService: MediaPlaybackService? = null

        @Volatile
        private var cachedPlaybackState: Map<String, Any?> = mapOf(
            "isActive" to false,
            "isPlaying" to false,
            "positionMs" to 0L,
            "durationMs" to 0L,
            "phase" to PHASE_IDLE,
            "errorCode" to null,
            "errorMessage" to null,
        )

        fun syncSession(
            context: Context,
            title: String,
            subtitle: String,
            artworkUrl: String?,
            durationMs: Long,
            positionMs: Long,
            isPlaying: Boolean,
            hasPrevious: Boolean,
            hasNext: Boolean,
        ) {
            val intent = Intent(context, MediaPlaybackService::class.java).apply {
                action = ACTION_SYNC_SESSION
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_SUBTITLE, subtitle)
                putExtra(EXTRA_ARTWORK_URL, artworkUrl)
                putExtra(EXTRA_DURATION_MS, durationMs)
                putExtra(EXTRA_POSITION_MS, positionMs)
                putExtra(EXTRA_IS_PLAYING, isPlaying)
                putExtra(EXTRA_HAS_PREVIOUS, hasPrevious)
                putExtra(EXTRA_HAS_NEXT, hasNext)
            }
            startServiceCompat(context, intent)
        }

        fun startBackgroundPlayback(
            context: Context,
            title: String,
            subtitle: String,
            artworkUrl: String?,
            url: String,
            headers: Map<String, String>,
            durationMs: Long,
            positionMs: Long,
            speed: Float,
        ) {
            val intent = Intent(context, MediaPlaybackService::class.java).apply {
                action = ACTION_START_BACKGROUND_PLAYBACK
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_SUBTITLE, subtitle)
                putExtra(EXTRA_ARTWORK_URL, artworkUrl)
                putExtra(EXTRA_URL, url)
                putExtra(EXTRA_HEADERS, HashMap(headers))
                putExtra(EXTRA_DURATION_MS, durationMs)
                putExtra(EXTRA_POSITION_MS, positionMs)
                putExtra(EXTRA_SPEED, speed)
            }
            startServiceCompat(context, intent)
        }

        fun stopSession(context: Context) {
            val intent = Intent(context, MediaPlaybackService::class.java).apply {
                action = ACTION_STOP_SESSION
            }
            context.startService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, MediaPlaybackService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }

        fun getPlaybackState(): Map<String, Any?> {
            return runningService?.let { service ->
                val exoPlayer = service.player
                mapOf(
                    "isActive" to service.currentState.isActive,
                    "isPlaying" to (exoPlayer?.isPlaying ?: service.currentState.isPlaying),
                    "positionMs" to (exoPlayer?.currentPosition?.coerceAtLeast(0L)
                        ?: service.currentState.positionMs),
                    "durationMs" to service.resolveDurationMs(exoPlayer),
                    "phase" to service.playbackPhase,
                    "errorCode" to service.lastErrorCode,
                    "errorMessage" to service.lastErrorMessage,
                )
            } ?: cachedPlaybackState
        }

        private fun startServiceCompat(context: Context, intent: Intent) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(context, intent)
            } else {
                context.startService(intent)
            }
        }

        private fun defaultPlaybackState(): MediaPlaybackNotificationState {
            return MediaPlaybackNotificationState(
                title = "Selene",
                subtitle = "",
                artworkUrl = null,
                url = "",
                headers = emptyMap(),
                durationMs = 0L,
                positionMs = 0L,
                speed = 1.0f,
                hasPrevious = false,
                hasNext = false,
                isPlaying = false,
                isActive = false,
                controlsFlutterOnly = false,
            )
        }

        private fun actionNameForFlutter(action: String): String {
            return when (action) {
                ACTION_MEDIA_PLAY -> "play"
                ACTION_MEDIA_PAUSE -> "pause"
                ACTION_MEDIA_TOGGLE_PLAY_PAUSE -> "toggle_play_pause"
                ACTION_MEDIA_PREVIOUS -> "previous"
                ACTION_MEDIA_NEXT -> "next"
                ACTION_MEDIA_SEEK -> "seek"
                else -> action
            }
        }
    }
}
