package com.zebwqfox.hbustpower.data

import com.zebwqfox.hbustpower.BuildConfig
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.nio.charset.StandardCharsets

/** Where the config lives and which hosts may serve the APK. Both are compiled in; see gradle.properties. */
object CloudEndpoints {
    val configUrl: String = BuildConfig.CLOUD_CONFIG_URL

    val downloadHosts: List<String> =
        BuildConfig.CLOUD_DOWNLOAD_HOSTS.split(',').map { it.trim() }.filter(String::isNotEmpty)

    /** No address compiled in means the whole feature stays quiet: no requests, no update UI. */
    val isConfigured: Boolean
        get() = configUrl.startsWith("https://") && runCatching { URI(configUrl).host }.getOrNull() != null

    /** For the diagnostics screen; the host is enough to tell which build points where. */
    val configHost: String? get() = runCatching { URI(configUrl).host }.getOrNull()
}

/** What a fetch produced: fresh content, an unchanged file, or nothing because it did not work. */
sealed interface CloudFetch {
    data class Fresh(val json: String, val etag: String?) : CloudFetch
    data object NotModified : CloudFetch
    data class Failed(val reason: String) : CloudFetch
}

fun interface CloudConfigFetcher {
    fun fetch(etag: String?): CloudFetch
}

/**
 * Fetches the config file over plain HTTPS with no cookies, no credentials and no identifying parameters: the
 * request says nothing about who is asking beyond what any HTTPS request must reveal. The response is capped at
 * [MAX_BYTES] so a wrong URL cannot make the app download something large. A timestamp-only `cacheBust`
 * parameter avoids a shared CDN serving an older publication; `ETag` still lets the origin answer 304 when
 * the file itself did not change.
 */
class HttpCloudConfigFetcher(
    private val url: String = CloudEndpoints.configUrl,
    private val timeoutMillis: Int = 10_000,
) : CloudConfigFetcher {

    override fun fetch(etag: String?): CloudFetch {
        if (!CloudEndpoints.isConfigured) return CloudFetch.Failed("未配置更新地址")
        return runCatching { request(etag) }.getOrElse { error ->
            CloudFetch.Failed(error.localizedMessage?.takeIf(String::isNotBlank) ?: "网络请求失败")
        }
    }

    private fun request(etag: String?): CloudFetch {
        val connection = (URL(cacheBustedUrl(url, System.currentTimeMillis())).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            instanceFollowRedirects = false
            connectTimeout = timeoutMillis
            readTimeout = timeoutMillis
            useCaches = false
            setRequestProperty("Accept", "application/json")
            setRequestProperty("Cache-Control", "no-cache")
            setRequestProperty("User-Agent", "HBUSTPower/${BuildConfig.VERSION_NAME} (Android)")
            etag?.let { setRequestProperty("If-None-Match", it) }
        }
        try {
            return when (val status = connection.responseCode) {
                HttpURLConnection.HTTP_NOT_MODIFIED -> CloudFetch.NotModified
                HttpURLConnection.HTTP_OK -> {
                    val bytes = connection.inputStream.use { stream ->
                        val buffer = ByteArray(MAX_BYTES + 1)
                        var read = 0
                        while (read < buffer.size) {
                            val count = stream.read(buffer, read, buffer.size - read)
                            if (count < 0) break
                            read += count
                        }
                        if (read > MAX_BYTES) throw IOException("更新信息过大")
                        buffer.copyOf(read)
                    }
                    CloudFetch.Fresh(String(bytes, StandardCharsets.UTF_8), connection.getHeaderField("ETag"))
                }
                // Redirects are not followed: the file is expected to sit at the compiled-in address.
                else -> CloudFetch.Failed("服务器返回 $status")
            }
        } finally {
            connection.disconnect()
        }
    }

    private companion object {
        const val MAX_BYTES = 64 * 1024
    }
}

internal fun cacheBustedUrl(url: String, timestampMillis: Long): String {
    val fragmentAt = url.indexOf('#')
    val base = if (fragmentAt >= 0) url.substring(0, fragmentAt) else url
    val fragment = if (fragmentAt >= 0) url.substring(fragmentAt) else ""
    val separator = if ('?' in base) '&' else '?'
    return "$base${separator}cacheBust=$timestampMillis$fragment"
}
