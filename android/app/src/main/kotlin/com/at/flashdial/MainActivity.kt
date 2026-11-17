package com.at.flashdial

import android.Manifest
import android.app.Activity
import android.app.role.RoleManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.telecom.TelecomManager
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.at.flashdial/telephony"
    private val eventChannelName = "com.at.flashdial/telephony_events"
    private val roleRequestCode = 7101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CallManager.eventSink = null

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "checkDialerRole" -> result.success(isDefaultDialer())
                    "requestDialerRole" -> {
                        requestDialerRole()
                        result.success(null)
                    }
                    "placeCall" -> {
                        val number = call.argument<String>("number")?.trim().orEmpty()
                        if (number.isEmpty()) throw IllegalArgumentException("Enter a phone number first.")
                        placeCall(number)
                        result.success(null)
                    }
                    "getActiveCalls" -> result.success(CallManager.snapshot())
                    "answerCall" -> result.success(CallManager.answer(call.argument<String>("callId")))
                    "rejectCall", "endCall" -> result.success(CallManager.disconnect(call.argument<String>("callId")))
                    "setMuted" -> result.success(CallManager.toggleMute())
                    "setAudioEndpoint" -> result.success(CallManager.toggleSpeaker())
                    else -> result.notImplemented()
                }
            } catch (error: SecurityException) {
                result.error("PERMISSION_DENIED", error.message, null)
            } catch (error: Exception) {
                result.error("TELEPHONY_ERROR", error.message, null)
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                CallManager.eventSink = events
                CallManager.snapshot().forEach { events?.success(it) }
            }

            override fun onCancel(arguments: Any?) {
                CallManager.eventSink = null
            }
        })
    }

    private fun isDefaultDialer(): Boolean = getSystemService(TelecomManager::class.java).defaultDialerPackage == packageName

    private fun requestDialerRole() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            if (roleManager.isRoleAvailable(RoleManager.ROLE_DIALER) && !roleManager.isRoleHeld(RoleManager.ROLE_DIALER)) {
                startActivityForResult(roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER), roleRequestCode)
            }
        }
    }

    private fun placeCall(number: String) {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CALL_PHONE), 7102)
            throw SecurityException("Phone permission is required to place calls.")
        }
        getSystemService(TelecomManager::class.java).placeCall(Uri.fromParts("tel", number, null), null)
    }
}
