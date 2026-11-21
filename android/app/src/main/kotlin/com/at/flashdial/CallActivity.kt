package com.at.flashdial

import android.app.Activity
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Locale

class CallActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private var callId: String? = null
    private var call: NativeCallInfo? = null
    private lateinit var status: TextView
    private lateinit var timer: TextView
    private lateinit var caller: TextView
    private lateinit var controls: LinearLayout
    private val listener: (NativeCallInfo?) -> Unit = { updated ->
        runOnUiThread {
            if (updated == null || updated.callId == callId) { call = updated; render() }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        callId = intent.getStringExtra("callId")
        call = CallManager.snapshot().firstOrNull { it["callId"] == callId }?.let { fromMap(it) }
        buildView()
        CallManager.addListener(listener)
        render()
        handler.post(timerTick)
    }

    override fun onNewIntent(intent: android.content.Intent?) {
        super.onNewIntent(intent)
        intent ?: return
        setIntent(intent)
        callId = intent.getStringExtra("callId")
        call = CallManager.snapshot().firstOrNull { it["callId"] == callId }?.let { fromMap(it) }
        render()
    }

    override fun onDestroy() {
        CallManager.removeListener(listener)
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private fun buildView() {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(32), dp(24), dp(24))
            background = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(Color.rgb(3, 11, 26), Color.rgb(10, 28, 55)))
        }
        caller = textView(30f, Color.WHITE)
        status = textView(16f, Color.rgb(170, 181, 197))
        timer = textView(15f, Color.rgb(170, 181, 197))
        root.addView(textView(15f, Color.rgb(255, 106, 0)).apply { text = "FLASHDIAL" }, lp())
        root.addView(caller, lp().apply { topMargin = dp(52) })
        root.addView(status, lp().apply { topMargin = dp(12) })
        root.addView(timer, lp().apply { topMargin = dp(8) })
        controls = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER }
        root.addView(controls, lp().apply { topMargin = dp(38) })
        setContentView(root)
    }

    private fun render() {
        val active = call ?: run { finish(); return }
        caller.text = active.callerName.ifBlank { active.phoneNumber.ifBlank { "Unknown number" } }
        val incoming = active.direction == "incoming" && active.state == "ringing"
        status.text = when (active.state) {
            "ringing" -> "Incoming call"
            "dialing" -> "Dialing…"
            "connecting" -> "Connecting…"
            "active" -> "Call active"
            "holding" -> "On hold"
            else -> active.state.replaceFirstChar { it.uppercase() }
        }
        timer.text = if (active.connectedAt != null) formatDuration(System.currentTimeMillis() - active.connectedAt!!) else ""
        controls.removeAllViews()
        if (incoming) {
            controls.addView(action("Answer", false) { CallManager.answer(callId) })
            controls.addView(action("Reject", true) { CallManager.disconnect(callId) })
        } else {
            val row = LinearLayout(this).apply { gravity = Gravity.CENTER }
            row.addView(action(if (active.isMuted) "Unmute" else "Mute", false) { CallManager.toggleMute() }, lp().apply { marginEnd = dp(8) })
            row.addView(action(if (active.audioEndpoint == "speaker") "Earpiece" else "Speaker", false) { CallManager.toggleSpeaker() })
            controls.addView(row)
            val secondRow = LinearLayout(this).apply { gravity = Gravity.CENTER }
            secondRow.addView(action(if (active.state == "holding") "Resume" else "Hold", false) { CallManager.toggleHold(callId) }, lp().apply { marginEnd = dp(8) })
            secondRow.addView(action("Keypad", false) { showKeypad() })
            controls.addView(secondRow)
            controls.addView(action("End call", true) { CallManager.disconnect(callId) }, lp().apply { topMargin = dp(18) })
        }
    }

    private fun action(label: String, destructive: Boolean, onClick: () -> Unit): Button = Button(this).apply {
        text = label; contentDescription = label; minHeight = dp(52); minWidth = dp(136)
        setTextColor(if (destructive) Color.rgb(255, 138, 141) else Color.WHITE)
        setOnClickListener { try { onClick() } catch (_: Exception) {} }
    }

    private fun showKeypad() {
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER }
        arrayOf("1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#").toList().chunked(3).forEach { values ->
            val row = LinearLayout(this).apply { gravity = Gravity.CENTER }
            values.forEach { digit -> row.addView(Button(this).apply { text = digit; contentDescription = "Dial $digit" }, lp().apply { width = dp(72); height = dp(56) }) }
            layout.addView(row)
        }
        android.app.AlertDialog.Builder(this).setTitle("Keypad").setView(layout).setNegativeButton("Close", null).show()
    }

    private val timerTick = object : Runnable { override fun run() { if (!isFinishing) render(); handler.postDelayed(this, 1000) } }
    private fun textView(size: Float, color: Int) = TextView(this).apply { textSize = size; setTextColor(color); gravity = Gravity.CENTER; textAlignment = View.TEXT_ALIGNMENT_CENTER }
    private fun lp() = LinearLayout.LayoutParams(-1, -2)
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    private fun formatDuration(millis: Long): String { val seconds = (millis / 1000).coerceAtLeast(0); return String.format(Locale.getDefault(), "%02d:%02d", seconds / 60, seconds % 60) }
    private fun fromMap(map: Map<String, Any?>) = NativeCallInfo(map["callId"].toString(), map["phoneNumber"].toString(), map["callerName"].toString(), map["direction"].toString(), map["state"].toString(), map["isMuted"] == true, map["audioEndpoint"].toString(), (map["connectedAt"] as? Number)?.toLong())
}
