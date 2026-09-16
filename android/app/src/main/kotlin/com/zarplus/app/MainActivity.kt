package com.zarplus.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val notificationPermissionChannel = "zarplus/notification_permission"
    private val permissionRequestedKey = "zar_notification_permission_requested"
    // Android exposes an app-level notification switch through the same
    // POST_NOTIFICATIONS check as a runtime denial on some OEM builds. Keep a
    // non-authoritative marker of a previously observed grant so the UI can
    // describe that state as "disabled in system settings" without ever
    // treating the marker as permission itself.
    private val permissionEverGrantedKey = "zar_notification_permission_ever_granted"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationPermissionChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPermissionState" -> result.success(notificationPermissionState())
                "markPermissionRequested" -> {
                    getPreferences(MODE_PRIVATE).edit()
                        .putBoolean(permissionRequestedKey, true)
                        .apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun notificationPermissionState(): Map<String, Any> {
        val notificationsEnabled =
            NotificationManagerCompat.from(this).areNotificationsEnabled()
        val runtimePermissionSupported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
        val permissionGranted = !runtimePermissionSupported ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        val preferences = getPreferences(MODE_PRIVATE)
        val everGranted = preferences.getBoolean(permissionEverGrantedKey, false)
        if (permissionGranted && notificationsEnabled && !everGranted) {
            preferences.edit().putBoolean(permissionEverGrantedKey, true).apply()
        }
        val requested = getPreferences(MODE_PRIVATE)
            .getBoolean(permissionRequestedKey, false)

        val status = when {
            !notificationsEnabled && (permissionGranted || everGranted) -> "disabled"
            permissionGranted -> "granted"
            !requested -> "notDetermined"
            else -> "denied"
        }
        return mapOf(
            "status" to status,
            "permissionGranted" to permissionGranted,
            "notificationsEnabled" to notificationsEnabled,
        )
    }
}
