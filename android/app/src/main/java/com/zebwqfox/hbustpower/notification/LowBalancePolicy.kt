package com.zebwqfox.hbustpower.notification

data class ReminderKey(val room: String, val threshold: Double)

data class ReminderState(val lastNotified: ReminderKey? = null)

data class ReminderDecision(
    val shouldNotify: Boolean,
    val nextStateAfterAccepted: ReminderState,
)

object LowBalancePolicy {
    fun evaluate(
        balance: Double,
        threshold: Double,
        room: String?,
        state: ReminderState,
    ): ReminderDecision {
        val key = ReminderKey(room.orEmpty(), threshold)
        if (balance >= threshold) return ReminderDecision(false, ReminderState())
        return ReminderDecision(
            shouldNotify = state.lastNotified != key,
            nextStateAfterAccepted = ReminderState(lastNotified = key),
        )
    }
}
