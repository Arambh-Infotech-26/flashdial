package com.at.flashdial

import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class CallActivity : Activity() {
    private val callId get() = intent.getStringExtra("callId")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val padding = (24 * resources.displayMetrics.density).toInt()
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER; setPadding(padding, padding, padding, padding); setBackgroundColor(0xFF030B1A.toInt()) }
        val title = TextView(this).apply { text = "FlashDial"; textSize = 28f; setTextColor(0xFFF5F7FB.toInt()); gravity = Gravity.CENTER }
        val number = TextView(this).apply { text = "Phone call"; textSize = 20f; setTextColor(0xFFAAB5C5.toInt()); gravity = Gravity.CENTER }
        layout.addView(title, LinearLayout.LayoutParams(-1, -2))
        layout.addView(number, LinearLayout.LayoutParams(-1, -2).apply { topMargin = padding / 2 })
        val answer = Button(this).apply { text = "Answer"; setOnClickListener { CallManager.answer(callId); finish() } }
        val reject = Button(this).apply { text = "Reject"; setOnClickListener { CallManager.disconnect(callId); finish() } }
        layout.addView(answer, LinearLayout.LayoutParams(-1, -2).apply { topMargin = padding })
        layout.addView(reject, LinearLayout.LayoutParams(-1, -2))
        setContentView(layout)
    }
}
