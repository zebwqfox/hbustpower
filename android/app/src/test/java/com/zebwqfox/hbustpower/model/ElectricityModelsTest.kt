package com.zebwqfox.hbustpower.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

class ElectricityModelsTest {
    private val zone = ZoneId.of("Asia/Shanghai")
    private fun record(day: Int, kWh: Double, meter: String) = UsageRecord(
        LocalDate.of(2026, 9, day).atStartOfDay(zone).toInstant(), kWh, meter
    )

    @Test fun averagesRecordedDaysAndAggregatesSameDay() {
        val snapshot = snapshot(
            listOf(
                record(1, 1.0, "照明电表"),
                record(1, 2.0, "照明电表"),
                record(3, 5.0, "照明电表"),
                record(1, 10.0, "空调电表"),
                record(3, 10.0, "空调电表"),
            )
        )
        assertEquals(4.0, snapshot.recentAverage(MeterKind.LIGHTING)!!, 0.0001)
        assertEquals(10.0, snapshot.recentAverage(MeterKind.AIR_CONDITIONING)!!, 0.0001)
        assertEquals(60.0 / 14.0, snapshot.predictedDays!!, 0.0001)
    }

    @Test fun predictionRequiresBothKnownKinds() {
        assertNull(snapshot(listOf(record(1, 2.0, "照明电表"))).predictedDays)
        assertEquals(MeterKind.UNKNOWN, record(1, 2.0, "新型表具").kind)
    }

    private fun snapshot(records: List<UsageRecord>) = ElectricitySnapshot(
        room = "101", purchasedKWh = 60.0, subsidyKWh = null, unitPrice = null,
        meters = emptyList(), usageRecords = records, rechargeRecords = emptyList(),
        fetchedAt = java.time.Instant.EPOCH,
    )
}
