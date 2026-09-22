package com.zebwqfox.hbustpower.background

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.zebwqfox.hbustpower.MainActivity
import com.zebwqfox.hbustpower.R
import com.zebwqfox.hbustpower.data.AppSettings
import java.time.Instant
import java.util.Locale
import java.time.ZoneId
import java.time.format.DateTimeFormatter

class PowerMonitorService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val refreshTask = object : Runnable {
        override fun run() {
            updateNotification()
            handler.postDelayed(this, REFRESH_INTERVAL_MILLIS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        promoteToForeground()
        handler.removeCallbacks(refreshTask)
        handler.post(refreshTask)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(refreshTask)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun promoteToForeground() {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else {
            0
        }
        ServiceCompat.startForeground(
            this,
            RESIDENT_NOTIFICATION_ID,
            buildNotification(),
            type,
        )
    }

    private fun updateNotification() {
        getSystemService(NotificationManager::class.java)
            .notify(RESIDENT_NOTIFICATION_ID, buildNotification())
    }

    private fun buildNotification(): android.app.Notification {
        val summary = AppSettings(this).summary()
        val text = if (summary == null) {
            "尚未取得电量，打开应用登录后显示"
        } else {
            val time = Instant.ofEpochMilli(summary.third).atZone(ZoneId.of("Asia/Shanghai"))
                .format(DateTimeFormatter.ofPattern("M月d日 HH:mm"))
            listOfNotNull(summary.first, String.format(Locale.ROOT, "剩余 %.2f 度", summary.second), "更新于 $time").joinToString(" · ")
        }
        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, RESIDENT_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification_power)
            .setContentTitle("湖科电量正在后台守护")
            .setContentText(text)
            .setContentIntent(openApp)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            RESIDENT_CHANNEL_ID,
            "后台电量守护",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "持续运行电量监测并在低电量时提醒"
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    companion object {
        private const val RESIDENT_CHANNEL_ID = "power_monitor_resident"
        private const val RESIDENT_NOTIFICATION_ID = 1001
        private const val REFRESH_INTERVAL_MILLIS = 15 * 60 * 1000L
    }
}
