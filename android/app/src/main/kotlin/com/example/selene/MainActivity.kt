package org.moontechlab.selene

import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.Intent
import android.content.res.Configuration
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val tag = "PipControls"
    private val backgroundChannel = "org.moontechlab.selene/background_download"
    private val pipControlChannelName = "org.moontechlab.selene/pip_controls"
    private val mediaSessionChannelName = "org.moontechlab.selene/media_session"
    private val sleepTimerChannelName = "org.moontechlab.selene/sleep_timer"

    private lateinit var pipControlChannel: MethodChannel
    private lateinit var mediaSessionChannel: MethodChannel
    private var pipIsPlaying: Boolean = true
    private var pipHasPrevious: Boolean = false
    private var pipHasNext: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backgroundChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startForegroundDownloadService" -> {
                        val downloadingCount =
                            call.argument<Int>("downloadingCount") ?: 0
                        val queuedCount = call.argument<Int>("queuedCount") ?: 0
                        startForegroundDownloadService(downloadingCount, queuedCount)
                        result.success(true)
                    }

                    "stopForegroundDownloadService" -> {
                        stopForegroundDownloadService()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, sleepTimerChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "closeApp" -> {
                        runOnUiThread {
                            result.success(true)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                finishAndRemoveTask()
                            } else {
                                finishAffinity()
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        pipControlChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipControlChannelName)
        pipControlChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updatePipActions" -> {
                    pipIsPlaying = call.argument<Boolean>("isPlaying") ?: pipIsPlaying
                    pipHasPrevious = call.argument<Boolean>("hasPrevious") ?: pipHasPrevious
                    pipHasNext = call.argument<Boolean>("hasNext") ?: pipHasNext
                    updatePipActions()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        mediaSessionChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaSessionChannelName)
        mediaSessionChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "syncMediaSession" -> {
                    val arguments = call.arguments as? Map<*, *>
                    if (arguments == null) {
                        result.error("invalid_args", "缺少媒体会话参数", null)
                        return@setMethodCallHandler
                    }
                    MediaPlaybackService.syncSession(
                        context = this,
                        title = arguments["title"]?.toString().orEmpty(),
                        subtitle = arguments["subtitle"]?.toString().orEmpty(),
                        artworkUrl = arguments["artworkUrl"]?.toString(),
                        durationMs = (arguments["durationMs"] as? Number)?.toLong() ?: 0L,
                        positionMs = (arguments["positionMs"] as? Number)?.toLong() ?: 0L,
                        isPlaying = arguments["isPlaying"] as? Boolean ?: false,
                        hasPrevious = arguments["hasPrevious"] as? Boolean ?: false,
                        hasNext = arguments["hasNext"] as? Boolean ?: false,
                    )
                    result.success(true)
                }

                "stopMediaSession" -> {
                    MediaPlaybackService.stopSession(this)
                    result.success(true)
                }

                "startBackgroundPlayback" -> {
                    val arguments = call.arguments as? Map<*, *>
                    if (arguments == null) {
                        result.error("invalid_args", "缺少后台播放参数", null)
                        return@setMethodCallHandler
                    }
                    val rawHeaders = arguments["headers"] as? Map<*, *> ?: emptyMap<Any?, Any?>()
                    val headers = rawHeaders.entries.mapNotNull { entry ->
                        val key = entry.key?.toString()?.trim().orEmpty()
                        val value = entry.value?.toString()?.trim().orEmpty()
                        if (key.isEmpty()) {
                            null
                        } else {
                            key to value
                        }
                    }.toMap()
                    MediaPlaybackService.startBackgroundPlayback(
                        context = this,
                        title = arguments["title"]?.toString().orEmpty(),
                        subtitle = arguments["subtitle"]?.toString().orEmpty(),
                        artworkUrl = arguments["artworkUrl"]?.toString(),
                        url = arguments["url"]?.toString().orEmpty(),
                        headers = headers,
                        durationMs = (arguments["durationMs"] as? Number)?.toLong() ?: 0L,
                        positionMs = (arguments["positionMs"] as? Number)?.toLong() ?: 0L,
                        speed = (arguments["speed"] as? Number)?.toFloat() ?: 1.0f,
                    )
                    result.success(true)
                }

                "stopBackgroundPlayback" -> {
                    MediaPlaybackService.stop(this)
                    result.success(true)
                }

                "getBackgroundPlaybackState" -> {
                    result.success(MediaPlaybackService.getPlaybackState())
                }

                else -> result.notImplemented()
            }
        }

        setPipActionHandler { rawAction ->
            when (rawAction) {
                ACTION_PIP_PREVIOUS -> {
                    sendPipActionToFlutter("previous")
                }

                ACTION_PIP_PLAY_PAUSE -> {
                    pipIsPlaying = !pipIsPlaying
                    updatePipActions()
                    sendPipActionToFlutter("toggle_play_pause")
                }

                ACTION_PIP_NEXT -> {
                    sendPipActionToFlutter("next")
                }

                else -> {
                    Log.d(tag, "收到未知 PiP 动作: $rawAction")
                }
            }
        }

        setMediaSessionActionHandler { action, positionMs ->
            sendMediaSessionActionToFlutter(action, positionMs)
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        if (isInPictureInPictureMode) {
            Log.d(tag, "进入 PiP，保持 Flutter 生命周期为 resumed")
            flutterEngine?.lifecycleChannel?.appIsResumed()
        }
    }

    private fun startForegroundDownloadService(downloadingCount: Int, queuedCount: Int) {
        val intent = Intent(this, DownloadForegroundService::class.java).apply {
            action = DownloadForegroundService.ACTION_START_OR_UPDATE
            putExtra(DownloadForegroundService.EXTRA_DOWNLOADING_COUNT, downloadingCount)
            putExtra(DownloadForegroundService.EXTRA_QUEUED_COUNT, queuedCount)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(this, intent)
        } else {
            startService(intent)
        }
    }

    private fun stopForegroundDownloadService() {
        val intent = Intent(this, DownloadForegroundService::class.java).apply {
            action = DownloadForegroundService.ACTION_STOP
        }
        startService(intent)
    }

    private fun sendPipActionToFlutter(action: String) {
        Log.d(tag, "回调 Flutter PiP 动作: $action")
        pipControlChannel.invokeMethod("onPipAction", mapOf("action" to action))
    }

    private fun sendMediaSessionActionToFlutter(action: String, positionMs: Long?) {
        val payload = mutableMapOf<String, Any>("action" to action)
        if (positionMs != null && positionMs >= 0L) {
            payload["positionMs"] = positionMs
        }
        runOnUiThread {
            Log.d(tag, "回调 Flutter 媒体动作: $action, position=$positionMs")
            mediaSessionChannel.invokeMethod("onMediaSessionAction", payload)
        }
    }

    private fun createPipAction(
        requestCode: Int,
        intentAction: String,
        title: String,
        iconResId: Int,
    ): RemoteAction {
        val intent = Intent(this, PipActionReceiver::class.java).apply {
            action = intentAction
            `package` = packageName
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(this, requestCode, intent, flags)
        return RemoteAction(
            Icon.createWithResource(this, iconResId),
            title,
            title,
            pendingIntent,
        )
    }

    private fun updatePipActions() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val actions = mutableListOf<RemoteAction>()
        if (pipHasPrevious) {
            actions += createPipAction(
                requestCode = 1001,
                intentAction = ACTION_PIP_PREVIOUS,
                title = "上一集",
                iconResId = android.R.drawable.ic_media_previous,
            )
        }

        actions += createPipAction(
            requestCode = 1002,
            intentAction = ACTION_PIP_PLAY_PAUSE,
            title = if (pipIsPlaying) "暂停" else "播放",
            iconResId = if (pipIsPlaying) {
                android.R.drawable.ic_media_pause
            } else {
                android.R.drawable.ic_media_play
            },
        )

        if (pipHasNext) {
            actions += createPipAction(
                requestCode = 1003,
                intentAction = ACTION_PIP_NEXT,
                title = "下一集",
                iconResId = android.R.drawable.ic_media_next,
            )
        }

        val paramsBuilder = PictureInPictureParams.Builder().setActions(actions)
        setPictureInPictureParams(paramsBuilder.build())
    }

    companion object {
        private const val ACTION_PIP_PREVIOUS = "org.moontechlab.selene.pip.action.PREVIOUS"
        private const val ACTION_PIP_PLAY_PAUSE = "org.moontechlab.selene.pip.action.PLAY_PAUSE"
        private const val ACTION_PIP_NEXT = "org.moontechlab.selene.pip.action.NEXT"
        @Volatile
        private var pipActionHandler: ((String) -> Unit)? = null
        @Volatile
        private var mediaSessionActionHandler: ((String, Long?) -> Unit)? = null

        private fun setPipActionHandler(handler: ((String) -> Unit)?) {
            pipActionHandler = handler
        }

        private fun setMediaSessionActionHandler(handler: ((String, Long?) -> Unit)?) {
            mediaSessionActionHandler = handler
        }

        fun dispatchPipActionFromReceiver(action: String) {
            pipActionHandler?.invoke(action)
                ?: Log.d("PipControls", "PiP 动作丢弃，当前无可用 Handler: $action")
        }

        fun dispatchMediaSessionActionFromService(action: String, positionMs: Long? = null) {
            mediaSessionActionHandler?.invoke(action, positionMs)
                ?: Log.d(
                    "PipControls",
                    "媒体动作丢弃，当前无可用 Handler: $action, position=$positionMs",
                )
        }
    }

    override fun onDestroy() {
        setPipActionHandler(null)
        setMediaSessionActionHandler(null)
        super.onDestroy()
    }
}
