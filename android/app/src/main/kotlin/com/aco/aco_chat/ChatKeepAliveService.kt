package com.aco.aco_chat

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/** Keeps the authenticated Flutter/OpenIM process eligible to receive messages. */
class ChatKeepAliveService : Service() {
    companion object {
        private const val SERVICE_CHANNEL_ID = "chat_keep_alive"
        private const val MESSAGE_CHANNEL_ID = "chat_messages"
        private const val SERVICE_NOTIFICATION_ID = 4202

        fun showMessage(context: Context, title: String, body: String) {
            val manager = context.getSystemService(NotificationManager::class.java)
            ensureChannels(manager)
            val notification = NotificationCompat.Builder(context, MESSAGE_CHANNEL_ID)
                .setSmallIcon(context.applicationInfo.icon)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                .setContentIntent(appLaunchPendingIntent(context))
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .build()
            val notificationID = (System.currentTimeMillis() and 0x7fffffff).toInt()
            manager.notify(notificationID, notification)
        }

        private fun appLaunchPendingIntent(context: Context): PendingIntent {
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            return PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        private fun ensureChannels(manager: NotificationManager) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            manager.createNotificationChannel(
                NotificationChannel(
                    SERVICE_CHANNEL_ID,
                    "后台消息服务",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply { setShowBadge(false) },
            )
            manager.createNotificationChannel(
                NotificationChannel(
                    MESSAGE_CHANNEL_ID,
                    "聊天消息",
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
        }
    }

    override fun onCreate() {
        super.onCreate()
        val manager = getSystemService(NotificationManager::class.java)
        ensureChannels(manager)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                SERVICE_NOTIFICATION_ID,
                serviceNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_REMOTE_MESSAGING,
            )
        } else {
            startForeground(SERVICE_NOTIFICATION_ID, serviceNotification())
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onBind(intent: Intent?): IBinder? = null

    private fun serviceNotification(): Notification =
        NotificationCompat.Builder(this, SERVICE_CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("ACO")
            .setContentText("正在后台接收消息")
            .setContentIntent(appLaunchPendingIntent(this))
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
}
