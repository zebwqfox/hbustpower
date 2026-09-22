package com.zebwqfox.hbustpower.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

/** Mirrors `HBUSTPowerIOSTests/RechargePlannerTests.swift` case by case. */
class RechargePlannerTest {
    private val zone: ZoneId = ZoneId.of("Asia/Shanghai")
    private val planner = RechargePlanner(balanceKWh = 50.0, unitPrice = 0.5, dailyKWh = 25.0)
    private fun at(year: Int, month: Int, day: Int, hour: Int) =
        LocalDateTime.of(year, month, day, hour, 0).atZone(zone).toInstant()

    @Test fun amountPlanBuysKilowattHoursAndDays() {
        val now = at(2026, 9, 19, 12)
        val plan = planner.plan(amount = 100.0, now = now)
        assertEquals(200.0, plan.addedKWh, 1e-9)
        assertEquals(10.0, plan.totalDays, 1e-9)
        assertEquals(now.plusSeconds(10 * 86_400L), plan.lastsUntil)
    }

    @Test fun datePlanCountsTheRestOfTodayAndRoundsUp() {
        val noon = at(2026, 9, 19, 12)
        // 19th (half left) through 24th = 5.5 days × 25 = 137.5 kWh, minus 50 in stock = 87.5 kWh × 0.5 = 43.75 → 44 yuan.
        val plan = planner.plan(LocalDate.of(2026, 9, 24), now = noon, zoneId = zone)
        assertEquals(6, plan.days)
        assertEquals(87.5, plan.neededKWh, 1e-4)
        assertEquals(44, plan.amount)
    }

    @Test fun datePlanNeedsNothingWhenBalanceIsEnough() {
        val noon = at(2026, 9, 19, 12)
        val plan = planner.plan(LocalDate.of(2026, 9, 19), now = noon, zoneId = zone)
        assertEquals(0.0, plan.neededKWh, 1e-9)
        assertEquals(0, plan.amount)
    }

    @Test fun shareRoundsUpToTheCent() {
        assertEquals(33.34, RechargePlanner.share(100.0, 3), 1e-9)
        assertEquals(25.0, RechargePlanner.share(100.0, 4), 1e-9)
        assertEquals(50.0, RechargePlanner.share(50.0, 0), 1e-9)
    }

    @Test fun plannerNeedsPriceAndBothKindsOfUsage() {
        val now = Instant.parse("2026-09-19T04:00:00Z")
        val usage = listOf(
            UsageRecord(now, 3.0, "东10-625照明"),
            UsageRecord(now, 9.0, "东10-625空调"),
        )
        val unpriced = ElectricitySnapshot(null, 80.0, null, null, emptyList(), usage, emptyList(), now)
        assertNull(RechargePlanner.from(unpriced))
        val priced = unpriced.copy(unitPrice = 0.57)
        assertEquals(12.0, RechargePlanner.from(priced)!!.dailyKWh, 1e-9)
        // Lighting only: without both kinds the estimate would be wrong, so nothing is offered.
        assertNull(RechargePlanner.from(priced.copy(usageRecords = usage.take(1))))
    }

    @Test fun summarySkipsMissingFields() {
        val records = listOf(
            RechargeRecord(Instant.ofEpochSecond(100), "100.00元", "175.44度", "一卡通充值", "-", null),
            RechargeRecord(Instant.ofEpochSecond(300), "50.00元", "-", "一卡通充值", "-", null),
            RechargeRecord(Instant.ofEpochSecond(200), "-", "30度", "补助", "-", null),
        )
        val summary = RechargeSummary.of(records)
        assertEquals(3, summary.count)
        assertEquals(150.0, summary.totalYuan!!, 1e-9)
        assertEquals(205.44, summary.totalKWh!!, 1e-4)
        assertEquals(Instant.ofEpochSecond(300), summary.latest)
        assertEquals(50.0, summary.averageYuan!!, 1e-9)
        assertNull(RechargeSummary.of(emptyList()).totalYuan)
    }
}
