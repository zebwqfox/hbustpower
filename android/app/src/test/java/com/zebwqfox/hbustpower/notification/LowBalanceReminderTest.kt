package com.zebwqfox.hbustpower.notification

import kotlinx.coroutines.*
import org.junit.Assert.*
import org.junit.Test

class LowBalanceReminderTest {
    private class Store : ReminderStateStore {
        var state = ReminderState()
        override fun load() = state
        override fun save(state: ReminderState) { this.state = state }
    }
    private class Gateway : ReminderGateway {
        var allowed = true; var fail = false; var posted = 0
        override fun canPostNotifications() = allowed
        override fun submit(title: String, body: String) { if (fail) error("failed"); posted++ }
    }
    @Test fun deniedAndFailedSubmissionsDoNotConsumeReminder() = runBlocking {
        val gateway = Gateway(); val store = Store(); val reminder = LowBalanceReminder(gateway, store)
        gateway.allowed = false; reminder.evaluate(19.99, 20.0, "a")
        assertNull(store.state.lastNotified)
        gateway.allowed = true; gateway.fail = true; reminder.evaluate(19.99, 20.0, "a")
        assertNull(store.state.lastNotified)
        gateway.fail = false; reminder.evaluate(19.99, 20.0, "a")
        assertEquals(1, gateway.posted)
    }
    @Test fun concurrentChecksAndProcessRestartDoNotDuplicate() = runBlocking {
        val gateway = Gateway(); val store = Store(); val reminder = LowBalanceReminder(gateway, store)
        coroutineScope { repeat(30) { launch(Dispatchers.Default) { reminder.evaluate(19.99, 20.0, "a") } } }
        LowBalanceReminder(gateway, store).evaluate(19.99, 20.0, "a")
        assertEquals(1, gateway.posted)
        reminder.evaluate(20.0, 20.0, "a"); reminder.evaluate(0.0, 20.0, "a")
        reminder.evaluate(-1.0, 20.0, "b"); reminder.evaluate(-1.0, 30.0, "b")
        assertEquals(4, gateway.posted)
    }
}
