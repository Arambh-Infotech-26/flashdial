package com.at.flashdial

import android.Manifest
import android.app.Activity
import android.app.role.RoleManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.Build
import android.os.PowerManager
import android.provider.CallLog
import android.provider.Settings
import android.telecom.TelecomManager
import android.app.NotificationManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.at.flashdial/telephony"
    private val eventChannelName = "com.at.flashdial/telephony_events"
    private val roleRequestCode = 7101
    private val setupPermissionRequestCode = 7104
    private val callLogPermissionRequestCode = 7103
    private var pendingPermissionResult: MethodChannel.Result? = null

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
                    "getDialerReadiness" -> result.success(isDefaultDialer())
                    "getSetupStatus" -> result.success(setupStatus())
                    "startSetupStep" -> {
                        startSetupStep(call.argument<String>("step").orEmpty(), result)
                    }
                    "getInitialDialNumber" -> result.success(intent?.data?.schemeSpecificPart)
                    "requestCallLogPermission" -> requestCallLogPermission(result)
                    "getRecentCalls" -> result.success(getRecentCalls())
                    "answerCall" -> result.success(CallManager.answer(call.argument<String>("callId")))
                    "rejectCall", "endCall" -> result.success(CallManager.disconnect(call.argument<String>("callId")))
                    "setMuted" -> result.success(CallManager.toggleMute())
                    "setAudioEndpoint" -> result.success(CallManager.toggleSpeaker())
                    "setCallHeld" -> result.success(CallManager.toggleHold(call.argument<String>("callId")))
                    "openDefaultPhoneAppSettings" -> { openDefaultDialerSettings(); result.success(null) }
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

    private fun isGranted(permission: String): Boolean = ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

    private fun setupStatus(): Map<String, Any> {
        val notifications = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || getSystemService(NotificationManager::class.java).areNotificationsEnabled()
        val bluetooth = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || (isGranted(Manifest.permission.BLUETOOTH_CONNECT) && isGranted(Manifest.permission.BLUETOOTH_SCAN))
        val battery = (getSystemService(POWER_SERVICE) as PowerManager).isIgnoringBatteryOptimizations(packageName)
        val fullScreen = Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE || getSystemService(NotificationManager::class.java).canUseFullScreenIntent()
        val status = mapOf(
            "defaultDialer" to isDefaultDialer(),
            "callPhone" to isGranted(Manifest.permission.CALL_PHONE),
            "answerPhoneCalls" to isGranted(Manifest.permission.ANSWER_PHONE_CALLS),
            "readPhoneState" to isGranted(Manifest.permission.READ_PHONE_STATE),
            "readCallLog" to isGranted(Manifest.permission.READ_CALL_LOG),
            "readContacts" to isGranted(Manifest.permission.READ_CONTACTS),
            "notifications" to notifications,
            "bluetooth" to bluetooth,
            "batteryOptimizationIgnored" to battery,
            "fullScreenIntentAllowed" to fullScreen,
        )
        return status + mapOf("isReady" to status.values.all { it == true })
    }

    private fun startSetupStep(step: String, result: MethodChannel.Result) {
        when (step) {
            "defaultDialer" -> { requestDialerRole(); result.success(null) }
            "coreCalls" -> requestPermissions(listOf(Manifest.permission.CALL_PHONE, Manifest.permission.ANSWER_PHONE_CALLS, Manifest.permission.READ_PHONE_STATE), result)
            "recents" -> requestPermissions(listOf(Manifest.permission.READ_CALL_LOG), result)
            "contacts" -> requestPermissions(listOf(Manifest.permission.READ_CONTACTS), result)
            "notifications" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) requestPermissions(listOf(Manifest.permission.POST_NOTIFICATIONS), result) else result.success(null)
            "bluetooth" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) requestPermissions(listOf(Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_SCAN), result) else result.success(null)
            "battery" -> {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply { data = Uri.parse("package:$packageName") }
                startActivity(intent)
                result.success(null)
            }
            "fullScreen" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startActivity(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply { data = Uri.parse("package:$packageName") })
                result.success(null)
            } else result.success(null)
            else -> result.success(null)
        }
    }

    private fun requestPermissions(permissions: List<String>, result: MethodChannel.Result) {
        val missing = permissions.filterNot(::isGranted)
        if (missing.isEmpty()) {
            result.success(setupStatus())
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(this, missing.toTypedArray(), setupPermissionRequestCode)
    }

    private fun requestDialerRole() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            if (roleManager.isRoleHeld(RoleManager.ROLE_DIALER)) return
            if (roleManager.isRoleAvailable(RoleManager.ROLE_DIALER)) {
                startActivityForResult(roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER), roleRequestCode)
            } else {
                openDefaultDialerSettings()
            }
        } else {
            val intent = Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER).apply {
                putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, packageName)
            }
            if (intent.resolveActivity(packageManager) != null) startActivity(intent) else openDefaultDialerSettings()
        }
    }

    private fun openDefaultDialerSettings() {
        val intent = Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
        if (intent.resolveActivity(packageManager) != null) startActivity(intent)
    }

    private fun placeCall(number: String) {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CALL_PHONE), 7102)
            throw SecurityException("Phone permission is required to place calls.")
        }
        getSystemService(TelecomManager::class.java).placeCall(Uri.fromParts("tel", number, null), null)
    }

    private fun requestCallLogPermission(result: MethodChannel.Result) {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_CALL_LOG), callLogPermissionRequestCode)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val result = pendingPermissionResult ?: return
        pendingPermissionResult = null
        if (requestCode == callLogPermissionRequestCode) {
            result.success(ActivityCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED)
        } else if (requestCode == setupPermissionRequestCode) {
            result.success(setupStatus())
        }
    }

    private fun getRecentCalls(): List<Map<String, Any?>> {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
            throw SecurityException("Call-log permission is required to view recent calls.")
        }
        val result = mutableListOf<Map<String, Any?>>()
        contentResolver.query(CallLog.Calls.CONTENT_URI, arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.TYPE, CallLog.Calls.DATE, CallLog.Calls.DURATION, CallLog.Calls.CACHED_NAME), null, null, "${CallLog.Calls.DATE} DESC")?.use { cursor ->
            val number = cursor.getColumnIndex(CallLog.Calls.NUMBER)
            val type = cursor.getColumnIndex(CallLog.Calls.TYPE)
            val date = cursor.getColumnIndex(CallLog.Calls.DATE)
            val duration = cursor.getColumnIndex(CallLog.Calls.DURATION)
            val name = cursor.getColumnIndex(CallLog.Calls.CACHED_NAME)
            var count = 0
            while (cursor.moveToNext() && count < 50) {
                val kind = when (cursor.getInt(type)) {
                    CallLog.Calls.INCOMING_TYPE -> "INCOMING"
                    CallLog.Calls.MISSED_TYPE -> "MISSED"
                    CallLog.Calls.REJECTED_TYPE -> "REJECTED"
                    else -> "OUTGOING"
                }
                result += mapOf("number" to cursor.getString(number), "name" to cursor.getString(name), "type" to kind, "date" to cursor.getLong(date), "duration" to cursor.getLong(duration))
                count++
            }
        }
        return result
    }
}
