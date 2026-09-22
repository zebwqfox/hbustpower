package com.zebwqfox.hbustpower.data

import org.json.JSONObject
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The promises the privacy policy makes about this, stated as tests: on by default but stopped for good the
 * moment it is switched off, the identifier deleted with it, at most one report a day, and no field beyond the
 * declared list ever leaving the device.
 */
class TelemetryTest {

    private class RecordingSender(var accept: Boolean = true) : TelemetrySender {
        val sent = mutableListOf<TelemetryPayload>()
        override fun send(payload: TelemetryPayload): Boolean {
            sent += payload
            return accept
        }
    }

    private fun repository(
        sender: TelemetrySender,
        now: () -> Long = { 1000L },
        prefs: FakePreferences = FakePreferences(),
    ) = TelemetryRepository(prefs, sender, now, isConfigured = true)

    @Test
    fun `on by default, and the consent screen shows the switch already on`() {
        val repo = repository(RecordingSender())
        assertTrue(repo.isEnabled)
        assertTrue(repo.shouldSend())
    }

    @Test
    fun `switching it off stops everything, and it stays off`() {
        val sender = RecordingSender()
        val prefs = FakePreferences()
        val repo = repository(sender, prefs = prefs)
        repo.isEnabled = false

        assertFalse(repo.shouldSend())
        assertFalse(repo.shouldSend(force = true))
        assertFalse(repo.report())
        assertFalse(repo.report(force = true))
        assertTrue(sender.sent.isEmpty())

        // A fresh repository over the same preferences must not revert to the default.
        assertFalse(repository(sender, prefs = prefs).isEnabled)
    }

    @Test
    fun `an unconfigured build never sends, even if the flag somehow got set`() {
        val prefs = FakePreferences()
        val sender = RecordingSender()
        val repo = TelemetryRepository(prefs, sender, { 1000L }, isConfigured = false)
        repo.isEnabled = true
        assertFalse(repo.shouldSend(force = true))
        assertFalse(repo.report(force = true))
        assertTrue(sender.sent.isEmpty())
    }

    @Test
    fun `turning it off before the first report means no identifier is ever created`() {
        val prefs = FakePreferences()
        val repo = repository(RecordingSender(), prefs = prefs)
        // What the consent screen does when someone flips the switch off before agreeing.
        repo.isEnabled = false
        repo.previewPayload()
        repo.report(force = true)
        assertNull(prefs.getString("telemetry_install_id", null))
    }

    @Test
    fun `the identifier appears only when a report is actually made`() {
        val prefs = FakePreferences()
        val repo = repository(RecordingSender(), prefs = prefs)
        repo.previewPayload()
        assertNull(prefs.getString("telemetry_install_id", null), "looking is not reporting")

        repo.report()
        assertTrue(prefs.getString("telemetry_install_id", null)!!.isNotBlank())
    }

    @Test
    fun `turning it off forgets the identifier`() {
        val prefs = FakePreferences()
        val repo = repository(RecordingSender(), prefs = prefs)
        val first = repo.installId()

        repo.isEnabled = false
        assertNull(prefs.getString("telemetry_install_id", null))
        assertEquals(0L, repo.lastSentAt)

        repo.isEnabled = true
        assertNotEquals(first, repo.installId())
    }

    @Test
    fun `resetting gives a new identifier`() {
        val repo = repository(RecordingSender())
        val first = repo.installId()
        assertNotEquals(first, repo.resetInstallId())
    }

    @Test
    fun `at most one report a day, unless forced`() {
        var now = 1000L
        val sender = RecordingSender()
        val repo = repository(sender, now = { now })

        assertTrue(repo.report())
        assertEquals(1, sender.sent.size)

        now += 3600
        assertFalse(repo.report())
        assertEquals(1, sender.sent.size, "an hour later is the same day")

        assertTrue(repo.report(force = true))
        assertEquals(2, sender.sent.size, "the settings switch forces one immediately")

        now += TelemetryRepository.INTERVAL_SECONDS
        assertTrue(repo.report())
        assertEquals(3, sender.sent.size)
    }

    @Test
    fun `a rejected report does not count as sent`() {
        var now = 1000L
        val sender = RecordingSender(accept = false)
        val repo = repository(sender, now = { now })

        assertFalse(repo.report())
        assertEquals(0L, repo.lastSentAt)
        // Still due, so the next launch tries again rather than waiting a day.
        assertTrue(repo.shouldSend())
    }

    @Test
    fun `the payload carries only the declared fields`() {
        val json = JSONObject(TelemetryPayload(installId = "id").toJson())
        assertEquals(
            listOf(
                "abi", "appVersionCode", "appVersionName", "channel", "installId",
                "locale", "manufacturer", "model", "osApiLevel", "osVersion", "platform",
            ),
            json.keys().asSequence().sorted().toList(),
        )
        assertEquals("android", json.getString("platform"))
    }

    @Test
    fun `the preview shows the same things the payload sends`() {
        val labels = TelemetryPayload(installId = "id").humanReadable().map { it.first }
        assertEquals(
            listOf("安装标识", "应用版本", "系统版本", "设备型号", "处理器架构", "语言", "渠道"),
            labels,
        )
    }
}
