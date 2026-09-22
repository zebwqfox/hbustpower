package com.zebwqfox.hbustpower.data

import android.content.SharedPreferences
import android.os.Build
import androidx.core.content.edit
import com.zebwqfox.hbustpower.BuildConfig
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.util.Locale
import java.util.UUID

/**
 * What the app reports so the developer can tell which versions are still in use and which devices break.
 *
 * Everything here is either the app's own build information or the phone's public model name. There is no
 * hardware identifier: [installId] is a UUID this app generates on first use, it is not derived from anything,
 * it never leaves this device except in these reports, and resetting it or switching reporting off makes the
 * old one unreachable. Nothing the school knows about the user — account, dorm, balance, usage — is included,
 * and nothing is read that would need a permission.
 *
 * The wire format is shared with iOS (`Services/Telemetry.swift`) and the panel's `server/src/ingest.js`:
 * [osVersion] is the version string on both platforms, [osApiLevel] is Android's SDK integer and is absent
 * on iOS.
 */
data class TelemetryPayload(
    val installId: String,
    val platform: String = "android",
    val appVersionCode: Int = BuildConfig.VERSION_CODE,
    val appVersionName: String = BuildConfig.VERSION_NAME,
    val osVersion: String? = Build.VERSION.RELEASE,
    val osApiLevel: Int = Build.VERSION.SDK_INT,
    val manufacturer: String? = Build.MANUFACTURER,
    val model: String? = Build.MODEL,
    val abi: String? = Build.SUPPORTED_ABIS?.firstOrNull(),
    val locale: String = Locale.getDefault().toLanguageTag(),
    val channel: String = if (BuildConfig.DEBUG) "debug" else "release",
) {
    fun toJson(): String = JSONObject().apply {
        put("installId", installId)
        put("platform", platform)
        put("appVersionCode", appVersionCode)
        put("appVersionName", appVersionName)
        put("osApiLevel", osApiLevel)
        // `put(key, null)` removes the key in org.json; JSONObject.NULL keeps the shape stable for the server.
        put("osVersion", osVersion ?: JSONObject.NULL)
        put("manufacturer", manufacturer ?: JSONObject.NULL)
        put("model", model ?: JSONObject.NULL)
        put("abi", abi ?: JSONObject.NULL)
        put("locale", locale)
        put("channel", channel)
    }.toString()

    /** What the settings screen shows, so nobody has to take the description on faith. */
    fun humanReadable(): List<Pair<String, String>> = listOf(
        "安装标识" to installId,
        "应用版本" to "$appVersionName ($appVersionCode)",
        "系统版本" to "Android ${osVersion ?: "未知"} (API $osApiLevel)",
        "设备型号" to listOfNotNull(manufacturer, model).joinToString(" ").ifBlank { "未知" },
        "处理器架构" to (abi ?: "未知"),
        "语言" to locale,
        "渠道" to channel,
    )
}

object TelemetryEndpoint {
    val reportUrl: String = BuildConfig.TELEMETRY_URL

    /** No address compiled in means the switch never appears and nothing is ever sent. */
    val isConfigured: Boolean
        get() = reportUrl.startsWith("https://") && runCatching { URI(reportUrl).host }.getOrNull() != null

    val host: String? get() = runCatching { URI(reportUrl).host }.getOrNull()
}

fun interface TelemetrySender {
    /** True when the server accepted it; anything else just means "try again tomorrow". */
    fun send(payload: TelemetryPayload): Boolean
}

class HttpTelemetrySender(
    private val url: String = TelemetryEndpoint.reportUrl,
    private val timeoutMillis: Int = 10_000,
) : TelemetrySender {
    override fun send(payload: TelemetryPayload): Boolean = runCatching {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            instanceFollowRedirects = false
            connectTimeout = timeoutMillis
            readTimeout = timeoutMillis
            doOutput = true
            useCaches = false
            setRequestProperty("Content-Type", "application/json; charset=utf-8")
            setRequestProperty("User-Agent", "HBUSTPower/${BuildConfig.VERSION_NAME} (Android)")
        }
        try {
            connection.outputStream.use { it.write(payload.toJson().toByteArray(Charsets.UTF_8)) }
            connection.responseCode in 200..299
        } finally {
            connection.disconnect()
        }
    }.getOrDefault(false)
}

/**
 * Off until the user says yes, then at most one report a day. Every decision lives in preferences, so turning
 * it off stops the next report rather than scheduling one more.
 */
class TelemetryRepository(
    private val prefs: SharedPreferences,
    private val sender: TelemetrySender = HttpTelemetrySender(),
    private val clock: () -> Long = { System.currentTimeMillis() / 1000 },
    val isConfigured: Boolean = TelemetryEndpoint.isConfigured,
) {
    /**
     * On unless the user says otherwise. The switch is shown, already on, on the privacy consent screen before
     * they agree to anything, and again in settings — so "on by default" still means they were told.
     */
    var isEnabled: Boolean
        get() = prefs.getBoolean(KEY_ENABLED, true)
        set(value) {
            prefs.edit {
                putBoolean(KEY_ENABLED, value)
                // Turning it off forgets the identifier too, so switching back on starts a new one.
                if (!value) { remove(KEY_INSTALL_ID); remove(KEY_LAST_SENT) }
            }
        }

    val lastSentAt: Long get() = prefs.getLong(KEY_LAST_SENT, 0L)

    /** Created lazily, so a user who never turns this on never has one. */
    fun installId(): String = prefs.getString(KEY_INSTALL_ID, null) ?: UUID.randomUUID().toString().also {
        prefs.edit { putString(KEY_INSTALL_ID, it) }
    }

    fun resetInstallId(): String {
        prefs.edit { remove(KEY_INSTALL_ID); remove(KEY_LAST_SENT) }
        return installId()
    }

    fun payload(): TelemetryPayload = TelemetryPayload(installId = installId())

    /**
     * The same content, for showing in settings, without creating an identifier as a side effect: someone who
     * turned reporting off and only wants to check what it *would* send should not get a new one.
     */
    fun previewPayload(): TelemetryPayload = TelemetryPayload(
        installId = prefs.getString(KEY_INSTALL_ID, null) ?: "（开启后才会生成）",
    )

    fun shouldSend(force: Boolean = false): Boolean = when {
        !isConfigured || !isEnabled -> false
        force -> true
        // Never sent means due now, rather than "due once the clock has been running for a day".
        lastSentAt == 0L -> true
        else -> clock() - lastSentAt >= INTERVAL_SECONDS
    }

    /** Blocking: call it off the main thread. Returns true when something was actually sent and accepted. */
    fun report(force: Boolean = false): Boolean {
        if (!shouldSend(force)) return false
        if (!sender.send(payload())) return false
        prefs.edit { putLong(KEY_LAST_SENT, clock()) }
        return true
    }

    companion object {
        const val INTERVAL_SECONDS = 24L * 60 * 60
        private const val KEY_ENABLED = "telemetry_enabled"
        private const val KEY_INSTALL_ID = "telemetry_install_id"
        private const val KEY_LAST_SENT = "telemetry_last_sent"
    }
}
