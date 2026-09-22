package com.zebwqfox.hbustpower.model

import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.ceil
import kotlin.math.max

/**
 * Local "how much should we top up?" arithmetic (iOS 1.8.0 `RechargePlanner`). Nothing here talks to the
 * school; it only uses the latest snapshot.
 */
class RechargePlanner(
    val balanceKWh: Double,
    val unitPrice: Double,
    /** Lighting + air conditioning, per recorded day. */
    val dailyKWh: Double,
) {
    data class AmountPlan(val addedKWh: Double, val totalDays: Double, val lastsUntil: Instant)

    /** What topping up [amount] yuan buys, and how long balance + purchase lasts at the recent pace. */
    fun plan(amount: Double, now: Instant = Instant.now()): AmountPlan {
        val added = max(0.0, amount) / unitPrice
        val days = (balanceKWh + added) / dailyKWh
        return AmountPlan(added, days, now.plusSeconds((days * 86_400).toLong()))
    }

    data class DatePlan(
        val days: Int,
        val neededKWh: Double,
        /** Whole yuan, rounded up so the power really lasts. */
        val amount: Int,
    )

    /** The top-up needed for power to last through the end of [target] (a calendar day). */
    fun plan(target: LocalDate, now: Instant = Instant.now(), zoneId: ZoneId = BEIJING): DatePlan {
        val today = now.atZone(zoneId).toLocalDate()
        val days = max(0L, java.time.temporal.ChronoUnit.DAYS.between(today, target) + 1).toInt()
        // Today is partly used already; count the remaining fraction of today rather than a whole day.
        val startOfDay = today.atStartOfDay(zoneId).toInstant()
        val elapsedToday = Duration.between(startOfDay, now).seconds / 86_400.0
        val neededDays = max(0.0, days - elapsedToday)
        val needed = max(0.0, neededDays * dailyKWh - balanceKWh)
        return DatePlan(days, needed, ceil(needed * unitPrice).toInt())
    }

    companion object {
        val BEIJING: ZoneId = ZoneId.of("Asia/Shanghai")

        /** Needs both a price and usage for both kinds; otherwise nothing can be calculated. */
        fun from(snapshot: ElectricitySnapshot): RechargePlanner? {
            val price = snapshot.unitPrice?.takeIf { it > 0 } ?: return null
            val lighting = snapshot.recentAverage(MeterKind.LIGHTING) ?: return null
            val airConditioning = snapshot.recentAverage(MeterKind.AIR_CONDITIONING) ?: return null
            val daily = lighting + airConditioning
            if (daily <= 0) return null
            return RechargePlanner(max(0.0, snapshot.purchasedKWh), price, daily)
        }

        /** Each roommate's share, in yuan with two decimals, rounded up so the total is never short. */
        fun share(amount: Double, people: Int): Double =
            if (people <= 0) amount else ceil(amount / people * 100) / 100

        /** The amounts offered as quick choices. */
        val presetAmounts = listOf(20.0, 50.0, 100.0, 200.0)
    }
}

/** Totals shown at the top of the recharge records (iOS 1.8.0 `RechargeSummary`). */
data class RechargeSummary(
    val count: Int,
    val totalYuan: Double?,
    val totalKWh: Double?,
    val latest: Instant?,
) {
    val averageYuan: Double? get() = totalYuan?.takeIf { count > 0 }?.div(count)

    companion object {
        fun of(records: List<RechargeRecord>): RechargeSummary {
            val yuan = records.mapNotNull { number(it.amountText, "元") }
            val kWh = records.mapNotNull { number(it.kWhText, "度") }
            return RechargeSummary(
                count = records.size,
                totalYuan = yuan.takeIf { it.isNotEmpty() }?.sum(),
                totalKWh = kWh.takeIf { it.isNotEmpty() }?.sum(),
                latest = records.maxOfOrNull(RechargeRecord::occurredAt),
            )
        }

        /** "100.00元" → 100. Null for "-" or text in another unit, so missing fields are not counted as zero. */
        fun number(text: String, unit: String): Double? {
            val trimmed = text.trim()
            if (!trimmed.endsWith(unit)) return null
            return trimmed.dropLast(unit.length).trim().toDoubleOrNull()
        }
    }
}
