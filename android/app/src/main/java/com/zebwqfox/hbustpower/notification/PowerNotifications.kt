package com.zebwqfox.hbustpower.notification

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.content.edit
import com.zebwqfox.hbustpower.MainActivity
import com.zebwqfox.hbustpower.R
import com.zebwqfox.hbustpower.data.Diagnostics

object PowerNotifications {
    const val LOW_BALANCE_CHANNEL = "low_balance"
    const val TEST_CHANNEL = "debug_tests"
    const val DEBUG_TAG = "debug-notification"

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(LOW_BALANCE_CHANNEL, "低电量提醒", NotificationManager.IMPORTANCE_HIGH)
                .apply { description = "宿舍电量首次低于提醒值时通知一次" },
        )
        manager.createNotificationChannel(
            NotificationChannel(TEST_CHANNEL, "通知测试", NotificationManager.IMPORTANCE_HIGH)
                .apply { description = "调试页发送的测试通知" },
        )
    }

    fun runtimePermissionGranted(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    fun channelEnabled(context: Context, channel: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        val value = context.getSystemService(NotificationManager::class.java).getNotificationChannel(channel)
        return value == null || value.importance != NotificationManager.IMPORTANCE_NONE
    }

    fun canPost(context: Context, channel: String = LOW_BALANCE_CHANNEL): Boolean =
        runtimePermissionGranted(context) && NotificationManagerCompat.from(context).areNotificationsEnabled() &&
            channelEnabled(context, channel)

    internal fun openAppIntent(context: Context): PendingIntent = PendingIntent.getActivity(
        context, 0,
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    @Throws(SecurityException::class)
    fun post(context: Context, channel: String, tag: String?, id: Int, title: String, body: String) {
        ensureChannels(context)
        val notification = NotificationCompat.Builder(context, channel)
            .setSmallIcon(R.drawable.ic_notification_power)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(openAppIntent(context))
            .build()
        if (!runtimePermissionGranted(context)) throw SecurityException("notification permission")
        NotificationManagerCompat.from(context).notify(tag, id, notification)
    }
}

class AndroidReminderGateway(private val context: Context) : ReminderGateway {
    override fun canPostNotifications(): Boolean = PowerNotifications.canPost(context)
    override fun submit(title: String, body: String) =
        PowerNotifications.post(context, PowerNotifications.LOW_BALANCE_CHANNEL, null, (System.currentTimeMillis() % Int.MAX_VALUE).toInt(), title, body)
}

class PrefsReminderStateStore(context: Context) : ReminderStateStore {
    private val prefs = context.getSharedPreferences("low_balance_reminder_v1", Context.MODE_PRIVATE)
    override fun load(): ReminderState {
        val room = prefs.getString("room", null) ?: return ReminderState()
        val threshold = prefs.getString("threshold", null)?.toDoubleOrNull() ?: return ReminderState()
        return ReminderState(ReminderKey(room, threshold))
    }
    override fun save(state: ReminderState) = prefs.edit(commit = true) {
        val key = state.lastNotified
        if (key == null) clear() else { putString("room", key.room); putString("threshold", key.threshold.toString()) }
    }
}

/** Test notifications, independent of the real reminder state (iOS `DebugNotificationService`). */
class DebugNotificationService(private val context: Context) {
    private val prefs = context.getSharedPreferences("debug_notifications", Context.MODE_PRIVATE)

    val pendingCount: Int get() = prefs.getStringSet(PENDING, emptySet())!!.size

    val deliveredCount: Int
        get() = runCatching {
            context.getSystemService(NotificationManager::class.java).activeNotifications.count { it.tag == PowerNotifications.DEBUG_TAG }
        }.getOrDefault(0)

    fun send(delaySeconds: Int, lowBalance: Boolean = false) {
        if (!PowerNotifications.canPost(context, PowerNotifications.TEST_CHANNEL)) throw IllegalStateException("通知权限已关闭，请在系统设置中允许通知。")
        val id = (SystemClock.elapsedRealtime() % 1_000_000).toInt() + 2000
        if (delaySeconds <= 0) {
            deliver(context, id, lowBalance, delayed = false)
            Diagnostics.record(if (lowBalance) "低电量样式测试：系统已接受" else "通知测试：系统已接受，延迟 0 秒")
            return
        }
        prefs.edit(commit = true) { putStringSet(PENDING, prefs.getStringSet(PENDING, emptySet())!! + id.toString()) }
        val alarms = context.getSystemService(AlarmManager::class.java)
        val triggerAt = SystemClock.elapsedRealtime() + delaySeconds * 1000L
        val intent = pendingIntent(id, lowBalance)
        // An inexact alarm is deferred while the app sits in the background, which defeats the point of the
        // test, so use an exact one when the system allows it.
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()
        runCatching {
            if (exact) alarms.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, intent)
            else alarms.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, intent)
        }
        // Fallback for as long as this process lives; the shared pending set keeps it from double posting.
        Handler(Looper.getMainLooper()).postDelayed({
            if (claimPending(context, id)) runCatching { deliver(context, id, lowBalance, delayed = true) }
        }, delaySeconds * 1000L)
        Diagnostics.record("通知测试：已安排，延迟 $delaySeconds 秒" + if (exact) "" else "（系统未授予精确闹钟，可能延后）")
    }

    fun clearTests() {
        val pending = prefs.getStringSet(PENDING, emptySet())!!
        val alarms = context.getSystemService(AlarmManager::class.java)
        pending.mapNotNull(String::toIntOrNull).forEach { alarms.cancel(pendingIntent(it, false)) }
        prefs.edit(commit = true) { remove(PENDING) }
        val manager = context.getSystemService(NotificationManager::class.java)
        val delivered = runCatching { manager.activeNotifications.filter { it.tag == PowerNotifications.DEBUG_TAG } }.getOrDefault(emptyList())
        delivered.forEach { manager.cancel(it.tag, it.id) }
        Diagnostics.record("已清除测试通知：待发送 ${pending.size}，已投递 ${delivered.size}")
    }

    private fun pendingIntent(id: Int, lowBalance: Boolean): PendingIntent = PendingIntent.getBroadcast(
        context, id,
        Intent(context, DebugNotificationReceiver::class.java).putExtra(EXTRA_ID, id).putExtra(EXTRA_LOW, lowBalance),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    companion object {
        private const val PENDING = "pending"
        const val EXTRA_ID = "id"
        const val EXTRA_LOW = "low"

        fun deliver(context: Context, id: Int, lowBalance: Boolean, delayed: Boolean) {
            val title = if (lowBalance) "低电量提醒 · 测试" else "湖科电量 · 测试通知"
            val body = when {
                lowBalance -> "模拟剩余 12.50 度，低于 20 度提醒值。这是测试，不会改变实际电量或提醒记录。"
                delayed -> "延迟通知已送达，可用来检查后台和锁屏通知。"
                else -> "即时通知已送达，通知通道可以正常使用。"
            }
            PowerNotifications.post(context, PowerNotifications.TEST_CHANNEL, PowerNotifications.DEBUG_TAG, id, title, body)
        }

        /** Removes [id] from the pending set; true only for whoever gets there first. */
        internal fun claimPending(context: Context, id: Int): Boolean {
            val prefs = context.getSharedPreferences("debug_notifications", Context.MODE_PRIVATE)
            synchronized(DebugNotificationService::class.java) {
                val pending = prefs.getStringSet(PENDING, emptySet())!!
                if (!pending.contains(id.toString())) return false
                prefs.edit(commit = true) { putStringSet(PENDING, pending - id.toString()) }
                return true
            }
        }
    }
}

class DebugNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(DebugNotificationService.EXTRA_ID, 2000)
        if (!DebugNotificationService.claimPending(context, id)) return
        runCatching { DebugNotificationService.deliver(context, id, intent.getBooleanExtra(DebugNotificationService.EXTRA_LOW, false), delayed = true) }
    }
}
