package com.zebwqfox.hbustpower.notification

import com.zebwqfox.hbustpower.data.Diagnostics
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.Locale

/** What the reminder needs from the platform, so dedup rules can be unit tested. */
interface ReminderGateway {
    /** Runtime permission granted and the app/channel not blocked. Never prompts. */
    fun canPostNotifications(): Boolean

    /** Returns normally only when the system accepted the notification. */
    @Throws(Exception::class)
    fun submit(title: String, body: String)
}

interface ReminderStateStore {
    fun load(): ReminderState
    fun save(state: ReminderState)
}

/**
 * Remembers accepted submissions rather than merely a low reading (iOS `LowBalanceReminder`). Denied permission
 * and failed submissions stay eligible for the next refresh; evaluations are serialised; reset() invalidates
 * anything in flight.
 */
class LowBalanceReminder(
    private val gateway: ReminderGateway,
    private val store: ReminderStateStore,
) {
    private val mutex = Mutex()
    @Volatile private var generation = 0
    @Volatile var lastError: String? = null
        private set

    val diagnosticStatus: String
        get() = when {
            lastError != null -> "发送失败：$lastError"
            store.load().lastNotified != null -> "本轮低电量已提醒；回升后重新启用"
            else -> "本轮尚未发送低电量提醒"
        }

    suspend fun evaluate(balance: Double, threshold: Double, room: String?) {
        if (!balance.isFinite() || !threshold.isFinite() || threshold <= 0) return
        val expected = generation
        mutex.withLock {
            if (generation != expected) return
            val state = store.load()
            val decision = LowBalancePolicy.evaluate(balance, threshold, room, state)
            if (balance >= threshold) {
                if (state.lastNotified != null) Diagnostics.record("电量已回升，重新启用低电量提醒")
                store.save(decision.nextStateAfterAccepted)
                lastError = null
                return
            }
            if (!decision.shouldNotify) {
                Diagnostics.record("低电量提醒：本轮已发送，跳过重复提醒")
                return
            }
            if (!gateway.canPostNotifications()) {
                Diagnostics.record("低电量提醒：通知权限未允许，保留下次尝试")
                return
            }
            try {
                gateway.submit(
                    "宿舍电量偏低",
                    String.format(Locale.ROOT, "当前剩余 %.2f 度，低于 %.0f 度提醒值。", balance, threshold),
                )
                if (generation != expected) return
                store.save(decision.nextStateAfterAccepted)
                lastError = null
                Diagnostics.record("低电量提醒：系统已接受")
            } catch (error: Exception) {
                // A submission error must not consume the reminder; the next refresh retries.
                lastError = error.javaClass.simpleName
                Diagnostics.record("低电量提醒失败：$lastError")
            }
        }
    }

    fun reset() {
        generation++
        store.save(ReminderState())
        lastError = null
    }
}
