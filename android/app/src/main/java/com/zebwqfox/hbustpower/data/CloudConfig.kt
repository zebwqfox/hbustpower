package com.zebwqfox.hbustpower.data

import org.json.JSONObject
import java.net.URI

/**
 * The small JSON file the app fetches from the developer's own site: what the newest version is, a notice worth
 * showing, and switches for the parts that break when the school changes its pages.
 *
 * It carries text, numbers and booleans only — never code, never a script, never anything the app runs. The one
 * thing that can send the user somewhere is the download link, and that is dropped unless it is HTTPS on one of
 * the hosts the build was compiled with, so a tampered file cannot point people at an arbitrary page.
 */
data class CloudConfig(
    val update: Update? = null,
    val notice: Notice? = null,
    val flags: Map<String, Boolean> = emptyMap(),
    /** Builds older than this are known to be broken; the app says so instead of blocking anyone. */
    val minSupportedVersionCode: Int = 0,
    /** When the file was published, as written by whoever published it. Diagnostics only. */
    val publishedAt: String? = null,
) {
    data class Update(
        val versionCode: Int,
        val versionName: String,
        val notes: List<String> = emptyList(),
        /** Null when the published link failed the host check. */
        val downloadUrl: String? = null,
        /** Optional, so the user can verify the file they downloaded. */
        val sha256: String? = null,
        val sizeBytes: Long? = null,
    )

    data class Notice(
        val id: String,
        val title: String,
        val body: String,
        val level: Level = Level.INFO,
        /** Epoch seconds. The notice goes away by itself after this, even if the file stops being updated. */
        val expiresAt: Long? = null,
        val dismissible: Boolean = true,
    ) {
        enum class Level { INFO, WARNING }
    }

    fun updateAvailable(currentVersionCode: Int): Update? = update?.takeIf { it.versionCode > currentVersionCode }

    fun mustUpgrade(currentVersionCode: Int): Boolean =
        minSupportedVersionCode > 0 && currentVersionCode < minSupportedVersionCode

    /** The notice to show right now: not expired, and not one the user already swiped away. */
    fun activeNotice(nowSeconds: Long, dismissedIds: Set<String>): Notice? = notice
        ?.takeIf { it.expiresAt == null || it.expiresAt > nowSeconds }
        ?.takeIf { !it.dismissible || it.id !in dismissedIds }

    /** Feature switches fail open: an unreachable or silent config leaves every feature on. */
    fun isEnabled(flag: String): Boolean = flags[flag] ?: true

    companion object {
        const val FLAG_CAMPUS_CARD = "campusCard"
        const val FLAG_RECHARGE = "recharge"
        const val FLAG_UPDATE_CHECK = "updateCheck"

        val EMPTY = CloudConfig()

        /**
         * Parses the published file. Every field is optional, so an older app reading a newer file keeps working,
         * and anything malformed yields [EMPTY] rather than throwing.
         *
         * @param trustedDownloadHosts hosts the app may send the user to; anything else drops the download link.
         */
        fun parse(json: String, trustedDownloadHosts: List<String> = emptyList()): CloudConfig = runCatching {
            val root = JSONObject(json)
            CloudConfig(
                update = root.optJSONObject("update")?.let { node -> parseUpdate(node, trustedDownloadHosts) },
                notice = root.optJSONObject("notice")?.let(::parseNotice),
                flags = root.optJSONObject("flags")?.let { node ->
                    node.keys().asSequence().associateWith { node.optBoolean(it, true) }
                } ?: emptyMap(),
                minSupportedVersionCode = root.optInt("minSupportedVersionCode", 0),
                publishedAt = root.optString("publishedAt").takeIf(String::isNotBlank),
            )
        }.getOrDefault(EMPTY)

        private fun parseUpdate(node: JSONObject, trustedHosts: List<String>): Update? {
            val code = node.optInt("versionCode", 0)
            val name = node.optString("versionName").takeIf(String::isNotBlank) ?: return null
            if (code <= 0) return null
            return Update(
                versionCode = code,
                versionName = name,
                notes = node.optJSONArray("notes")?.let { array ->
                    (0 until array.length()).mapNotNull { array.optString(it).takeIf(String::isNotBlank) }
                } ?: emptyList(),
                downloadUrl = node.optString("downloadUrl").takeIf { isTrustedDownload(it, trustedHosts) },
                sha256 = node.optString("sha256").lowercase().takeIf { it.matches(SHA256) },
                sizeBytes = node.optLong("sizeBytes", 0L).takeIf { it > 0 },
            )
        }

        private fun parseNotice(node: JSONObject): Notice? {
            val id = node.optString("id").takeIf(String::isNotBlank) ?: return null
            val body = node.optString("body").takeIf(String::isNotBlank) ?: return null
            return Notice(
                id = id,
                title = node.optString("title").takeIf(String::isNotBlank) ?: "公告",
                body = body,
                level = if (node.optString("level").equals("warning", ignoreCase = true)) {
                    Notice.Level.WARNING
                } else {
                    Notice.Level.INFO
                },
                expiresAt = node.optLong("expiresAt", 0L).takeIf { it > 0 },
                dismissible = node.optBoolean("dismissible", true),
            )
        }

        /** HTTPS on a host the build allows — never a redirect to somewhere the config file made up. */
        fun isTrustedDownload(url: String, trustedHosts: List<String>): Boolean {
            if (url.isBlank() || trustedHosts.isEmpty()) return false
            val parsed = runCatching { URI(url) }.getOrNull() ?: return false
            val host = parsed.host?.lowercase() ?: return false
            if (!parsed.scheme.equals("https", ignoreCase = true) || parsed.userInfo != null) return false
            return trustedHosts.any { trusted ->
                val expected = trusted.lowercase().trim()
                expected.isNotEmpty() && (host == expected || host.endsWith(".$expected"))
            }
        }

        private val SHA256 = Regex("^[0-9a-f]{64}$")
    }
}
