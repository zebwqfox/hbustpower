package com.zebwqfox.hbustpower.data

import com.zebwqfox.hbustpower.HandoffFixtures
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import java.nio.charset.Charset

class ElectricityServiceTest {
    @Test fun decodesGb18030AndUtf8WithoutReplacingCharacters() {
        val text = "剩余购电 -12.50 度 & 照明"
        assertEquals(text, HtmlDecoding.decode(text.toByteArray(Charset.forName("GB18030"))))
        assertEquals(text, HtmlDecoding.decode(text.toByteArray(Charsets.UTF_8)))
    }
    @Test fun unauthorizedStatusIsAuthenticationFailure() = runBlocking {
        for (status in listOf(401, 403)) {
            val service = ElectricityService(HttpFetcher { HttpResult(it, status, byteArrayOf()) })
            val failure = runCatching { service.fetchCurrentSession() }.exceptionOrNull()
            assertTrue(failure is ElectricityException.AuthenticationRequired)
        }
    }
    @Test fun anySecondaryPageFailureFailsEntireRefresh() = runBlocking {
        val service = ElectricityService(HttpFetcher { url ->
            if (url == SchoolEndpoints.HOME_URL) HttpResult(url, 200, HandoffFixtures.html("home.html").toByteArray())
            else HttpResult(url, 500, byteArrayOf())
        })
        assertTrue(runCatching { service.fetchCurrentSession() }.exceptionOrNull() is ElectricityException.InvalidResponse)
    }
    @Test fun invalidRedirectNeverMakesNetworkRequest() = runBlocking {
        var calls = 0
        val service = ElectricityService(HttpFetcher { calls++; error("unexpected request") })
        assertTrue(runCatching { service.establishSession("https://example.com/") }.exceptionOrNull() is ElectricityException.InvalidRedirect)
        assertEquals(0, calls)
    }
}
