package com.zebwqfox.hbustpower.data

import android.content.SharedPreferences
import androidx.core.content.edit

/** Why a refresh happened, which decides whether the daily throttle applies and whether errors are shown. */
enum class CloudRefreshTrigger { LAUNCH, MANUAL }

/** The result of a refresh, as the UI needs to see it. */
data class CloudConfigState(
    val config: CloudConfig = CloudConfig.EMPTY,
    val lastCheckedAtEpochSeconds: Long = 0L,
    /** Set only after a manual check, so a failed silent check never interrupts anyone. */
    val error: String? = null,
    val isChecking: Boolean = false,
) {
    val isEmpty: Boolean get() = config == CloudConfig.EMPTY && lastCheckedAtEpochSeconds == 0L
}

/**
 * Keeps the last config on disk and decides when to ask for a new one: once a day on launch, or whenever the
 * user taps "检查更新". The cached copy is what the UI reads, so the app shows the same notice offline as it did
 * online and never waits on the network to draw a screen.
 *
 * Nothing here is sent anywhere. The class only reads a file and remembers what the user dismissed.
 */
class CloudConfigRepository(
    private val prefs: SharedPreferences,
    private val currentVersionCode: Int,
    private val fetcher: CloudConfigFetcher = HttpCloudConfigFetcher(),
    private val trustedDownloadHosts: List<String> = CloudEndpoints.downloadHosts,
    private val clock: () -> Long = { System.currentTimeMillis() / 1000 },
    /** False in builds with no address compiled in; nothing here then touches the network. */
    val isConfigured: Boolean = CloudEndpoints.isConfigured,
) {

    /** The config as last fetched, or empty when nothing has ever been fetched. */
    fun cached(): CloudConfig = prefs.getString(KEY_JSON, null)
        ?.let { CloudConfig.parse(it, trustedDownloadHosts) }
        ?: CloudConfig.EMPTY

    fun lastCheckedAt(): Long = prefs.getLong(KEY_CHECKED_AT, 0L)

    fun state(error: String? = null): CloudConfigState =
        CloudConfigState(config = cached(), lastCheckedAtEpochSeconds = lastCheckedAt(), error = error)

    fun shouldCheck(trigger: CloudRefreshTrigger): Boolean = when {
        !isConfigured -> false
        trigger == CloudRefreshTrigger.MANUAL -> true
        // Never checked means due now, rather than "due once the clock has been running for a day".
        lastCheckedAt() == 0L -> true
        else -> clock() - lastCheckedAt() >= CHECK_INTERVAL_SECONDS
    }

    /**
     * Fetches unless the daily throttle says otherwise, stores what came back, and returns the state to show.
     * Blocking: call it off the main thread.
     */
    fun refresh(trigger: CloudRefreshTrigger): CloudConfigState {
        if (!shouldCheck(trigger)) return state()
        return when (val fetch = fetcher.fetch(prefs.getString(KEY_ETAG, null))) {
            is CloudFetch.Fresh -> {
                val parsed = CloudConfig.parse(fetch.json, trustedDownloadHosts)
                if (parsed == CloudConfig.EMPTY && fetch.json.isNotBlank()) {
                    // Keep the last good copy rather than replacing it with nothing.
                    state(error = "更新信息格式不正确".takeIf { trigger == CloudRefreshTrigger.MANUAL })
                } else {
                    prefs.edit {
                        putString(KEY_JSON, fetch.json)
                        putLong(KEY_CHECKED_AT, clock())
                        if (fetch.etag.isNullOrBlank()) remove(KEY_ETAG) else putString(KEY_ETAG, fetch.etag)
                    }
                    state()
                }
            }
            CloudFetch.NotModified -> {
                prefs.edit { putLong(KEY_CHECKED_AT, clock()) }
                state()
            }
            is CloudFetch.Failed ->
                state(error = fetch.reason.takeIf { trigger == CloudRefreshTrigger.MANUAL })
        }
    }

    // --- what the user has already dealt with ---

    /** The update to offer, unless the user said "跳过这个版本" for exactly that build. */
    fun pendingUpdate(config: CloudConfig = cached()): CloudConfig.Update? =
        config.updateAvailable(currentVersionCode)
            ?.takeIf { config.mustUpgrade(currentVersionCode) || it.versionCode != skippedVersionCode }

    var skippedVersionCode: Int
        get() = prefs.getInt(KEY_SKIPPED, 0)
        private set(value) = prefs.edit { putInt(KEY_SKIPPED, value) }

    fun skip(update: CloudConfig.Update) {
        skippedVersionCode = update.versionCode
    }

    fun activeNotice(config: CloudConfig = cached()): CloudConfig.Notice? =
        config.activeNotice(clock(), dismissedNoticeIds())

    fun dismissNotice(notice: CloudConfig.Notice) {
        // Keep the list short: ids pile up otherwise, and an old id can never come back into view.
        val kept = (listOf(notice.id) + dismissedNoticeIds()).distinct().take(MAX_DISMISSED)
        prefs.edit { putStringSet(KEY_DISMISSED, kept.toSet()) }
    }

    private fun dismissedNoticeIds(): Set<String> = prefs.getStringSet(KEY_DISMISSED, emptySet()) ?: emptySet()

    /** Feature switches fail open, so a missing or unreachable config changes nothing. */
    fun isEnabled(flag: String): Boolean = cached().isEnabled(flag)

    fun mustUpgrade(): Boolean = cached().mustUpgrade(currentVersionCode)

    /** Forgets everything fetched, for the "清除本地数据" path in settings. */
    fun clear() = prefs.edit {
        remove(KEY_JSON); remove(KEY_ETAG); remove(KEY_CHECKED_AT); remove(KEY_SKIPPED); remove(KEY_DISMISSED)
    }

    companion object {
        const val CHECK_INTERVAL_SECONDS = 24L * 60 * 60
        private const val MAX_DISMISSED = 20
        private const val KEY_JSON = "cloud_config_json"
        private const val KEY_ETAG = "cloud_config_etag"
        private const val KEY_CHECKED_AT = "cloud_config_checked_at"
        private const val KEY_SKIPPED = "cloud_config_skipped_version"
        private const val KEY_DISMISSED = "cloud_config_dismissed_notices"
    }
}
