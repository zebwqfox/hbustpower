package com.zebwqfox.hbustpower.data

import android.content.SharedPreferences
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The parts that decide when the app talks to the network and what the user is shown afterwards: the daily
 * throttle, the ETag round trip, and not throwing away a good cached copy when a bad one arrives.
 */
class CloudConfigRepositoryTest {

    private val hosts = listOf("dl.example.com")

    private fun json(versionCode: Int = 200, noticeId: String = "n1") = """
        {"update":{"versionCode":$versionCode,"versionName":"2.0.0","downloadUrl":"https://dl.example.com/a.apk"},
         "notice":{"id":"$noticeId","body":"维护"}}
    """.trimIndent()

    private class RecordingFetcher(var next: () -> CloudFetch) : CloudConfigFetcher {
        var calls = 0
        var lastEtag: String? = null
        override fun fetch(etag: String?): CloudFetch {
            calls++
            lastEtag = etag
            return next()
        }
    }

    private fun repository(
        fetcher: CloudConfigFetcher,
        currentVersionCode: Int = 190,
        now: () -> Long,
        prefs: SharedPreferences = FakePreferences(),
    ) = CloudConfigRepository(prefs, currentVersionCode, fetcher, hosts, now, isConfigured = true)

    @Test
    fun `a fresh fetch is stored and offered`() {
        var now = 1000L
        val fetcher = RecordingFetcher { CloudFetch.Fresh(json(), "etag-1") }
        val repo = repository(fetcher, now = { now })

        val state = repo.refresh(CloudRefreshTrigger.LAUNCH)
        assertEquals(1000L, state.lastCheckedAtEpochSeconds)
        assertNull(state.error)
        assertEquals(200, repo.pendingUpdate()?.versionCode)
        assertEquals("n1", repo.activeNotice()?.id)
    }

    @Test
    fun `every launch checks, because a kill switch that waits a day is not a kill switch`() {
        var now = 1000L
        val fetcher = RecordingFetcher { CloudFetch.Fresh(json(), null) }
        val repo = repository(fetcher, now = { now })

        repeat(3) {
            repo.refresh(CloudRefreshTrigger.LAUNCH)
            now += 60
        }
        assertEquals(3, fetcher.calls, "cold starts are never throttled")

        repo.refresh(CloudRefreshTrigger.MANUAL)
        assertEquals(4, fetcher.calls, "asking by hand always asks")
    }

    @Test
    fun `returning to the foreground is throttled, so app switching does not hammer the server`() {
        var now = 1000L
        val fetcher = RecordingFetcher { CloudFetch.Fresh(json(), null) }
        val repo = repository(fetcher, now = { now })

        repo.refresh(CloudRefreshTrigger.FOREGROUND)
        assertEquals(1, fetcher.calls, "nothing cached yet, so this one is due")

        now += 60
        repo.refresh(CloudRefreshTrigger.FOREGROUND)
        assertEquals(1, fetcher.calls, "a minute later is the same visit")

        now += CloudConfigRepository.FOREGROUND_INTERVAL_SECONDS
        repo.refresh(CloudRefreshTrigger.FOREGROUND)
        assertEquals(2, fetcher.calls)

        // A cold start in between ignores the floor entirely.
        repo.refresh(CloudRefreshTrigger.LAUNCH)
        assertEquals(3, fetcher.calls)
    }

    @Test
    fun `the stored etag goes back out and a 304 only moves the clock`() {
        var now = 1000L
        val fetcher = RecordingFetcher { CloudFetch.Fresh(json(), "etag-1") }
        val repo = repository(fetcher, now = { now })
        repo.refresh(CloudRefreshTrigger.MANUAL)
        assertNull(fetcher.lastEtag, "nothing cached on the first call")

        fetcher.next = { CloudFetch.NotModified }
        now = 5000L
        val state = repo.refresh(CloudRefreshTrigger.MANUAL)
        assertEquals("etag-1", fetcher.lastEtag)
        assertEquals(5000L, state.lastCheckedAtEpochSeconds)
        assertEquals(200, repo.pendingUpdate()?.versionCode, "the cached copy survives a 304")
    }

    @Test
    fun `a failure keeps the last good copy and only a manual check reports it`() {
        var now = 1000L
        val fetcher = RecordingFetcher { CloudFetch.Fresh(json(), null) }
        val repo = repository(fetcher, now = { now })
        repo.refresh(CloudRefreshTrigger.MANUAL)

        fetcher.next = { CloudFetch.Failed("网络请求失败") }
        assertNull(repo.refresh(CloudRefreshTrigger.LAUNCH).error, "a silent check must not interrupt anyone")

        assertEquals("网络请求失败", repo.refresh(CloudRefreshTrigger.MANUAL).error)
        assertEquals(200, repo.pendingUpdate()?.versionCode, "the cached copy survives a failure")
    }

