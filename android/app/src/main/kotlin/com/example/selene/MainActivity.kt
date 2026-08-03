package org.moontechlab.selene

import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import android.os.StatFs
import android.provider.Settings
import android.util.Log
import android.view.OrientationEventListener
import android.view.Surface
import android.view.View
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val tag = "PipControls"
    private val backgroundChannel = "org.moontechlab.selene/background_download"
    private val pipControlChannelName = "org.moontechlab.selene/pip_controls"
    private val sleepTimerChannelName = "org.moontechlab.selene/sleep_timer"
    private val orientationChannelName = "selene/orientation"
    private val physicalOrientationChannelName = "selene/physical_orientation"
    private val deviceChannelName = "selene/device"
    private val storageChannelName = "selene/storage"

    private var pipControlChannel: MethodChannel? = null
    private var pipIsPlaying: Boolean = true
    private var pipHasPrevious: Boolean = false
    private var pipHasNext: Boolean = false
    private var physicalOrientationListener: OrientationEventListener? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        disableAndroidDefaultFocusHighlight()
    }

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, orientationChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSystemAutoRotateEnabled" -> {
                        val value = runCatching {
                            Settings.System.getInt(
                                contentResolver,
                                Settings.System.ACCELEROMETER_ROTATION,
                            ) == 1
                        }.getOrNull()
                        result.success(value)
                    }

                    "getCurrentInterfaceOrientation" -> {
                        result.success(resolveCurrentInterfaceOrientation())
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, physicalOrientationChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    physicalOrientationListener?.disable()
                    physicalOrientationListener =
                        object : OrientationEventListener(this@MainActivity) {
                            private var lastOrientation: String? = null

                            override fun onOrientationChanged(orientation: Int) {
                                val physicalOrientation =
                                    resolvePhysicalDeviceOrientation(orientation) ?: return
                                if (physicalOrientation == lastOrientation) {
                                    return
                                }
                                lastOrientation = physicalOrientation
                                runOnUiThread {
                                    events?.success(physicalOrientation)
                                }
                            }
                        }

                    if (physicalOrientationListener?.canDetectOrientation() == true) {
                        physicalOrientationListener?.enable()
                    } else {
                        events?.error("unavailable", "设备不支持物理方向检测", null)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    physicalOrientationListener?.disable()
                    physicalOrientationListener = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAndroidTv" -> {
                        result.success(isAndroidTvDevice())
                    }

                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storageChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAvailableStorageBytes" -> {
                        val statFs = StatFs(cacheDir.path)
                        result.success(statFs.availableBytes)
                    }

                    "getTotalStorageBytes" -> {
                        val statFs = StatFs(cacheDir.path)
                        result.success(statFs.totalBytes)
                    }

                    else -> result.notImplemented()
                }
            }

        val pipChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipControlChannelName)
        pipControlChannel = pipChannel
        pipChannel.setMethodCallHandler { call, result ->
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

        setPipActionHandler { rawAction ->
            when (rawAction) {
                ACTION_PIP_PREVIOUS -> {
                    sendPipActionToFlutter("previous")
                }

                ACTION_PIP_PLAY_PAUSE -> {
                    // 播放状态由 Flutter 播放器确认，宿主不做乐观翻转，避免回写旧状态。
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
    }

    private fun disableAndroidDefaultFocusHighlight() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        // FlutterView 会承接遥控器按键，关闭原生默认焦点框避免整屏被系统描边。
        val rootView = window.decorView
        disableDefaultFocusHighlightForViewTree(rootView)
        rootView.post {
            disableDefaultFocusHighlightForViewTree(rootView)
        }
    }

    private fun disableDefaultFocusHighlightForViewTree(view: View) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        view.defaultFocusHighlightEnabled = false
        if (view !is ViewGroup) {
            return
        }

        // 子 View 由 FlutterActivity 动态挂载，递归处理所有原生容器。
        for (index in 0 until view.childCount) {
            disableDefaultFocusHighlightForViewTree(view.getChildAt(index))
        }
    }

    private fun isAndroidTvDevice(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        val isTelevisionMode =
            uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION

        // 部分电视盒子只声明 leanback 或 television feature，这里三种信号任一命中即可。
        val hasLeanbackFeature =
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
        val hasTelevisionFeature =
            packageManager.hasSystemFeature(PackageManager.FEATURE_TELEVISION)

        return isTelevisionMode || hasLeanbackFeature || hasTelevisionFeature
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        if (isInPictureInPictureMode) {
            Log.d(tag, "进入 PiP，保持 Flutter 生命周期为 resumed")
            flutterEngine?.lifecycleChannel?.appIsResumed()
            // pip 插件的 enter 参数不包含自定义 RemoteAction，进入后立即恢复当前动作集合。
            updatePipActions()
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
        val channel = pipControlChannel
        if (channel == null) {
            Log.d(tag, "PiP 动作丢弃，Flutter 通道不可用: $action")
            return
        }
        Log.d(tag, "回调 Flutter PiP 动作: $action")
        runCatching {
            channel.invokeMethod("onPipAction", mapOf("action" to action))
        }.onFailure { error ->
            Log.d(tag, "PiP 动作回调 Flutter 失败: action=$action, error=$error")
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
        if (isFinishing || (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1 && isDestroyed)) {
            Log.d(tag, "PiP 动作写入跳过，Activity 已销毁或正在退出")
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
        Log.d(
            tag,
            "写入 PiP 动作: count=${actions.size}, playing=$pipIsPlaying, " +
                "previous=$pipHasPrevious, next=$pipHasNext",
        )
        setPictureInPictureParams(paramsBuilder.build())
    }

    private fun resolveCurrentInterfaceOrientation(): String {
        val displayRotation = getCurrentDisplayRotation() ?: return "unknown"
        val orientation = resources.configuration.orientation
        if (
            orientation != Configuration.ORIENTATION_PORTRAIT &&
            orientation != Configuration.ORIENTATION_LANDSCAPE
        ) {
            return "unknown"
        }

        val isPortraitNatural = when (displayRotation) {
            Surface.ROTATION_0, Surface.ROTATION_180 ->
                orientation == Configuration.ORIENTATION_PORTRAIT

            Surface.ROTATION_90, Surface.ROTATION_270 ->
                orientation == Configuration.ORIENTATION_LANDSCAPE

            else -> return "unknown"
        }

        return if (isPortraitNatural) {
            when (displayRotation) {
                Surface.ROTATION_0 -> "portraitUp"
                Surface.ROTATION_90 -> "landscapeLeft"
                Surface.ROTATION_180 -> "portraitDown"
                Surface.ROTATION_270 -> "landscapeRight"
                else -> "unknown"
            }
        } else {
            when (displayRotation) {
                Surface.ROTATION_0 -> "landscapeLeft"
                Surface.ROTATION_90 -> "portraitDown"
                Surface.ROTATION_180 -> "landscapeRight"
                Surface.ROTATION_270 -> "portraitUp"
                else -> "unknown"
            }
        }
    }

    private fun resolvePhysicalDeviceOrientation(orientation: Int): String? {
        if (orientation == OrientationEventListener.ORIENTATION_UNKNOWN) {
            return null
        }

        return when {
            orientation >= 315 || orientation < 45 -> "portraitUp"
            orientation >= 45 && orientation < 135 -> "landscapeRight"
            orientation >= 135 && orientation < 225 -> "portraitDown"
            orientation >= 225 && orientation < 315 -> "landscapeLeft"
            else -> null
        }
    }

    private fun getCurrentDisplayRotation(): Int? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display?.rotation
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.rotation
        }
    }

    companion object {
        private const val ACTION_PIP_PREVIOUS = "org.moontechlab.selene.pip.action.PREVIOUS"
        private const val ACTION_PIP_PLAY_PAUSE = "org.moontechlab.selene.pip.action.PLAY_PAUSE"
        private const val ACTION_PIP_NEXT = "org.moontechlab.selene.pip.action.NEXT"
        @Volatile
        private var pipActionHandler: ((String) -> Unit)? = null

        private fun setPipActionHandler(handler: ((String) -> Unit)?) {
            pipActionHandler = handler
        }

        fun dispatchPipActionFromReceiver(action: String) {
            if (action.isBlank()) {
                Log.d("PipControls", "PiP 动作丢弃，action 为空")
                return
            }
            val handler = pipActionHandler
            if (handler == null) {
                Log.d("PipControls", "PiP 动作丢弃，当前无可用 Handler: $action")
                return
            }
            Log.d("PipControls", "宿主分发 PiP 动作: $action")
            runCatching { handler.invoke(action) }
                .onFailure { error ->
                    Log.d("PipControls", "PiP 动作分发失败: action=$action, error=$error")
                }
        }
    }

    override fun onDestroy() {
        physicalOrientationListener?.disable()
        physicalOrientationListener = null
        setPipActionHandler(null)
        pipControlChannel = null
        super.onDestroy()
    }
}
