import Foundation

/// Local "how much should we top up?" arithmetic. Nothing here talks to the school; it only uses the latest snapshot.
struct RechargePlanner: Sendable {
    let balanceKWh: Double
    let unitPrice: Double
    /// Lighting + air conditioning, per recorded day.
    let dailyKWh: Double

    init?(snapshot: ElectricitySnapshot) {
        guard let price = snapshot.unitPrice, price > 0,
              let lighting = snapshot.recentAverage(kind: "照明"),
              let airConditioning = snapshot.recentAverage(kind: "空调"),
              lighting + airConditioning > 0 else { return nil }
        self.init(balanceKWh: max(0, snapshot.purchasedKWh), unitPrice: price, dailyKWh: lighting + airConditioning)
    }

    init(balanceKWh: Double, unitPrice: Double, dailyKWh: Double) {
        self.balanceKWh = balanceKWh
        self.unitPrice = unitPrice
        self.dailyKWh = dailyKWh
    }

    struct AmountPlan: Equatable, Sendable {
        let addedKWh: Double
        let totalDays: Double
        let lastsUntil: Date
    }

    /// What topping up `amount` yuan buys, and how long balance + purchase lasts at the recent pace.
    func plan(amount: Double, now: Date = .now) -> AmountPlan {
        let added = max(0, amount) / unitPrice
        let days = (balanceKWh + added) / dailyKWh
        return AmountPlan(addedKWh: added, totalDays: days, lastsUntil: now.addingTimeInterval(days * 86_400))
    }

    struct DatePlan: Equatable, Sendable {
        let days: Int
        let neededKWh: Double
        /// Whole yuan, rounded up so the power really lasts.
        let amount: Int
    }

    /// The top-up needed for power to last through the end of `target` (a calendar day).
    func plan(until target: Date, now: Date = .now, calendar: Calendar = .current) -> DatePlan {
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: target)
        let days = max(0, (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
        // Today is partly used already; count the remaining fraction of today rather than a whole day.
        let elapsedToday = now.timeIntervalSince(start) / 86_400
        let neededDays = max(0, Double(days) - elapsedToday)
        let needed = max(0, neededDays * dailyKWh - balanceKWh)
        return DatePlan(days: days, neededKWh: needed, amount: Int((needed * unitPrice).rounded(.up)))
    }

    /// Each roommate's share, in yuan with two decimals, rounded up so the total is never short.
    static func share(of amount: Double, among people: Int) -> Double {
        guard people > 0 else { return amount }
        return (amount / Double(people) * 100).rounded(.up) / 100
    }
}

/// Totals shown at the top of the recharge records.
struct RechargeSummary: Equatable, Sendable {
    let count: Int
    let totalYuan: Double?
    let totalKWh: Double?
    let latest: Date?

    init(records: [RechargeRecord]) {
        count = records.count
        latest = records.map(\.date).max()
        let yuan = records.compactMap { Self.number(in: $0.amountText, unit: "元") }
        let kWh = records.compactMap { Self.number(in: $0.kWhText, unit: "度") }
        totalYuan = yuan.isEmpty ? nil : yuan.reduce(0, +)
        totalKWh = kWh.isEmpty ? nil : kWh.reduce(0, +)
    }

    /// "100.00元" → 100. Returns nil for "-" or text in another unit, so missing fields are not counted as zero.
    static func number(in text: String, unit: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasSuffix(unit) else { return nil }
        return Double(trimmed.dropLast(unit.count).trimmingCharacters(in: .whitespaces))
    }
}
