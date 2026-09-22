package com.zebwqfox.hbustpower.notification

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LowBalancePolicyTest {
    @Test fun thresholdIsStrictAndAcceptedNotificationDeduplicates() {
        val initial = ReminderState()
        assertFalse(LowBalancePolicy.evaluate(20.0, 20.0, "101", initial).shouldNotify)
        val first = LowBalancePolicy.evaluate(19.99, 20.0, "101", initial)
        assertTrue(first.shouldNotify)
        assertFalse(LowBalancePolicy.evaluate(19.0, 20.0, "101", first.nextStateAfterAccepted).shouldNotify)
        assertTrue(LowBalancePolicy.evaluate(19.0, 15.0, "101", first.nextStateAfterAccepted).nextStateAfterAccepted.lastNotified == null)
    }

    @Test fun recoveryClearsReminderState() {
        val state = ReminderState(ReminderKey("101", 20.0))
        val recovered = LowBalancePolicy.evaluate(20.0, 20.0, "101", state)
        assertFalse(recovered.shouldNotify)
        assertNull(recovered.nextStateAfterAccepted.lastNotified)
    }
}
