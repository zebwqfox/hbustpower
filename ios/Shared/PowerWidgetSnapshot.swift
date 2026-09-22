import Foundation

/// The little bit of data the home screen widgets show. Written by the app after every successful refresh and
/// read by the widget extension; both sides share it through the App Group container.
struct PowerWidgetSnapshot: Codable, Equatable, Sendable {
    struct Day: Codable, Equatable, Sendable {
        let date: Date
        let lighting: Double
        let airConditioning: Double
        var total: Double { lighting + airConditioning }
    }

    var room: String?
    var balanceKWh: Double
    var predictedDays: Double?
    var dailyLighting: Double?
    var dailyAirConditioning: Double?
    /// Oldest first, at most the last seven recorded days.
    var days: [Day]
    var isLow: Bool
    var updatedAt: Date

    var dailyTotal: Double? {
        guard let dailyLighting, let dailyAirConditioning else { return nil }
        return dailyLighting + dailyAirConditioning
    }

    /// How full the gauge looks: a month of forecast is "full", as on the balance card.
    var gaugeLevel: Double {
        guard let predictedDays else { return min(1, max(0, balanceKWh / 300)) }
        return min(1, max(0, predictedDays / 30))
    }
}

/// Reads and writes the widget snapshot plus the chosen theme in the shared container.
/// Without the App Group entitlement (free-account sideloading) the shared defaults are unavailable; the app keeps
/// working and the widget simply shows its "open the app once" placeholder.
enum PowerWidgetStore {
    static let appGroup = "group.com.local.hbustpower"
    static let widgetKind = "HBUSTPowerBalance"
    private static let snapshotKey = "widget.snapshot"
    private static let themeKey = "widget.theme"

    nonisolated(unsafe) private static let shared = UserDefaults(suiteName: appGroup)

    /// True only when the App Group entitlement really granted a shared container. `UserDefaults(suiteName:)` can
    /// hand back an object even when the group is not entitled, so ask the file system instead.
    static var isAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) != nil
    }

    /// Where the shared container lives, for the diagnostics screen.
    static var containerPath: String? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?.path
    }

    static func save(_ snapshot: PowerWidgetSnapshot, theme: PowerThemeStyle) {
        guard let shared, let data = try? JSONEncoder().encode(snapshot) else { return }
        shared.set(data, forKey: snapshotKey)
        shared.set(theme.rawValue, forKey: themeKey)
    }

    static func saveTheme(_ theme: PowerThemeStyle) {
        shared?.set(theme.rawValue, forKey: themeKey)
    }

    static func clear() {
        shared?.removeObject(forKey: snapshotKey)
    }

    static func load() -> PowerWidgetSnapshot? {
        guard let data = shared?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(PowerWidgetSnapshot.self, from: data)
    }

    static func theme() -> PowerThemeStyle {
        shared?.string(forKey: themeKey).flatMap(PowerThemeStyle.init(rawValue:)) ?? .classic
    }

    /// Demo content for the widget gallery and for previews.
    static var placeholder: PowerWidgetSnapshot {
        let calendar = Calendar.current
        let days = (0..<7).reversed().map { offset in
            PowerWidgetSnapshot.Day(date: calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now,
                                    lighting: 4.6 + Double(offset % 3) * 0.5,
                                    airConditioning: 18.5 + Double(offset % 4) * 1.4)
        }
        return PowerWidgetSnapshot(room: "东10-625", balanceKWh: 122.99, predictedDays: 5.2,
                                   dailyLighting: 4.16, dailyAirConditioning: 9.47, days: days,
                                   isLow: false, updatedAt: .now)
    }
}
