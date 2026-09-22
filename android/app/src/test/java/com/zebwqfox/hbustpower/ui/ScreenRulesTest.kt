package com.zebwqfox.hbustpower.ui

import com.zebwqfox.hbustpower.model.ElectricitySnapshot
import com.zebwqfox.hbustpower.model.RechargeRecord
import com.zebwqfox.hbustpower.model.UsageRecord
import com.zebwqfox.hbustpower.ui.components.HandDrawn
import com.zebwqfox.hbustpower.ui.screens.UsageChartScale
import com.zebwqfox.hbustpower.ui.screens.UsageWeek
import com.zebwqfox.hbustpower.ui.screens.forecastText
import com.zebwqfox.hbustpower.ui.screens.sortedRecords
import com.zebwqfox.hbustpower.ui.screens.stickerFor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

class ScreenRulesTest {
    private val zone = ZoneId.of("Asia/Shanghai")

    private fun snapshot(balance: Double, lightingPerDay: Double, airPerDay: Double, days: Int) = ElectricitySnapshot(
        room = "东10-625", purchasedKWh = balance, subsidyKWh = null, unitPrice = null, meters = emptyList(),
        usageRecords = (0 until days).flatMap { offset ->
            val at = LocalDate.of(2026, 9, 17).minusDays(offset.toLong()).atTime(10, 0).atZone(zone).toInstant()
            listOf(UsageRecord(at, lightingPerDay, "东10-625照明"), UsageRecord(at, airPerDay, "东10-625空调"))
        },
        rechargeRecords = emptyList(), fetchedAt = Instant.EPOCH,
    )

    @Test fun chartScaleMatchesIosNiceSteps() {
        assertEquals(1.5, UsageChartScale.niceMaximum(0.4), 1e-9)
        assertEquals(30.0, UsageChartScale.niceMaximum(21.59), 1e-9)
        assertEquals(7.5, UsageChartScale.niceMaximum(7.2), 1e-9)
        assertEquals("0", UsageChartScale.axisLabel(0.0))
        assertEquals("2.5", UsageChartScale.axisLabel(2.5))
        assertEquals("20", UsageChartScale.axisLabel(20.0))
    }

    @Test fun weekComparisonNeedsAsManyPreviousDays() {
        val short = UsageWeek.from(snapshot(100.0, 2.0, 8.0, 10))
        assertEquals(7, short.current.size)
        assertNull(short.changePercent)
        val full = UsageWeek.from(snapshot(100.0, 2.0, 8.0, 14))
        assertEquals(0.0, full.changePercent!!, 1e-9)
        assertEquals(70.0, full.total, 1e-9)
        assertEquals("近 7 日", full.periodName)
    }

    @Test fun stickerAndForecastFollowIosThresholds() {
        // 60 kWh / 10 kWh per day = 6 days.
        val sixDays = snapshot(60.0, 2.0, 8.0, 7)
        assertEquals("省着点用" to false, stickerFor(sixDays, isLow = false))
        assertEquals("按近期用量，约可用 6.0 天", forecastText(sixDays, isLow = false))
        assertEquals("该充电啦" to true, stickerFor(snapshot(20.0, 2.0, 8.0, 7), isLow = false))
        assertEquals("电量充足" to false, stickerFor(snapshot(194.67, 2.0, 8.0, 7), isLow = false))
        assertEquals("该充电啦" to true, stickerFor(sixDays, isLow = true))
        assertEquals("电量偏低，记得及时充值", forecastText(sixDays, isLow = true))
        assertEquals("用量记录充足后，可估算使用天数", forecastText(snapshot(60.0, 0.0, 0.0, 0), isLow = false))
    }

    @Test fun squiggleIsDeterministicPerSeed() {
        val first = HandDrawn.squiggle(120.0, 8.0, 3)
        assertEquals(first, HandDrawn.squiggle(120.0, 8.0, 3))
        assertNotEquals(first, HandDrawn.squiggle(120.0, 8.0, 11))
        assertEquals(5, first.second.size)
        first.second.forEach { assertTrue(it.end.y in 0.0..8.0 * 1.2) }
    }

    @Test fun recordsAreNewestFirstAndSnapshotFeedsInsights() {
        val older = RechargeRecord(Instant.ofEpochSecond(10), "1元", "1度", "一卡通充值", "东10", null)
        val newer = older.copy(occurredAt = Instant.ofEpochSecond(20))
        assertEquals(listOf(newer, older), sortedRecords(listOf(older, newer)))
        val current = snapshot(194.67, 2.0, 8.0, 14)
        assertEquals(14, current.dailyPoints().size)
        assertTrue(com.zebwqfox.hbustpower.model.UsageInsights.make(current, current.fetchedAt).any { it.id == "week" })
    }
}
