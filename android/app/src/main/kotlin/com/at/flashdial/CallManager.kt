package com.at.flashdial

import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.CallEndpoint
import android.telecom.InCallService
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.ConcurrentHashMap

data class NativeCallInfo(
    val callId: String,
    val phoneNumber: String,
    val direction: String,
    var state: String,
    var isMuted: Boolean = false,
    var audioEndpoint: String = "earpiece",
    var connectedAt: Long? = null,
) {
    fun asMap() = mapOf("callId" to callId, "phoneNumber" to phoneNumber, "direction" to direction, "state" to state, "isMuted" to isMuted, "audioEndpoint" to audioEndpoint, "connectedAt" to connectedAt)
}

object CallManager {
    private val calls = ConcurrentHashMap<String, Call>()
    private val info = ConcurrentHashMap<String, NativeCallInfo>()
    private val callbacks = ConcurrentHashMap<String, Call.Callback>()
    private var service: InCallService? = null
    private var muted = false
    private var speaker = false
    private var availableEndpoints: List<CallEndpoint> = emptyList()
    var eventSink: EventChannel.EventSink? = null

    fun attach(service: InCallService) { this.service = service }

    fun detach(service: InCallService) {
        if (this.service === service) this.service = null
    }

    fun updateAvailableEndpoints(endpoints: List<CallEndpoint>) {
        availableEndpoints = endpoints
    }

    fun add(service: InCallService, call: Call) {
        attach(service)
        val id = callId(call)
        calls[id] = call
        val direction = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && call.details.callDirection == Call.Details.DIRECTION_INCOMING) "incoming" else "outgoing"
        val item = NativeCallInfo(id, call.details.handle?.schemeSpecificPart.orEmpty(), direction, stateName(call.state))
        info[id] = item
        val callback = object : Call.Callback() {
            override fun onStateChanged(call: Call, state: Int) {
                info[id]?.state = stateName(state)
                if (state == Call.STATE_ACTIVE && info[id]?.connectedAt == null) {
                    info[id]?.connectedAt = System.currentTimeMillis()
                }
                publish(info[id])
                if (state == Call.STATE_DISCONNECTED) remove(call)
            }
        }
        callbacks[id] = callback
        call.registerCallback(callback, Handler(Looper.getMainLooper()))
        publish(item)
        CallNotificationManager.show(service, item)
    }

    fun remove(call: Call) {
        val id = callId(call)
        callbacks.remove(id)?.let { call.unregisterCallback(it) }
        calls.remove(id)
        info.remove(id)
        CallNotificationManager.dismiss(service)
        eventSink?.success(mapOf("callId" to id, "state" to "disconnected"))
    }

    fun snapshot(): List<Map<String, Any?>> = info.values.map { it.asMap() }

    fun answer(callId: String?): Boolean {
        val call = calls[callId] ?: throw IllegalArgumentException("Call is no longer available.")
        if (call.state != Call.STATE_RINGING) throw IllegalStateException("Call is not ringing.")
        call.answer(0)
        return true
    }

    fun disconnect(callId: String?): Boolean {
        val call = calls[callId] ?: throw IllegalArgumentException("Call is no longer available.")
        call.disconnect()
        return true
    }

    fun toggleMute(): Boolean {
        muted = !muted
        service?.setMuted(muted) ?: throw IllegalStateException("Call audio is unavailable.")
        info.values.forEach { it.isMuted = muted; publish(it) }
        return muted
    }

    fun toggleSpeaker(): String {
        val incall = service ?: throw IllegalStateException("Call audio is unavailable.")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val endpointType = if (speaker) CallEndpoint.TYPE_EARPIECE else CallEndpoint.TYPE_SPEAKER
            val endpoint = availableEndpoints.firstOrNull { it.endpointType == endpointType }
                ?: throw IllegalStateException("No compatible audio endpoint is available.")
            incall.requestCallEndpointChange(endpoint, incall.mainExecutor, {})
        } else {
            incall.setAudioRoute(if (speaker) CallAudioState.ROUTE_SPEAKER else CallAudioState.ROUTE_EARPIECE)
        }
        speaker = !speaker
        val endpoint = if (speaker) "speaker" else "earpiece"
        info.values.forEach { it.audioEndpoint = endpoint; publish(it) }
        return endpoint
    }

    private fun publish(item: NativeCallInfo?) {
        if (item != null) {
            eventSink?.success(item.asMap())
            service?.let { CallNotificationManager.show(it, item) }
        }
    }

    private fun callId(call: Call): String = call.hashCode().toString()

    private fun stateName(state: Int): String = when (state) {
        Call.STATE_RINGING -> "ringing"
        Call.STATE_DIALING -> "dialing"
        Call.STATE_CONNECTING -> "connecting"
        Call.STATE_ACTIVE -> "active"
        Call.STATE_HOLDING -> "holding"
        Call.STATE_DISCONNECTED -> "disconnected"
        else -> "unknown"
    }
}
