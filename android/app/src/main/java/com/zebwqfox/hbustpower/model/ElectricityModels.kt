package com.zebwqfox.hbustpower.model

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

enum class MeterKind(val label: String) {
    LIGHTING("照明"),
    AIR_CONDITIONING("空调"),
    UNKNOWN("其他");

    companion object {
        fun fromMeterName(name: String): MeterKind = when {
            name.contains("空调") -> AIR_CONDITIONING
            name.contains("照明") -> LIGHTING
            else -> UNKNOWN
        }
    }
}

data class MeterStatus(
    val name: String,
    val powerStatus: String,
    val communicationStatus: String,
)

data class UsageRecord(
    val occurredAt: Instant,
    val kWh: Double,
    val meterName: String,
) {
    val kind: MeterKind get() = MeterKind.fromMeterName(meterName)
}

data class RechargeRecord(
    val occurredAt: Instant,
    val amountText: String,
    val kWhText: String,
    val type: String,
    val meterName: String,
    val studentNumber: String?,
)

data class ElectricitySnapshot(
    val room: String?,
    val purchasedKWh: Double,
    val subsidyKWh: Double?,
    val unitPrice: Double?,
    val meters: List<MeterStatus>,
    val usageRecords: List<UsageRecord>,
    val rechargeRecords: List<RechargeRecord>,
    val fetchedAt: Instant,
) {
    fun recentDailyTotals(
        kind: MeterKind,
        days: Int = 7,
        zoneId: ZoneId = ZoneId.of("Asia/Shanghai"),
    ): List<Pair<LocalDate, Double>> = usageRecords
        .asSequence()
        .filter { it.kind == kind }
        .groupBy { it.occurredAt.atZone(zoneId).toLocalDate() }
        .mapValues { (_, records) -> records.sumOf(UsageRecord::kWh) }
        .toList()
        .sortedBy(Pair<LocalDate, Double>::first)
        .takeLast(days)

    fun recentAverage(kind: MeterKind, days: Int = 7): Double? =
        recentDailyTotals(kind, days).map(Pair<LocalDate, Double>::second)
            .takeIf(List<Double>::isNotEmpty)?.average()

    val predictedDays: Double?
        get() {
            val lighting = recentAverage(MeterKind.LIGHTING) ?: return null
            val airConditioning = recentAverage(MeterKind.AIR_CONDITIONING) ?: return null
            val daily = lighting + airConditioning
            return if (daily > 0.0) purchasedKWh / daily else null
        }

    /** One point per recorded day, oldest first. Unknown meters are kept apart rather than folded into lighting. */
    fun dailyPoints(zoneId: ZoneId = ZoneId.of("Asia/Shanghai")): List<DailyUsagePoint> = usageRecords
        .groupBy { it.occurredAt.atZone(zoneId).toLocalDate() }
        .toSortedMap()
        .map { (day, records) ->
            DailyUsagePoint(
                day = day,
                lighting = records.filter { it.kind == MeterKind.LIGHTING }.sumOf(UsageRecord::kWh),
                airConditioning = records.filter { it.kind == MeterKind.AIR_CONDITIONING }.sumOf(UsageRecord::kWh),
                other = records.filter { it.kind == MeterKind.UNKNOWN }.sumOf(UsageRecord::kWh),
            )
        }
}

data class DailyUsagePoint(
    val day: LocalDate,
    val lighting: Double,
    val airConditioning: Double,
    val other: Double = 0.0,
) {
    val total: Double get() = lighting + airConditioning + other
}
