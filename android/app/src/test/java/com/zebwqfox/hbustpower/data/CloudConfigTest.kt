package com.zebwqfox.hbustpower.data

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The config comes off the network, so the parser has to survive whatever arrives: truncated files, fields of the
 * wrong type, a newer publisher writing keys this build has never heard of, and a download link pointing
 * somewhere it should not.
 */
class CloudConfigTest {

    private val hosts = listOf("example.com", "dl.example.com")

    private val full = """
        {
          "publishedAt": "2026-09-22",
          "minSupportedVersionCode": 180,
          "update": {
            "versionCode": 200,
            "versionName": "2.0.0",
            "notes": ["修了空调用量", "  ", "新增检查更新"],
            "downloadUrl": "https://dl.example.com/a.apk",
            "sha256": "${"a".repeat(64)}",
            "sizeBytes": 9437184
          },
          "notice": {
            "id": "n1", "title": "维护", "body": "周六维护", "level": "warning", "expiresAt": 2000
          },
          "flags": { "campusCard": false, "recharge": true }
        }
    """.trimIndent()

    @Test
    fun `reads every field`() {
        val config = CloudConfig.parse(full, hosts)
        assertEquals("2026-09-22", config.publishedAt)
        assertEquals(180, config.minSupportedVersionCode)
        val update = config.update!!
        assertEquals(200, update.versionCode)
        assertEquals("2.0.0", update.versionName)
        // Blank lines in notes would render as empty bullets.
        assertEquals(listOf("修了空调用量", "新增检查更新"), update.notes)
        assertEquals("https://dl.example.com/a.apk", update.downloadUrl)
        assertEquals(9437184L, update.sizeBytes)
        assertEquals(CloudConfig.Notice.Level.WARNING, config.notice?.level)
    }

    @Test
    fun `malformed input never throws`() {
        listOf("", "   ", "not json", "[]", "{", """{"update": 5}""", """{"notice": "hello"}""")
            .forEach { assertEquals(CloudConfig.EMPTY, CloudConfig.parse(it, hosts), "input: $it") }
    }

    @Test
    fun `unknown keys are ignored so a newer file still works on an older build`() {
        val config = CloudConfig.parse(
            """{"update":{"versionCode":200,"versionName":"2.0.0","rolloutPercent":50},"newSection":{"a":1}}""",
            hosts,
        )
        assertEquals(200, config.update?.versionCode)
    }

    @Test
    fun `an update without a usable version is dropped`() {
        assertNull(CloudConfig.parse("""{"update":{"versionName":"2.0.0"}}""", hosts).update)
        assertNull(CloudConfig.parse("""{"update":{"versionCode":200}}""", hosts).update)
        assertNull(CloudConfig.parse("""{"update":{"versionCode":0,"versionName":"x"}}""", hosts).update)
    }

    @Test
    fun `only an update newer than this build is offered`() {
        val config = CloudConfig.parse(full, hosts)
        assertNull(config.updateAvailable(200))
        assertNull(config.updateAvailable(201))
        assertEquals(200, config.updateAvailable(199)?.versionCode)
    }

    @Test
    fun `mustUpgrade only fires below the published floor`() {
        val config = CloudConfig.parse(full, hosts)
        assertTrue(config.mustUpgrade(179))
        assertFalse(config.mustUpgrade(180))
        // Without a floor the app never tells anyone to upgrade.
        assertFalse(CloudConfig.parse("""{"update":{"versionCode":200,"versionName":"x"}}""", hosts).mustUpgrade(1))
    }

    @Test
    fun `download links off the allowed hosts are dropped`() {
        val rejected = listOf(
            "http://dl.example.com/a.apk",          // not HTTPS
            "https://evil.com/a.apk",               // wrong host
            "https://dl.example.com.evil.com/a.apk",// suffix that only looks right
            "https://notexample.com/a.apk",         // must match on a dot boundary
            "https://user@dl.example.com/a.apk",    // credentials in the authority
            "ftp://dl.example.com/a.apk",
            "javascript:alert(1)",
            "/a.apk",
            "",
        )
        rejected.forEach { url ->
            assertFalse(CloudConfig.isTrustedDownload(url, hosts), "should reject: $url")
            val config = CloudConfig.parse("""{"update":{"versionCode":9,"versionName":"x","downloadUrl":"$url"}}""", hosts)
            assertNull(config.update?.downloadUrl, "should drop: $url")
        }
        assertTrue(CloudConfig.isTrustedDownload("https://example.com/a.apk", hosts))
        assertTrue(CloudConfig.isTrustedDownload("https://cdn.dl.example.com/a.apk", hosts))
    }

    @Test
    fun `no allowed hosts means no download link at all`() {
        assertFalse(CloudConfig.isTrustedDownload("https://dl.example.com/a.apk", emptyList()))
    }

    @Test
    fun `a bad sha256 is dropped rather than shown`() {
        fun sha(value: String) =
            CloudConfig.parse("""{"update":{"versionCode":9,"versionName":"x","sha256":"$value"}}""", hosts).update?.sha256
        assertNull(sha("abc"))
        assertNull(sha("z".repeat(64)))
        assertEquals("a".repeat(64), sha("A".repeat(64)))
    }

    @Test
    fun `a notice expires on its own`() {
        val config = CloudConfig.parse(full, hosts)
        assertEquals("n1", config.activeNotice(1999, emptySet())?.id)
        assertNull(config.activeNotice(2000, emptySet()))
        assertNull(config.activeNotice(5000, emptySet()))
    }

    @Test
    fun `a dismissed notice stays gone, unless it is not dismissible`() {
        val config = CloudConfig.parse(full, hosts)
        assertNull(config.activeNotice(100, setOf("n1")))
        val sticky = CloudConfig.parse("""{"notice":{"id":"n1","body":"x","dismissible":false}}""", hosts)
        assertEquals("n1", sticky.activeNotice(100, setOf("n1"))?.id)
    }

    @Test
    fun `a notice without an id or body is dropped`() {
        assertNull(CloudConfig.parse("""{"notice":{"body":"x"}}""", hosts).notice)
        assertNull(CloudConfig.parse("""{"notice":{"id":"n1"}}""", hosts).notice)
        assertNull(CloudConfig.parse("""{"notice":{"id":" ","body":"x"}}""", hosts).notice)
    }

    @Test
    fun `a notice with no expiry stays until dismissed`() {
        val config = CloudConfig.parse("""{"notice":{"id":"n1","body":"x"}}""", hosts)
        assertEquals("n1", config.activeNotice(Long.MAX_VALUE, emptySet())?.id)
    }

    @Test
    fun `flags fail open`() {
        val config = CloudConfig.parse(full, hosts)
        assertFalse(config.isEnabled(CloudConfig.FLAG_CAMPUS_CARD))
        assertTrue(config.isEnabled(CloudConfig.FLAG_RECHARGE))
        // Never published, and the whole config missing: both leave the feature on.
        assertTrue(config.isEnabled("somethingNew"))
        assertTrue(CloudConfig.EMPTY.isEnabled(CloudConfig.FLAG_CAMPUS_CARD))
    }
}
