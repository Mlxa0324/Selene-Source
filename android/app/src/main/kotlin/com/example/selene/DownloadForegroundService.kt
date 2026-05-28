package org.moontechlab.selene

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class DownloadForegroundService : Service() {
    companion object {
        const val ACTION_START_OR_UPDATE = "org.moontechlab.selene.action.DOWNLOAD_START_OR_UPDATE"
        const val ACTION_STOP = "org.moontechlab.selene.action.DOWNLOAD_STOP"
        const val EXTRA_DOWNLOADING_COUNT = "downloadingCount"
        const val EXTRA_QUEUED_COUNT = "queuedCount"

        private const val CHANNEL_ID = "selene_download_channel"
        private const val CHANNEL_NAME = "后台下载"
        private const val NOTIFICATION_ID = 10086
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START_OR_UPDATE -> {
                val downloadingCount = intent.getIntExtra(EXTRA_DOWNLOADING_COUNT, 0)
                val queuedCount = intent.getIntExtra(EXTRA_QUEUED_COUNT, 0)
                startForeground(NOTIFICATION_ID, buildNotification(downloadingCount, queuedCount))
                return START_STICKY
            }
            else -> {
                startForeground(NOTIFICATION_ID, buildNotification(0, 0))
                return START_STICKY
            }
        }
    }

    private fun buildNotification(downloadingCount: Int, queuedCount: Int): Notification {
        createNotificationChannelIfNeeded()

        val contentText = when {
            downloadingCount > 0 && queuedCount > 0 ->
                "正在下载 $downloadingCount 个，排队 $queuedCount 个"
            downloadingCount > 0 ->
                "正在下载 $downloadingCount 个任务"
            queuedCount > 0 ->
                "下载排队中 $queuedCount 个任务"
            else ->
                "下载服务运行中"
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("IvyTV 后台下载")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun createNotificationChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java)
        val channel = manager.getNotificationChannel(CHANNEL_ID)
        if (channel != null) return

        val newChannel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "保持下载任务在后台持续运行"
            setShowBadge(false)
        }
        manager.createNotificationChannel(newChannel)
    }
}
