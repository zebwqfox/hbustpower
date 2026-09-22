import XCTest
@testable import HBUSTPowerIOS

final class ChangelogTests: XCTestCase {
    func testLatestEntryMatchesShippedVersion() {
        XCTAssertEqual(Changelog.latest.version, Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                       "Add a Changelog entry when bumping MARKETING_VERSION")
    }

    func testVersionsAreUniqueNewestFirstAndFilledIn() {
        let versions = Changelog.releases.map(\.version)
        XCTAssertEqual(Set(versions).count, versions.count)
        let sorted = versions.sorted { $0.compare($1, options: .numeric) == .orderedDescending }
        XCTAssertEqual(versions, sorted)
        for release in Changelog.releases {
            XCTAssertFalse(release.sections.isEmpty, release.version)
            XCTAssertFalse(release.sections.contains { $0.items.isEmpty }, release.version)
        }
    }
}

final class UsageInsightsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()

    private func snapshot(daily: [(lighting: Double, ac: Double)], recharge: Date? = nil, price: Double? = 0.57, balance: Double = 100) -> ElectricitySnapshot {
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 12))!
        let records = daily.enumerated().flatMap { index, day -> [UsageRecord] in
            let date = calendar.date(byAdding: .day, value: index, to: start)!
            return [UsageRecord(date: date, kWh: day.lighting, meterName: "东10-625照明"), UsageRecord(date: date, kWh: day.ac, meterName: "东10-625空调")]
        }
        let recharges = recharge.map { [RechargeRecord(date: $0, amountText: "50元", kWhText: "87度", type: "一卡通充值", meterName: "东10-625", studentNumber: nil)] } ?? []
        return ElectricitySnapshot(room: "东10-625", purchasedKWh: balance, subsidyKWh: 0, unitPrice: price, meters: [],
                                   usageRecords: records, rechargeRecords: recharges, fetchedAt: .now)
    }

    func testUsageSelectorShowsOneRequestedSeries() {
        let point = DailyUsagePoint(date: .now, lighting: 2.5, airConditioning: 7.5)
        XCTAssertEqual(UsageSeries.total.value(for: point), 10)
        XCTAssertEqual(UsageSeries.lighting.value(for: point), 2.5)
        XCTAssertEqual(UsageSeries.airConditioning.value(for: point), 7.5)
    }

    func testWeekComparisonReportsSaving() {
        let days = Array(repeating: (lighting: 5.0, ac: 15.0), count: 7) + Array(repeating: (lighting: 4.0, ac: 12.0), count: 7)
        let week = UsageInsights.make(from: snapshot(daily: days), calendar: calendar).first { $0.id == "week" }
        XCTAssertEqual(week?.value, "省了 20%")
        XCTAssertEqual(week?.sticker, "省电小能手")
        XCTAssertEqual(week?.tone, .good)
    }

    func testNotEnoughHistoryHidesComparisons() {
        let insights = UsageInsights.make(from: snapshot(daily: [(5, 15), (5, 15)], price: nil), calendar: calendar)
        XCTAssertNil(insights.first { $0.id == "week" })
        XCTAssertNil(insights.first { $0.id == "streak" })
        XCTAssertNil(insights.first { $0.id == "value" })
    }

    func testStreakPeakShareValueAndRecharge() {
        let days: [(lighting: Double, ac: Double)] = [(5, 25), (5, 25), (5, 30), (4, 10), (4, 10), (4, 12)]
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 17, hour: 9))!
        let recharge = calendar.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: 20))!
        let insights = UsageInsights.make(from: snapshot(daily: days, recharge: recharge, balance: 100), now: now, calendar: calendar)
        func value(_ id: String) -> String? { insights.first { $0.id == id }?.value }
        XCTAssertEqual(value("streak"), "连续 3 天")
        XCTAssertEqual(value("peak"), "35.0 度")
        XCTAssertEqual(value("ac"), "空调占 81%")
        XCTAssertEqual(insights.first { $0.id == "ac" }?.sticker, "空调重度用户")
        XCTAssertEqual(value("value"), "约 ¥57.00")
        XCTAssertEqual(value("recharge"), "12 天前")
    }
}
