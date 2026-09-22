import XCTest
@testable import HBUSTPowerIOS

final class WidgetSnapshotTests: XCTestCase {
    private func snapshot(balance: Double, days: Double?) -> PowerWidgetSnapshot {
        PowerWidgetSnapshot(room: "东10-625", balanceKWh: balance, predictedDays: days, dailyLighting: 4,
                            dailyAirConditioning: 9, days: [], isLow: false, updatedAt: Date(timeIntervalSince1970: 0))
    }

    func testGaugeUsesTheForecastAndFillsAtAMonth() {
        XCTAssertEqual(snapshot(balance: 100, days: 15).gaugeLevel, 0.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot(balance: 100, days: 40).gaugeLevel, 1)
        XCTAssertEqual(snapshot(balance: 0, days: 0).gaugeLevel, 0)
    }

    func testGaugeFallsBackToTheBalanceWithoutAForecast() {
        XCTAssertEqual(snapshot(balance: 150, days: nil).gaugeLevel, 0.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot(balance: 900, days: nil).gaugeLevel, 1)
    }

    func testDailyTotalNeedsBothMeters() {
        XCTAssertEqual(snapshot(balance: 10, days: 1).dailyTotal, 13)
        var partial = snapshot(balance: 10, days: 1)
        partial.dailyAirConditioning = nil
        XCTAssertNil(partial.dailyTotal)
    }

    func testSnapshotSurvivesEncoding() throws {
        let original = PowerWidgetStore.placeholder
        let restored = try JSONDecoder().decode(PowerWidgetSnapshot.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(restored, original)
        XCTAssertEqual(restored.days.count, 7)
        XCTAssertEqual(restored.days.first!.total, restored.days.first!.lighting + restored.days.first!.airConditioning)
    }
}
