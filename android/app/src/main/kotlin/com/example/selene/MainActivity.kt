package org.moontechlab.selene

import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val backgroundChannel = "org.moontechlab.selene/background_download"

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
}
