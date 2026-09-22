import UIKit

/// Colour schemes. The two extra ones are modelled on friends' fursuits: 紫鸟紫 (black fur, violet markings,
/// amber eyes) and 枫烻黄 (grey fur, yellow markings, red collar with a gold bell).
enum PowerThemeStyle: String, CaseIterable, Sendable {
    case classic, purpleBird, mapleYellow

    var name: String {
        switch self {
        case .classic: "湖科蓝"
        case .purpleBird: "紫鸟紫"
        case .mapleYellow: "枫烻黄"
        }
    }

    var tagline: String {
        switch self {
        case .classic: "云白配清蓝，App 原本的样子"
        case .purpleBird: "夜色里的紫与琥珀色的眼睛"
        case .mapleYellow: "灰黄配色，脖子上挂着金铃铛"
        }
    }

    /// Credit shown under the friends' themes.
    var credit: String? {
        switch self {
        case .classic: nil
        case .purpleBird, .mapleYellow: "配色来自朋友「\(name)」"
        }
    }

    var symbol: String {
        switch self {
        case .classic: "bolt.fill"
        case .purpleBird: "moon.stars.fill"
        case .mapleYellow: "bell.fill"
        }
    }

    /// Shown when the theme's signature animation plays.
    var greeting: String {
        switch self {
        case .classic: "⚡ 电力满满"
        case .purpleBird: "🌙 夜里也在偷偷发电"
        case .mapleYellow: "🔔 叮——铃铛响了一下"
        }
    }

    /// An extra line the pull-to-charge indicator may show in this theme.
    var chargingLine: String {
        switch self {
        case .classic: "电流正在赶来…"
        case .purpleBird: "夜色里悄悄充电…"
        case .mapleYellow: "铃铛一响，电就来了…"
        }
    }

    // MARK: Colours

    fileprivate struct Pair {
        let light: UIColor
        let dark: UIColor
        var dynamic: UIColor { UIColor { $0.userInterfaceStyle == .dark ? dark : light } }
    }

    private var backgroundPair: Pair {
        switch self {
        case .classic: Pair(light: .rgb(0.965, 0.977, 0.995), dark: .rgb(0.04, 0.06, 0.10))
        case .purpleBird: Pair(light: .rgb(0.975, 0.970, 0.995), dark: .rgb(0.055, 0.042, 0.085))
        case .mapleYellow: Pair(light: .rgb(0.995, 0.985, 0.960), dark: .rgb(0.075, 0.068, 0.045))
        }
    }

    private var surfacePair: Pair {
        switch self {
        case .classic: Pair(light: .white, dark: .rgb(0.08, 0.11, 0.17))
        case .purpleBird: Pair(light: .white, dark: .rgb(0.115, 0.095, 0.165))
        case .mapleYellow: Pair(light: .white, dark: .rgb(0.145, 0.130, 0.090))
        }
    }

    private var accentPair: Pair {
        switch self {
        case .classic: Pair(light: .rgb(0.12, 0.34, 0.76), dark: .rgb(0.52, 0.72, 1.0))
        case .purpleBird: Pair(light: .rgb(0.36, 0.18, 0.78), dark: .rgb(0.72, 0.61, 1.0))
        case .mapleYellow: Pair(light: .rgb(0.60, 0.42, 0.02), dark: .rgb(1.0, 0.82, 0.28))
        }
    }

    private var heroPair: Pair {
        switch self {
        case .classic: Pair(light: .rgb(0.86, 0.925, 1.0), dark: .rgb(0.085, 0.16, 0.29))
        case .purpleBird: Pair(light: .rgb(0.90, 0.87, 0.99), dark: .rgb(0.16, 0.12, 0.30))
        case .mapleYellow: Pair(light: .rgb(1.0, 0.94, 0.78), dark: .rgb(0.22, 0.18, 0.07))
        }
    }

    /// The warm secondary: lighting figures, low-balance warnings and stickers.
    private var secondaryPair: Pair {
        switch self {
        case .classic: Pair(light: .rgb(0.67, 0.40, 0.13), dark: .rgb(0.94, 0.73, 0.40))
        case .purpleBird: Pair(light: .rgb(0.78, 0.45, 0.05), dark: .rgb(1.0, 0.76, 0.35))
        case .mapleYellow: Pair(light: .rgb(0.72, 0.16, 0.13), dark: .rgb(1.0, 0.50, 0.42))
        }
    }

    /// Sparks and the charging ring; always bright enough to read as "electric".
    private var sparkPair: Pair {
        switch self {
        case .classic: Pair(light: .rgb(1.0, 0.66, 0.05), dark: .rgb(1.0, 0.80, 0.30))
        case .purpleBird: Pair(light: .rgb(0.55, 0.30, 0.95), dark: .rgb(0.80, 0.66, 1.0))
        case .mapleYellow: Pair(light: .rgb(0.95, 0.70, 0.05), dark: .rgb(1.0, 0.85, 0.30))
        }
    }

    var background: UIColor { backgroundPair.dynamic }
    var surface: UIColor { surfacePair.dynamic }
    var accent: UIColor { accentPair.dynamic }
    var hero: UIColor { heroPair.dynamic }
    var secondary: UIColor { secondaryPair.dynamic }
    var spark: UIColor { sparkPair.dynamic }
}

private extension UIColor {
    static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

/// Remembers the chosen theme. Changing it rebuilds the interface, since colours already drawn cannot repaint.
/// Only ever touched from the main thread, like the rest of the UI layer.
final class PowerThemeStore {
    nonisolated(unsafe) static let shared = PowerThemeStore()
    static let didChange = Notification.Name("powerThemeDidChange")
    private static let key = "appTheme"

    private let defaults: UserDefaults
    private(set) var style: PowerThemeStyle

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        style = (defaults.string(forKey: Self.key).flatMap(PowerThemeStyle.init(rawValue:))) ?? .classic
    }

    func select(_ style: PowerThemeStyle) {
        guard style != self.style else { return }
        self.style = style
        defaults.set(style.rawValue, forKey: Self.key)
        // Keep the widgets in the same colours as the app.
        PowerWidgetStore.saveTheme(style)
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }
}
