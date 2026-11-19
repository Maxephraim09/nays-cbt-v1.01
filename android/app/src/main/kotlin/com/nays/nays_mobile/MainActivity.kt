package com.nays.nays_mobile

import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun getInitialRoute(): String =
        reminderRoute(intent) ?: super.getInitialRoute() ?: "/"

    override fun onCreate(savedInstanceState: Bundle?) {
        if (reminderRoute(intent) != null) {
            setAlarmWindowFlags(true)
        }
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val route = reminderRoute(intent) ?: return
        setAlarmWindowFlags(true)
        flutterEngine?.navigationChannel?.pushRoute(route)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ALARM_WINDOW_METHOD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                SET_ALARM_WINDOW_FLAGS -> {
                    setAlarmWindowFlags(true)
                    result.success(null)
                }
                CLEAR_ALARM_WINDOW_FLAGS -> {
                    setAlarmWindowFlags(false)
                    result.success(null)
                }
                CAN_USE_FULL_SCREEN_INTENT -> result.success(
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        true
                    } else {
                        getSystemService(NotificationManager::class.java)
                            .canUseFullScreenIntent()
                    },
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun setAlarmWindowFlags(enabled: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(enabled)
            setTurnScreenOn(enabled)
        }

        val flags = WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        if (enabled) {
            window.addFlags(flags)
        } else {
            window.clearFlags(flags)
        }
    }

    private fun reminderRoute(intent: Intent?): String? {
        if (intent?.action != SELECT_NOTIFICATION_ACTION) return null
        val reminderId = intent.getStringExtra(NOTIFICATION_PAYLOAD)
            ?.takeIf(String::isNotBlank)
        return if (reminderId == null) {
            "/alarm"
        } else {
            "/alarm?reminder_id=${Uri.encode(reminderId)}"
        }
    }

    private companion object {
        const val ALARM_WINDOW_METHOD_CHANNEL =
            "com.nays.nays_mobile/alarm_window"
        const val CAN_USE_FULL_SCREEN_INTENT = "canUseFullScreenIntent"
        const val SET_ALARM_WINDOW_FLAGS = "setAlarmWindowFlags"
        const val CLEAR_ALARM_WINDOW_FLAGS = "clearAlarmWindowFlags"
        const val NOTIFICATION_PAYLOAD = "payload"
        const val SELECT_NOTIFICATION_ACTION = "SELECT_NOTIFICATION"
    }
}
