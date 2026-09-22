package com.zebwqfox.hbustpower.data

import android.webkit.CookieManager
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.nio.ByteBuffer
import java.nio.charset.Charset
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets

data class HttpResult(val finalUrl: String, val statusCode: Int, val body: ByteArray)

/** GET only; the service never submits forms. */
fun interface HttpFetcher {
    @Throws(IOException::class)
    fun get(url: String): HttpResult
}

/**
 * Cookies shared by the login/recharge WebViews and native requests. Android's WebView [CookieManager] is the
 * single jar: it already applies domain, path, secure and expiry rules, so nothing is flattened into one
 * cross-domain header and there is no second store to drift out of sync.
 */
interface CookieBridge {
    fun cookieHeader(url: String): String?
    fun store(url: String, setCookie: String)
    fun flush()
    fun clearAll()
    fun count(urls: List<String>): Int
}

class WebViewCookieBridge : CookieBridge {
    private val manager: CookieManager get() = CookieManager.getInstance()
    override fun cookieHeader(url: String): String? = manager.getCookie(url)
    override fun store(url: String, setCookie: String) = manager.setCookie(url, setCookie)
    override fun flush() = manager.flush()
    override fun clearAll() {
        manager.removeAllCookies(null)
        manager.flush()
    }
    override fun count(urls: List<String>): Int = urls
        .flatMap { url -> manager.getCookie(url).orEmpty().split(';').map { it.substringBefore('=').trim() } }
        .filter(String::isNotEmpty)
        .toSet()
        .size
}

/**
 * Minimal HttpURLConnection client for the school hosts. Redirects are followed by hand so cookies set on
 * each hop (for example while exchanging the synjones-auth redirect) reach the shared jar.
 */
class SessionHttpClient(
    private val cookies: CookieBridge,
    private val userAgent: () -> String,
    private val timeoutMillis: Int = 20_000,
) : HttpFetcher {
    override fun get(url: String): HttpResult {
        var current = url
        repeat(MAX_REDIRECTS) {
            require(SchoolEndpoints.isSchoolHost(current) && SchoolEndpoints.isAllowedNavigation(current)) { "只允许访问学校域名" }
            val connection = (URL(current).openConnection() as HttpURLConnection).apply {
                instanceFollowRedirects = false
                connectTimeout = timeoutMillis
                readTimeout = timeoutMillis
                requestMethod = "GET"
                setRequestProperty("User-Agent", userAgent())
                setRequestProperty("Referer", SchoolEndpoints.HOME_URL)
                setRequestProperty("Accept", "text/html,application/xhtml+xml,*/*;q=0.8")
                cookies.cookieHeader(current)?.takeIf(String::isNotBlank)?.let { setRequestProperty("Cookie", it) }
            }
            try {
                val code = connection.responseCode
                connection.headerFields.entries
                    .filter { it.key.equals("Set-Cookie", ignoreCase = true) }
                    .flatMap { it.value }
                    .forEach { cookies.store(current, it) }
                val location = connection.getHeaderField("Location")
                if (code in 300..399 && location != null) {
                    current = URI(current).resolve(location.trim()).toString()
                    if (SchoolEndpoints.isOfficialAuthHost(current)) throw ElectricityException.AuthenticationRequired()
                    return@repeat
                }
                val stream = if (code >= 400) connection.errorStream else connection.inputStream
                val body = stream?.use { it.readBytes() } ?: ByteArray(0)
                cookies.flush()
                return HttpResult(current, code, body)
            } finally {
                connection.disconnect()
            }
        }
        throw IOException("重定向次数过多")
    }

    private companion object {
        const val MAX_REDIRECTS = 10
    }
}

/** UTF-8 first, then GB18030, as the iOS service does. */
object HtmlDecoding {
    fun decode(bytes: ByteArray): String? =
        strict(bytes, StandardCharsets.UTF_8) ?: strict(bytes, Charset.forName("GB18030"))

    private fun strict(bytes: ByteArray, charset: Charset): String? = runCatching {
        charset.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
            .decode(ByteBuffer.wrap(bytes))
            .toString()
    }.getOrNull()
}
