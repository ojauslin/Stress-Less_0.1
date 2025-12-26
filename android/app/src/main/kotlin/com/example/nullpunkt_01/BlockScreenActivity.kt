package com.example.nullpunkt_01

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager

class BlockScreenActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Make the activity full screen and show on lock screen
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )

        // Create a simple block screen UI
        val layout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = android.view.Gravity.CENTER
            setBackgroundColor(android.graphics.Color.parseColor("#2C2C2C"))
            setPadding(50, 50, 50, 50)
        }

        val textView = android.widget.TextView(this).apply {
            text = "This app is blocked"
            textSize = 24f
            setTextColor(android.graphics.Color.WHITE)
            gravity = android.view.Gravity.CENTER
        }

        val button = android.widget.Button(this).apply {
            text = "Go Back"
            setOnClickListener {
                goHome()
            }
        }

        layout.addView(textView)
        layout.addView(button)
        setContentView(layout)
    }

    private fun goHome() {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
        finish()
    }

    override fun onBackPressed() {
        // Prevent back button from closing the block screen
        goHome()
    }
}
