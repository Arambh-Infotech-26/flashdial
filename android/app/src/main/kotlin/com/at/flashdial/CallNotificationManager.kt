package com.at.flashdial

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

object CallNotificationManager {
    private const val incomingChannel = "incoming_calls"
    private const val ongoingChannel = "ongoing_calls"
    private const val incomingId = 481
    private const val ongoingId = 482
    const val ACTION_ANSWER = "com.at.flashdial.ANSWER"
    const val ACTION_REJECT = "com.at.flashdial.REJECT"
    const val ACTION_END = "com.at.flashdial.END"
    const val ACTION_OPEN = "com.at.flashdial.OPEN"

    fun show(context: Context, call: NativeCallInfo) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(incomingChannel, "Incoming calls", NotificationManager.IMPORTANCE_HIGH).apply { description = "Incoming FlashDial calls" })
            manager.createNotificationChannel(NotificationChannel(ongoingChannel, "Ongoing calls", NotificationManager.IMPORTANCE_LOW).apply { description = "Active FlashDial calls" })
        }
        val incoming = call.direction == "incoming" && call.state == "ringing"
        val open = pendingActivity(context, call.callId)
        val builder = NotificationCompat.Builder(context, if (incoming) incomingChannel else ongoingChannel)
            .setSmallIcon(com.at.flashdial.R.mipmap.ic_launcher)
            .setContentTitle(if (incoming) "Incoming call" else "FlashDial call")
            .setContentText(call.callerName.ifBlank { call.phoneNumber.ifBlank { "Unknown number" } } + if (incoming) " · Incoming call" else " · ${call.state}")
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(if (incoming) NotificationCompat.PRIORITY_MAX else NotificationCompat.PRIORITY_LOW)
            .setOngoing(true).setAutoCancel(false).setContentIntent(open)
        if (incoming) {
            builder.setFullScreenIntent(open, true)
                .addAction(0, "Answer", pendingBroadcast(context, ACTION_ANSWER, call.callId, 1001))
                .addAction(0, "Reject", pendingBroadcast(context, ACTION_REJECT, call.callId, 1002))
        } else {
            builder.addAction(0, "Open call", open).addAction(0, "End call", pendingBroadcast(context, ACTION_END, call.callId, 1003))
        }
        manager.notify(if (incoming) incomingId else ongoingId, builder.build())
    }

    fun dismiss(context: Context?) { context?.getSystemService(NotificationManager::class.java)?.apply { cancel(incomingId); cancel(ongoingId) } }
    private fun pendingActivity(context: Context, id: String) = PendingIntent.getActivity(context, id.hashCode(), Intent(context, CallActivity::class.java).putExtra("callId", id), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun pendingBroadcast(context: Context, action: String, id: String, code: Int) = PendingIntent.getBroadcast(context, code, Intent(context, CallNotificationReceiver::class.java).setAction(action).putExtra("callId", id), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
}

class CallNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("callId")
        when (intent.action) {
            CallNotificationManager.ACTION_ANSWER -> CallManager.answer(id)
            CallNotificationManager.ACTION_REJECT, CallNotificationManager.ACTION_END -> CallManager.disconnect(id)
            CallNotificationManager.ACTION_OPEN -> context.startActivity(Intent(context, CallActivity::class.java).putExtra("callId", id).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP))
        }
    }
}
