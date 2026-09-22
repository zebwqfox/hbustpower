package com.zebwqfox.hbustpower.model

import com.zebwqfox.hbustpower.HandoffFixtures
import com.zebwqfox.hbustpower.stringOrNull
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * Drives `fixtures/insights-cases.json` exactly as `tools/ios-parser-harness` does and compares against
 * the results the iOS 1.7.1 `UsageInsights` produced. `peak` captions carry a locale-formatted date,
 * so the harness omits them and neither does this test.
 */
class UsageInsightsTest {
    private val beijing = ZoneId.of("Asia/Shanghai")

    @Test fun matchesTheInsightsTheIosCodeProduced() {
        val cases = HandoffFixtures.jsonArray("insights-cases.json")
        val expectedCases = HandoffFixtures.expected.getAsJsonArray("insights")
        assertEquals(cases.size(), expectedCases.size())

        cases.forEachIndexed { index, element ->
            val testCase = element.asJsonObject
            val name = testCase.get("name").asString
            val expected = expectedCases[index].asJsonObject
            assertEquals("用例顺序应与 insights-cases.json 一致", name, expected.get("name").asString)

            val actual = UsageInsights.make(
                snapshot = snapshotFor(testCase),
                now = Instant.ofEpochSecond(testCase.get("nowEpoch").asLong),
                zoneId = beijing,
            )
            val expectedInsights = expected.getAsJsonArray("insights")
            assertEquals("$name 的卡片数量", expectedInsights.size(), actual.size)

            expectedInsights.forEachIndexed { position, expectedElement ->
                val insight = expectedElement.asJsonObject
                val id = insight.get("id").asString
                assertEquals("$name 第 ${position + 1} 张卡的 id", id, actual[position].id)
                assertEquals("$name/$id 的值", insight.get("value").asString, actual[position].value)
                assertEquals("$name/$id 的贴纸", insight.stringOrNull("sticker"), actual[position].sticker)
                assertEquals(
                    "$name/$id 的色调",
                    insight.get("tone").asString,
                    actual[position].tone.name.lowercase(),
                )
                insight.stringOrNull("caption")?.let {
                    assertEquals("$name/$id 的说明", it, actual[position].caption)
                }
            }
        }
    }

    /** Same construction as the Swift harness: day i is 2026-09-01 12:00 Beijing plus i days. */
    private fun snapshotFor(testCase: com.google.gson.JsonObject): ElectricitySnapshot {
        val start = ZonedDateTime.of(2026, 9, 1, 12, 0, 0, 0, beijing)
        val records = testCase.getAsJsonArray("daily").flatMapIndexed { day, element ->
            val amounts = element.asJsonArray
            val at = start.plusDays(day.toLong()).toInstant()
            listOf(
                UsageRecord(at, amounts[0].asDouble, "示例楼101照明"),
                UsageRecord(at, amounts[1].asDouble, "示例楼101空调"),
            )
        }
        val recharges = testCase.get("rechargeEpoch").takeUnless { it.isJsonNull }?.let {
            listOf(
                RechargeRecord(
                    occurredAt = Instant.ofEpochSecond(it.asLong),
                    amountText = "50元",
                    kWhText = "87度",
                    type = "一卡通充值",
                    meterName = "示例楼101",
                    studentNumber = null,
                ),
            )
        }.orEmpty()

        return ElectricitySnapshot(
            room = "示例楼101",
            purchasedKWh = testCase.get("balance").asDouble,
            subsidyKWh = 0.0,
            unitPrice = testCase.get("unitPrice").takeUnless { it.isJsonNull }?.asDouble,
            meters = emptyList(),
            usageRecords = records,
            rechargeRecords = recharges,
            fetchedAt = Instant.EPOCH,
        )
    }
}
