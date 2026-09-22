package com.zebwqfox.hbustpower.model

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import java.util.Locale
import kotlin.math.abs
import kotlin.math.round

/** Small, friendly observations derived from the school's usage and recharge records. */
data class UsageInsight(
    val id: String,
    val value: String,
    val caption: String,
    val sticker: String?,
    val tone: Tone,
) {
    enum class Tone { GOOD, NEUTRAL, HEADS }
}

/** One recorded day and everything drawn that day, oldest first. */
data class DailyTotal(val day: LocalDate, val kWh: Double)

/**
 * Mirrors `Models/UsageInsights.swift` in the iOS 1.7.1 reference. `fixtures/insights-cases.json`
 * feeds both sides and `fixtures/expected-1.7.1.json` holds the results the Swift code produced.
 */
object UsageInsights {
    private val beijing = ZoneId.of("Asia/Shanghai")

    fun make(
        snapshot: ElectricitySnapshot,
        now: Instant,
        zoneId: ZoneId = beijing,
    ): List<UsageInsight> {
        val days = dailyTotals(snapshot.usageRecords, zoneId)
        return listOfNotNull(
            weekComparison(days),
            savingStreak(days),
            peakDay(days),
            airConditioningShare(snapshot.usageRecords, days, zoneId),
            balanceValue(snapshot),
            daysSinceRecharge(snapshot.rechargeRecords, now, zoneId),
        )
    }

    /** Oldest first; one entry per recorded day. */
    fun dailyTotals(records: List<UsageRecord>, zoneId: ZoneId = beijing): List<DailyTotal> = records
        .groupBy { it.occurredAt.atZone(zoneId).toLocalDate() }
        .map { (day, sameDay) -> DailyTotal(day, sameDay.sumOf(UsageRecord::kWh)) }
        .sortedBy(DailyTotal::day)

    fun weekComparison(days: List<DailyTotal>): UsageInsight? {
        if (days.size < 14) return null
        val recent = days.takeLast(7).sumOf(DailyTotal::kWh)
        val previous = days.dropLast(7).takeLast(7).sumOf(DailyTotal::kWh)
        if (previous <= 0.0) return null
        val change = (recent - previous) / previous
        val percent = round(abs(change) * 100).toInt()
        if (percent < 3) {
            return UsageInsight("week", "和上周差不多", "最近 7 天用电很稳定", null, UsageInsight.Tone.NEUTRAL)
        }
        return if (change < 0) {
            UsageInsight(
                id = "week",
                value = "省了 $percent%",
                caption = "最近 7 天比之前 7 天",
                sticker = "省电小能手".takeIf { percent >= 10 },
                tone = UsageInsight.Tone.GOOD,
            )
        } else {
            UsageInsight("week", "多用 $percent%", "最近 7 天比之前 7 天", null, UsageInsight.Tone.HEADS)
        }
    }

    /** Consecutive most recent days at or below the average of all recorded days. */
    fun savingStreak(days: List<DailyTotal>): UsageInsight? {
        if (days.size < 5) return null
        val average = days.sumOf(DailyTotal::kWh) / days.size
        val streak = days.asReversed().takeWhile { it.kWh <= average }.size
        if (streak < 2) return null
        return UsageInsight(
            id = "streak",
            value = "连续 $streak 天",
            caption = String.format(Locale.ROOT, "低于日均 %.1f 度", average),
            sticker = "一周达成".takeIf { streak >= 7 },
            tone = UsageInsight.Tone.GOOD,
        )
    }

    fun peakDay(days: List<DailyTotal>): UsageInsight? {
        if (days.size < 3) return null
        // Keeps the earliest of equal maxima, matching Swift's `max(by:)`.
        val peak = days.takeLast(14).maxByOrNull(DailyTotal::kWh) ?: return null
        return UsageInsight(
            id = "peak",
            value = String.format(Locale.ROOT, "%.1f 度", peak.kWh),
            caption = "${peak.day.monthValue}月${peak.day.dayOfMonth}日 用电最多",
            sticker = null,
            tone = UsageInsight.Tone.NEUTRAL,
        )
    }

    fun airConditioningShare(
        records: List<UsageRecord>,
        days: List<DailyTotal>,
        zoneId: ZoneId = beijing,
    ): UsageInsight? {
        val first = days.takeLast(7).firstOrNull()?.day ?: return null
        val recent = records.filter { !it.occurredAt.atZone(zoneId).toLocalDate().isBefore(first) }
        val total = recent.sumOf(UsageRecord::kWh)
        if (total <= 0.0) return null
        val airConditioning = recent.filter { it.kind == MeterKind.AIR_CONDITIONING }.sumOf(UsageRecord::kWh)
        val share = round(airConditioning / total * 100).toInt()
        return UsageInsight(
            id = "ac",
            value = "空调占 $share%",
            caption = "最近 7 天的电都去哪了",
            sticker = "空调重度用户".takeIf { share >= 80 },
            tone = if (share >= 80) UsageInsight.Tone.HEADS else UsageInsight.Tone.NEUTRAL,
        )
    }

    fun balanceValue(snapshot: ElectricitySnapshot): UsageInsight? {
        val price = snapshot.unitPrice ?: return null
        if (price <= 0.0 || snapshot.purchasedKWh <= 0.0) return null
        return UsageInsight(
            id = "value",
            value = String.format(Locale.ROOT, "约 ¥%.2f", snapshot.purchasedKWh * price),
            caption = "剩余电量折合电费",
            sticker = null,
            tone = UsageInsight.Tone.NEUTRAL,
        )
    }

    fun daysSinceRecharge(
        records: List<RechargeRecord>,
        now: Instant,
        zoneId: ZoneId = beijing,
    ): UsageInsight? {
        val latest = records.maxOfOrNull(RechargeRecord::occurredAt) ?: return null
        val days = ChronoUnit.DAYS.between(
            latest.atZone(zoneId).toLocalDate(),
            now.atZone(zoneId).toLocalDate(),
        )
        if (days < 0) return null
        return UsageInsight(
            id = "recharge",
            value = if (days == 0L) "今天" else "$days 天前",
            caption = "上一次充值",
            sticker = null,
            tone = UsageInsight.Tone.NEUTRAL,
        )
    }
}
