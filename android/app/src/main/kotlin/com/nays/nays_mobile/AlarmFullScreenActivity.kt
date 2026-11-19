package com.nays.nays_mobile

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class AlarmFullScreenActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                or WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                or WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
        )
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val reminderId = intent.getStringExtra("reminder_id")
        val route = if (reminderId.isNullOrBlank()) {
            "/alarm"
        } else {
            "/alarm?reminder_id=$reminderId"
        }
        flutterEngine.navigationChannel.setInitialRoute(route)
    }
}
