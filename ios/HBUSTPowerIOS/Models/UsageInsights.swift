import Foundation

/// Small, friendly observations derived from the school's usage and recharge records.
struct UsageInsight: Hashable, Sendable {
    enum Tone: Sendable { case good, neutral, heads }

    let id: String
    let symbol: String
    let value: String
    let caption: String
    let sticker: String?
    let tone: Tone
}

enum UsageInsights {
    static func make(from snapshot: ElectricitySnapshot, now: Date = .now, calendar: Calendar = .current) -> [UsageInsight] {
        let days = dailyTotals(snapshot.usageRecords, calendar: calendar)
        return [
            weekComparison(days),
            savingStreak(days),
            peakDay(days),
            airConditioningShare(snapshot.usageRecords, days: days, calendar: calendar),
            balanceValue(snapshot),
            daysSinceRecharge(snapshot.rechargeRecords, now: now, calendar: calendar)
        ].compactMap { $0 }
    }

    /// Oldest first; one entry per recorded day.
    static func dailyTotals(_ records: [UsageRecord], calendar: Calendar) -> [(day: Date, kWh: Double)] {
        Dictionary(grouping: records) { calendar.startOfDay(for: $0.date) }
            .map { (day: $0.key, kWh: $0.value.map(\.kWh).reduce(0, +)) }
            .sorted { $0.day < $1.day }
    }

    static func weekComparison(_ days: [(day: Date, kWh: Double)]) -> UsageInsight? {
        guard days.count >= 14 else { return nil }
        let recent = days.suffix(7).map(\.kWh).reduce(0, +)
        let previous = days.dropLast(7).suffix(7).map(\.kWh).reduce(0, +)
        guard previous > 0 else { return nil }
        let change = (recent - previous) / previous
        let percent = Int((abs(change) * 100).rounded())
        if percent < 3 {
            return UsageInsight(id: "week", symbol: "equal.circle", value: "和上周差不多", caption: "最近 7 天用电很稳定", sticker: nil, tone: .neutral)
        }
        return change < 0
            ? UsageInsight(id: "week", symbol: "arrow.down.right", value: "省了 \(percent)%", caption: "最近 7 天比之前 7 天", sticker: percent >= 10 ? "省电小能手" : nil, tone: .good)
            : UsageInsight(id: "week", symbol: "arrow.up.right", value: "多用 \(percent)%", caption: "最近 7 天比之前 7 天", sticker: nil, tone: .heads)
    }

    /// Consecutive most recent days at or below the average of all recorded days.
    static func savingStreak(_ days: [(day: Date, kWh: Double)]) -> UsageInsight? {
        guard days.count >= 5 else { return nil }
        let average = days.map(\.kWh).reduce(0, +) / Double(days.count)
        let streak = days.reversed().prefix { $0.kWh <= average }.count
        guard streak >= 2 else { return nil }
        return UsageInsight(id: "streak", symbol: "flame", value: "连续 \(streak) 天", caption: String(format: "低于日均 %.1f 度", average),
                            sticker: streak >= 7 ? "一周达成" : nil, tone: .good)
    }

    static func peakDay(_ days: [(day: Date, kWh: Double)]) -> UsageInsight? {
        guard days.count >= 3, let peak = days.suffix(14).max(by: { $0.kWh < $1.kWh }) else { return nil }
        let date = peak.day.formatted(.dateTime.month(.defaultDigits).day())
        return UsageInsight(id: "peak", symbol: "bolt.badge.clock", value: String(format: "%.1f 度", peak.kWh), caption: "\(date) 用电最多", sticker: nil, tone: .neutral)
    }

    static func airConditioningShare(_ records: [UsageRecord], days: [(day: Date, kWh: Double)], calendar: Calendar) -> UsageInsight? {
        guard let first = days.suffix(7).first?.day else { return nil }
        let recent = records.filter { calendar.startOfDay(for: $0.date) >= first }
        let total = recent.map(\.kWh).reduce(0, +)
        guard total > 0 else { return nil }
        let share = Int((recent.filter { $0.kind == "空调" }.map(\.kWh).reduce(0, +) / total * 100).rounded())
        return UsageInsight(id: "ac", symbol: "snowflake", value: "空调占 \(share)%", caption: "最近 7 天的电都去哪了",
                            sticker: share >= 80 ? "空调重度用户" : nil, tone: share >= 80 ? .heads : .neutral)
    }

    static func balanceValue(_ snapshot: ElectricitySnapshot) -> UsageInsight? {
        guard let price = snapshot.unitPrice, price > 0, snapshot.purchasedKWh > 0 else { return nil }
        return UsageInsight(id: "value", symbol: "yensign.circle", value: String(format: "约 ¥%.2f", snapshot.purchasedKWh * price),
                            caption: "剩余电量折合电费", sticker: nil, tone: .neutral)
    }

    static func daysSinceRecharge(_ records: [RechargeRecord], now: Date, calendar: Calendar) -> UsageInsight? {
        guard let latest = records.map(\.date).max(),
              let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: latest), to: calendar.startOfDay(for: now)).day,
              days >= 0 else { return nil }
        return UsageInsight(id: "recharge", symbol: "clock.arrow.circlepath", value: days == 0 ? "今天" : "\(days) 天前",
                            caption: "上一次充值", sticker: nil, tone: .neutral)
    }
}
