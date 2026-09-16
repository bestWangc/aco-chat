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
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.lang.reflect.Proxy

/** Keeps the authenticated Flutter/OpenIM process eligible to receive messages. */
class ChatKeepAliveService : Service() {
    companion object {
        private const val SERVICE_CHANNEL_ID = "chat_keep_alive"
        // Channel importance cannot be raised after Android creates it. Keep a
        // new ID so existing installs migrate from the old non-banner channel.
        private const val MESSAGE_CHANNEL_ID = "chat_banner_messages_v2"
        private const val SERVICE_NOTIFICATION_ID = 4202
        private var lastNotifiedMessageID: String? = null

        fun listenForBackgroundMessages(context: Context) {
            runCatching {
                val listenerType = Class.forName("open_im_sdk_callback.OnAdvancedMsgListener")
                val listener = Proxy.newProxyInstance(
                    listenerType.classLoader,
                    arrayOf(listenerType),
                ) { _, method, arguments ->
                    if (
                        method.name == "onRecvNewMessage" ||
                        method.name == "onRecvOfflineNewMessage"
                    ) {
                        (arguments?.firstOrNull() as? String)?.let {
                            notifyIncomingMessage(context, it)
                        }
                    }
                    null
                }
                Class.forName("open_im_sdk.Open_im_sdk")
                    .getMethod("setAdvancedMsgListener", listenerType)
                    .invoke(null, listener)
                Log.i("AcoChatBackground", "OpenIM background listener registered")
            }.onFailure {
                Log.e("AcoChatBackground", "Failed to register OpenIM listener", it)
            }
        }

        private fun notifyIncomingMessage(context: Context, payload: String) {
            val message = runCatching { JSONObject(payload) }.getOrNull() ?: return
            val messageID = message.optString("clientMsgID")
            if (messageID.isNotEmpty() && messageID == lastNotifiedMessageID) return
            lastNotifiedMessageID = messageID
            val title = message.optString("senderNickname").ifEmpty { "新消息" }
            val body = when {
                message.has("textElem") ->
                    message.optJSONObject("textElem")?.optString("content").orEmpty()
                message.has("soundElem") -> "[语音消息]"
                message.has("pictureElem") -> "[图片]"
                message.has("videoElem") -> "[视频]"
                else -> "你收到一条新消息"
            }
            Log.i("AcoChatBackground", "Background message received id=$messageID")
            showMessage(context, title, body.ifEmpty { "你收到一条新消息" }, false)
        }

        fun showMessage(context: Context, title: String, body: String, urgent: Boolean) {
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
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
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
                    "新消息横幅提醒",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "收到新聊天消息时显示横幅、声音和桌面角标"
                    enableVibration(true)
                    setShowBadge(true)
                    lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                },
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
