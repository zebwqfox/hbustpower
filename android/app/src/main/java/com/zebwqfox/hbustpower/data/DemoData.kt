package com.zebwqfox.hbustpower.data

import com.zebwqfox.hbustpower.model.ElectricitySnapshot
import com.zebwqfox.hbustpower.model.MeterStatus
import com.zebwqfox.hbustpower.model.RechargeRecord
import com.zebwqfox.hbustpower.model.UsageRecord
import java.time.Instant
import java.time.ZoneId

/**
 * Offline demo, matching the iOS `--ui-preview` snapshot (14 days, 194.67 kWh). Clearly labelled in the UI;
 * it never pretends a real login succeeded.
 */
object DemoData {
    private val zone = ZoneId.of("Asia/Shanghai")

    fun snapshot(now: Instant = Instant.now(), lowBalance: Boolean = false): ElectricitySnapshot {
        val today = now.atZone(zone).toLocalDate()
        val records = (0 until 14).flatMap { offset ->
            val at = today.minusDays(offset.toLong()).atTime(11, 0).atZone(zone).toInstant()
            listOf(
                UsageRecord(at, 4.8 + (offset % 3) * 0.62, "东10-625照明"),
                UsageRecord(at, 20.2 + (offset % 4) * 1.08, "东10-625空调"),
            )
        }
        return ElectricitySnapshot(
            room = "东10-625",
            purchasedKWh = if (lowBalance) 12.50 else 194.67,
            subsidyKWh = 0.0,
            unitPrice = 0.57,
            meters = listOf(
                MeterStatus("东10-625照明", "正常用电", "通讯正常"),
                MeterStatus("东10-625空调", "正常用电", "通讯正常"),
            ),
            usageRecords = records,
            rechargeRecords = listOf(
                RechargeRecord(now, "100.00元", "175.44度", "一卡通充值", "东10-625", "2026123456"),
                RechargeRecord(now.minusSeconds(9 * 86_400L), "50.00元", "87.72度", "一卡通充值", "东10-625", "2026123456"),
                RechargeRecord(now.minusSeconds(31 * 86_400L), "-", "30.00度", "补助", "东10-625", null),
            ),
            fetchedAt = now,
        )
    }

    const val CAMPUS_CARD_BALANCE = 42.50
}