    @Test
    fun `garbage does not replace a good cached copy`() {
        val now = 1000L
        val fetcher = RecordingFetcher { CloudFetch.Fresh(json(), null) }
        val repo = repository(fetcher, now = { now })
        repo.refresh(CloudRefreshTrigger.MANUAL)

        fetcher.next = { CloudFetch.Fresh("not json at all", null) }
        val state = repo.refresh(CloudRefreshTrigger.MANUAL)
        assertEquals("更新信息格式不正确", state.error)
        assertEquals(200, repo.pendingUpdate()?.versionCode)
    }

    @Test
    fun `skipping a version hides it until a newer one arrives`() {
        val now = 1000L
        val fetcher = RecordingFetcher { CloudFetch.Fresh(json(), null) }
        val repo = repository(fetcher, now = { now })
        repo.refresh(CloudRefreshTrigger.MANUAL)

        repo.skip(repo.pendingUpdate()!!)
        assertNull(repo.pendingUpdate())

        fetcher.next = { CloudFetch.Fresh(json(versionCode = 201), null) }
        repo.refresh(CloudRefreshTrigger.MANUAL)
        assertEquals(201, repo.pendingUpdate()?.versionCode)
    }

    @Test
    fun `a required upgrade is offered even after being skipped`() {
        val now = 1000L
        val body = """{"minSupportedVersionCode":195,"update":{"versionCode":200,"versionName":"2.0.0"}}"""
        val fetcher = RecordingFetcher { CloudFetch.Fresh(body, null) }
        val repo = repository(fetcher, currentVersionCode = 190, now = { now })
        repo.refresh(CloudRefreshTrigger.MANUAL)

        repo.skip(repo.pendingUpdate()!!)
        assertTrue(repo.mustUpgrade())
        assertEquals(200, repo.pendingUpdate()?.versionCode)
    }

    @Test
    fun `update check flag hides version offers without stopping notices`() {
        val now = 1000L
        val body = """{"minSupportedVersionCode":195,
            "update":{"versionCode":200,"versionName":"2.0.0"},
            "notice":{"id":"n1","body":"维护"},
            "flags":{"updateCheck":false}}"""
        val fetcher = RecordingFetcher { CloudFetch.Fresh(body, null) }
        val repo = repository(fetcher, currentVersionCode = 190, now = { now })

        repo.refresh(CloudRefreshTrigger.LAUNCH)

        assertNull(repo.pendingUpdate())
        assertFalse(repo.mustUpgrade())
        assertEquals("n1", repo.activeNotice()?.id, "config fetches continue so notices and flags can recover")
    }

    @Test
    fun `a dismissed notice does not come back, a new one does`() {
        val now = 1000L
        val fetcher = RecordingFetcher { CloudFetch.Fresh(json(), null) }
        val repo = repository(fetcher, now = { now })
        repo.refresh(CloudRefreshTrigger.MANUAL)

        repo.dismissNotice(repo.activeNotice()!!)
        assertNull(repo.activeNotice())

        fetcher.next = { CloudFetch.Fresh(json(noticeId = "n2"), null) }
        repo.refresh(CloudRefreshTrigger.MANUAL)
        assertEquals("n2", repo.activeNotice()?.id)
    }

    @Test
    fun `clearing forgets the cache, the etag and what was dismissed`() {
        val now = 1000L
        val fetcher = RecordingFetcher { CloudFetch.Fresh(json(), "etag-1") }
        val repo = repository(fetcher, now = { now })
        repo.refresh(CloudRefreshTrigger.MANUAL)
        repo.dismissNotice(repo.activeNotice()!!)

        repo.clear()
        assertEquals(CloudConfig.EMPTY, repo.cached())
        assertEquals(0L, repo.lastCheckedAt())
        assertTrue(repo.state().isEmpty)

        repo.refresh(CloudRefreshTrigger.MANUAL)
        assertNull(fetcher.lastEtag)
        assertEquals("n1", repo.activeNotice()?.id)
    }

    @Test
    fun `flags fail open before anything has been fetched`() {
        val repo = repository(RecordingFetcher { CloudFetch.Failed("x") }, now = { 0L })
        assertTrue(repo.isEnabled(CloudConfig.FLAG_CAMPUS_CARD))
        assertFalse(repo.mustUpgrade())
        assertNull(repo.pendingUpdate())
    }
}
