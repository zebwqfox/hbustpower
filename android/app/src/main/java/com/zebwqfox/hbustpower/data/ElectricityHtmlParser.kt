package com.zebwqfox.hbustpower.data

import com.zebwqfox.hbustpower.model.ElectricitySnapshot
import com.zebwqfox.hbustpower.model.MeterStatus
import com.zebwqfox.hbustpower.model.RechargeRecord
import com.zebwqfox.hbustpower.model.UsageRecord
import org.jsoup.parser.Parser
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.ResolverStyle
import java.util.Locale

/**
 * Pure parsing of the school electricity pages, kept separate from networking so it can be unit tested.
 * Mirrors `Services/ElectricityHTMLParser.swift` in the iOS 1.7.1 reference; `fixtures/expected-1.7.1.json`
 * was generated from that Swift code and both sides must agree item by item.
 */
class ElectricityHtmlParser(
    private val zoneId: ZoneId = ZoneId.of("Asia/Shanghai"),
) {
    fun parse(homeHtml: String, usageHtml: String, recordsHtml: String, fetchedAt: Instant): ElectricitySnapshot {
        val purchased = purchasedKWh(homeHtml) ?: throw ElectricityParseException("没有找到剩余购电")
        return ElectricitySnapshot(
            room = room(homeHtml),
            purchasedKWh = purchased,
            subsidyKWh = subsidyKWh(homeHtml),
            unitPrice = unitPrice(homeHtml),
            meters = meters(homeHtml),
            usageRecords = usageRecords(usageHtml),
            rechargeRecords = rechargeRecords(recordsHtml),
            fetchedAt = fetchedAt,
        )
    }

    fun purchasedKWh(html: String): Double? = value("剩余购电", html)

    fun subsidyKWh(html: String): Double? = value("剩余补助", html)

    /** A sign-in page, as opposed to a normal page that merely mentions the authentication service in its footer. */
    fun isLoginPage(finalUrl: String, html: String): Boolean {
        val url = finalUrl.lowercase(Locale.ROOT)
        if (url.contains("login") || url.contains("/error") || html.contains("session过期", ignoreCase = true)) return true
        return html.contains("统一身份认证") && passwordField.containsMatchIn(html)
    }

    /** The home page lost its balance and shows the authentication service instead, e.g. a script-rendered login page. */
    fun isLoginPlaceholder(homeHtml: String): Boolean =
        purchasedKWh(homeHtml) == null && homeHtml.contains("统一身份认证")

    /**
     * The live page titles the first meter ("东10-625照明"), so the room is the part before the meter type
     * (iOS 1.8.2). A title that is only "照明" or "空调" is kept as is.
     */
    fun room(html: String): String? {
        val title = roomPattern.find(html)?.groupValues?.get(1)?.let(::stripTags)?.trim() ?: return null
        val room = meterSuffixes.fold(title) { value, suffix ->
            if (value.endsWith(suffix) && value.length > suffix.length) value.dropLast(suffix.length).trim() else value
        }
        return room.ifEmpty { null }
    }

    fun unitPrice(html: String): Double? {
        val plain = stripTags(html)
        val start = plain.indexOf("电费单价")
        if (start < 0) return null
        val tail = plain.substring(start + "电费单价".length).take(80)
        return unsignedNumber.find(tail)?.value?.toDoubleOrNull()
    }

    fun meters(html: String): List<MeterStatus> {
        val lines = visibleLines(html)
        val start = lines.indexOf("当前表具")
        if (start < 0) return emptyList()
        val result = mutableListOf<MeterStatus>()
        var index = start + 1
        while (index + 2 < lines.size) {
            val name = lines[index]
            if (name == "元" || name.contains("充值说明") || name == "一卡通充值") break
            if (name.contains("照明") || name.contains("空调")) {
                result += MeterStatus(name, lines[index + 1], lines[index + 2])
                index += 3
            } else index++
        }
        return result
    }

    fun usageRecords(html: String): List<UsageRecord> =
        recordWindows(visibleLines(html), maxLength = 6).mapNotNull { (date, window) ->
            val amount = window.firstOrNull(kWhAmount::matches) ?: return@mapNotNull null
            val meter = window.firstOrNull { it.startsWith("电表:") } ?: return@mapNotNull null
            val kWh = amount.removeSuffix("度").toDoubleOrNull() ?: return@mapNotNull null
            UsageRecord(date, kWh, meter.removePrefix("电表:").trim())
        }

    fun rechargeRecords(html: String): List<RechargeRecord> =
        recordWindows(visibleLines(html), maxLength = 9).map { (date, window) ->
            RechargeRecord(
                occurredAt = date,
                amountText = window.firstOrNull {
                    it.endsWith("元") || (it.endsWith("度") && !it.startsWith("电量:"))
                } ?: "-",
                kWhText = field("电量:", window),
                type = field("类型:", window),
                meterName = field("电表:", window),
                studentNumber = optionalField(listOf("学工号:", "学号:"), window),
            )
        }

    /**
     * School timestamps are Beijing time in the Gregorian calendar, whatever the device's region,
     * calendar or time zone. Returns null for impossible dates such as month 13.
     */
    fun timestamp(text: String): Instant? = runCatching {
        LocalDateTime.parse(text, dateTimeFormatter).atZone(zoneId).toInstant()
    }.getOrNull()

    /**
     * Lines after each timestamp, stopping at the next timestamp so a record with missing fields
     * never borrows them from the next one.
     */
    private fun recordWindows(lines: List<String>, maxLength: Int): List<Pair<Instant, List<String>>> {
        val starts = lines.indices.mapNotNull { index -> timestamp(lines[index])?.let { index to it } }
        return starts.mapIndexed { position, (index, date) ->
            val nextStart = if (position + 1 < starts.size) starts[position + 1].first else lines.size
            date to lines.subList(index + 1, minOf(nextStart, index + 1 + maxLength))
        }
    }

    private fun value(label: String, html: String): Double? {
        val start = html.indexOf(label)
        if (start < 0) return null
        val plain = stripTags(html.substring(start + label.length).take(700))
        return signedNumber.find(plain)?.value?.toDoubleOrNull()
    }

    private fun field(prefix: String, lines: List<String>): String =
        lines.firstOrNull { it.startsWith(prefix) }?.removePrefix(prefix)?.trim() ?: "-"

    private fun optionalField(prefixes: List<String>, lines: List<String>): String? = prefixes
        .asSequence()
        .mapNotNull { prefix -> lines.firstOrNull { it.startsWith(prefix) }?.removePrefix(prefix)?.trim() }
        .firstOrNull(String::isNotEmpty)

    private fun visibleLines(html: String): List<String> = stripTags(
        html.replace(scriptBlock, " ").replace(styleBlock, " "),
    ).lineSequence().map(String::trim).filter(String::isNotEmpty).toList()

    private fun stripTags(html: String): String = Parser.unescapeEntities(
        // `&nbsp;` becomes a plain space rather than U+00A0 so trimming behaves like the iOS parser.
        htmlTag.replace(html, "\n").replace("&nbsp;", " "),
        true,
    )

    private companion object {
        val htmlTag = Regex("<[^>]+>")
        val scriptBlock = Regex("<script\\b[^>]*>.*?</script>", setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL))
        val styleBlock = Regex("<style\\b[^>]*>.*?</style>", setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL))
        val roomPattern = Regex(
            "<li[^>]*class=[\"'][^\"']*list-group-title[^\"']*[\"'][^>]*>(.*?)</li>",
            setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL),
        )
        val passwordField = Regex("type\\s*=\\s*[\"']?password", RegexOption.IGNORE_CASE)
        val meterSuffixes = listOf("照明", "空调")
        val kWhAmount = Regex("^\\d+(?:\\.\\d+)?度$")
        val signedNumber = Regex("-?\\d+(?:\\.\\d+)?")
        val unsignedNumber = Regex("\\d+(?:\\.\\d+)?")

        val dateTimeFormatter: DateTimeFormatter = DateTimeFormatter
            .ofPattern("uuuu-MM-dd HH:mm:ss", Locale.ROOT)
            .withResolverStyle(ResolverStyle.STRICT)
    }
}

class ElectricityParseException(message: String) : IllegalArgumentException(message)
