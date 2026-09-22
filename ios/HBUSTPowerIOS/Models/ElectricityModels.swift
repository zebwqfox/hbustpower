import Foundation

struct ElectricitySnapshot: Sendable {
    let room: String?
    let purchasedKWh: Double
    let subsidyKWh: Double?
    let unitPrice: Double?
    let meters: [MeterStatus]
    let usageRecords: [UsageRecord]
    let rechargeRecords: [RechargeRecord]
    let fetchedAt: Date

    func recentAverage(kind: String, days: Int = 7) -> Double? {
        let calendar = Calendar.current
        let records = usageRecords.filter { $0.kind == kind }
        let grouped = Dictionary(grouping: records) { calendar.startOfDay(for: $0.date) }
        let values = grouped.keys.sorted().suffix(days).map { date in
            grouped[date, default: []].map(\.kWh).reduce(0, +)
        }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    var predictedDays: Double? {
        guard let lighting = recentAverage(kind: "照明"),
              let airConditioning = recentAverage(kind: "空调"),
              lighting + airConditioning > 0 else { return nil }
        return purchasedKWh / (lighting + airConditioning)
    }
}

struct MeterStatus: Hashable, Sendable {
    let name: String
    let powerStatus: String
    let communicationStatus: String
}

struct UsageRecord: Hashable, Sendable {
    let date: Date
    let kWh: Double
    let meterName: String
    var kind: String { meterName.contains("空调") ? "空调" : "照明" }
}

struct RechargeRecord: Hashable, Sendable {
    let date: Date
    let amountText: String
    let kWhText: String
    let type: String
    let meterName: String
    let studentNumber: String?
}

extension Notification.Name {
    static let powerModelDidChange = Notification.Name("powerModelDidChange")
}
