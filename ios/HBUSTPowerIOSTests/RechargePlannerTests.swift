import XCTest
@testable import HBUSTPowerIOS

final class RechargePlannerTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()

    private let planner = RechargePlanner(balanceKWh: 50, unitPrice: 0.5, dailyKWh: 25)

    func testAmountPlan() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 19, hour: 12))!
        let plan = planner.plan(amount: 100, now: now)
        XCTAssertEqual(plan.addedKWh, 200)
        XCTAssertEqual(plan.totalDays, 10)
        XCTAssertEqual(plan.lastsUntil, calendar.date(byAdding: .day, value: 10, to: now))
    }

    func testDatePlanCountsTheRestOfTodayAndRoundsUp() {
        let noon = calendar.date(from: DateComponents(year: 2026, month: 9, day: 19, hour: 12))!
        let target = calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 8))!
        // 19th (half left) through 24th = 5.5 days × 25 = 137.5 kWh, minus 50 in stock = 87.5 kWh × 0.5 = 43.75 → 44 yuan.
        let plan = planner.plan(until: target, now: noon, calendar: calendar)
        XCTAssertEqual(plan.days, 6)
        XCTAssertEqual(plan.neededKWh, 87.5, accuracy: 0.0001)
        XCTAssertEqual(plan.amount, 44)
    }

    func testDatePlanNeedsNothingWhenBalanceIsEnough() {
        let noon = calendar.date(from: DateComponents(year: 2026, month: 9, day: 19, hour: 12))!
        let plan = planner.plan(until: noon, now: noon, calendar: calendar)
        XCTAssertEqual(plan.neededKWh, 0)
        XCTAssertEqual(plan.amount, 0)
    }

    func testShareRoundsUpToTheCent() {
        XCTAssertEqual(RechargePlanner.share(of: 100, among: 3), 33.34)
        XCTAssertEqual(RechargePlanner.share(of: 100, among: 4), 25)
        XCTAssertEqual(RechargePlanner.share(of: 50, among: 0), 50)
    }

    func testPlannerNeedsPriceAndUsage() {
        let base = ElectricitySnapshot(room: nil, purchasedKWh: 80, subsidyKWh: nil, unitPrice: nil, meters: [],
                                       usageRecords: [UsageRecord(date: .now, kWh: 3, meterName: "照明"), UsageRecord(date: .now, kWh: 9, meterName: "空调")],
                                       rechargeRecords: [], fetchedAt: .now)
        XCTAssertNil(RechargePlanner(snapshot: base))
        let priced = ElectricitySnapshot(room: nil, purchasedKWh: 80, subsidyKWh: nil, unitPrice: 0.57, meters: [],
                                         usageRecords: base.usageRecords, rechargeRecords: [], fetchedAt: .now)
        XCTAssertEqual(RechargePlanner(snapshot: priced)?.dailyKWh, 12)
    }

    func testRechargeSummarySkipsMissingFields() {
        let records = [
            RechargeRecord(date: Date(timeIntervalSince1970: 100), amountText: "100.00元", kWhText: "175.44度", type: "一卡通充值", meterName: "-", studentNumber: nil),
            RechargeRecord(date: Date(timeIntervalSince1970: 300), amountText: "50.00元", kWhText: "-", type: "一卡通充值", meterName: "-", studentNumber: nil),
            RechargeRecord(date: Date(timeIntervalSince1970: 200), amountText: "-", kWhText: "30度", type: "补助", meterName: "-", studentNumber: nil)
        ]
        let summary = RechargeSummary(records: records)
        XCTAssertEqual(summary.count, 3)
        XCTAssertEqual(summary.totalYuan, 150)
        XCTAssertEqual(summary.totalKWh!, 205.44, accuracy: 0.0001)
        XCTAssertEqual(summary.latest, Date(timeIntervalSince1970: 300))
        XCTAssertNil(RechargeSummary(records: []).totalYuan)
    }
}
