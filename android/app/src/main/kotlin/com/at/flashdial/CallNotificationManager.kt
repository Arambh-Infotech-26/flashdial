package com.at.flashdial

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

object CallNotificationManager {
    private const val channelId = "calls"
    private const val notificationId = 481

    fun show(context: Context, call: NativeCallInfo) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) manager.createNotificationChannel(NotificationChannel(channelId, "Calls", NotificationManager.IMPORTANCE_HIGH).apply { description = "Incoming and ongoing phone calls" })
        val intent = Intent(context, CallActivity::class.java).putExtra("callId", call.callId)
        val pending = PendingIntent.getActivity(context, call.callId.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val title = if (call.direction == "incoming" && call.state == "ringing") "Incoming call" else "Call ${call.state}"
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(com.at.flashdial.R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(call.phoneNumber.ifBlank { "Unknown number" })
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(call.state != "disconnected")
            .setContentIntent(pending)
            .setFullScreenIntent(pending, call.state == "ringing")
            .build()
        manager.notify(notificationId, notification)
    }

    fun dismiss(context: Context?) {
        context?.getSystemService(NotificationManager::class.java)?.cancel(notificationId)
    }
}
