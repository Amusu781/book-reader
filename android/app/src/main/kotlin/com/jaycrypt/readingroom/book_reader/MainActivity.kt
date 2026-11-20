package com.jaycrypt.readingroom.book_reader

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Do Not Disturb bridge for Focus Mode.
 *
 * Channel: "com.jaycrypt.readingroom/dnd"
 *  - isDndGranted  -> bool: NotificationManager.isNotificationPolicyAccessGranted
 *  - requestDndAccess -> opens the system DND-access settings page
 *  - setDnd {enabled: bool} -> INTERRUPTION_FILTER_NONE / INTERRUPTION_FILTER_ALL
 *
 * Everything is guarded: if DND access was never granted, setDnd is a
 * no-op instead of a crash, so reading always works.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.jaycrypt.readingroom/dnd"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                when (call.method) {
                    "isDndGranted" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            result.success(nm.isNotificationPolicyAccessGranted)
                        } else {
                            result.success(true)
                        }
                    }
                    "requestDndAccess" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(
                                Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS
                            )
                            startActivity(intent)
                        }
                        result.success(null)
                    }
                    "setDnd" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                            nm.isNotificationPolicyAccessGranted
                        ) {
                            nm.setInterruptionFilter(
                                if (enabled) {
                                    NotificationManager.INTERRUPTION_FILTER_NONE
                                } else {
                                    NotificationManager.INTERRUPTION_FILTER_ALL
                                }
                            )
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
