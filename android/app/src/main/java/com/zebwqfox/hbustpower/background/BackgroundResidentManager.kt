package com.zebwqfox.hbustpower.background

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.ContextCompat

object BackgroundResidentManager {
    fun start(context: Context) {
        val appContext = context.applicationContext
        val intent = Intent(appContext, PowerMonitorService::class.java)
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(appContext, intent)
            } else {
                appContext.startService(intent)
            }
        }
    }

    fun canPostNotifications(context: Context): Boolean {
        val runtimePermissionGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        val notificationsEnabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            context.getSystemService(NotificationManager::class.java).areNotificationsEnabled()
        } else {
            true
        }
        return runtimePermissionGranted && notificationsEnabled
    }

    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val powerManager = context.getSystemService(PowerManager::class.java)
        return powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun requestBatteryOptimizationExemption(activity: Activity) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            isIgnoringBatteryOptimizations(activity)
        ) return

        val directRequest = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:${activity.packageName}"),
        )
        val settingsFallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        runCatching { activity.startActivity(directRequest) }
            .recoverCatching { activity.startActivity(settingsFallback) }
    }

    fun openNotificationSettings(activity: Activity) {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
        }
        runCatching { activity.startActivity(intent) }
    }
}
