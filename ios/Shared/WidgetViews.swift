import SwiftUI
import WidgetKit

/// The widget's SwiftUI views live in Shared so the app can render them in its debug preview at real widget sizes.
struct BalanceEntry: TimelineEntry {
    let date: Date
    let snapshot: PowerWidgetSnapshot?
    let theme: PowerThemeStyle
}

struct BalanceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BalanceEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryCircular: CircularView(snapshot: snapshot)
            case .accessoryRectangular: RectangularView(snapshot: snapshot)
            case .accessoryInline: Label(inlineText(snapshot), systemImage: "bolt.fill")
            case .systemMedium: MediumView(snapshot: snapshot, theme: entry.theme)
            default: SmallView(snapshot: snapshot, theme: entry.theme)
            }
        } else {
            EmptyStateView(theme: entry.theme, family: family)
        }
    }

    private func inlineText(_ snapshot: PowerWidgetSnapshot) -> String {
        let days = snapshot.predictedDays.map { String(format: " · %.1f 天", $0) } ?? ""
        return String(format: "%.1f 度", snapshot.balanceKWh) + days
    }
}

// MARK: - Home screen

struct SmallView: View {
    let snapshot: PowerWidgetSnapshot
    let theme: PowerThemeStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderRow(snapshot: snapshot, theme: theme)
            Spacer(minLength: 6)
            BalanceNumber(snapshot: snapshot, theme: theme, size: 38)
            Spacer(minLength: 6)
            ForecastBar(snapshot: snapshot, theme: theme)
        }
    }
}

struct MediumView: View {
    let snapshot: PowerWidgetSnapshot
    let theme: PowerThemeStyle

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                HeaderRow(snapshot: snapshot, theme: theme)
                Spacer(minLength: 4)
                BalanceNumber(snapshot: snapshot, theme: theme, size: 40)
                Spacer(minLength: 4)
                ForecastBar(snapshot: snapshot, theme: theme)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                if let lighting = snapshot.dailyLighting, let cooling = snapshot.dailyAirConditioning {
                    HStack(spacing: 10) {
                        DailyFigure(title: "照明", value: lighting, color: Color(theme.secondary))
                        DailyFigure(title: "空调", value: cooling, color: Color(theme.accent))
                    }
                }
                UsageBars(days: snapshot.days, theme: theme)
                Text("更新于 \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct HeaderRow: View {
    let snapshot: PowerWidgetSnapshot
    let theme: PowerThemeStyle

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: theme.symbol)
                .font(.caption2.weight(.bold))
            Text(snapshot.room ?? "我的宿舍")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color(theme.accent))
    }
}

struct BalanceNumber: View {
    let snapshot: PowerWidgetSnapshot
    let theme: PowerThemeStyle
    let size: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(String(format: "%.2f", snapshot.balanceKWh))
                .font(.system(size: size, weight: .medium, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("度").font(.caption).padding(.leading, 1)
        }
        .foregroundStyle(Color(snapshot.isLow ? theme.secondary : theme.accent))
    }
}

/// A slim bar that fills with the forecast: a month of power is a full bar.
struct ForecastBar: View {
    let snapshot: PowerWidgetSnapshot
    let theme: PowerThemeStyle

    private var tint: Color { Color(snapshot.isLow ? theme.secondary : theme.accent) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.18))
                    Capsule().fill(tint)
                        .frame(width: max(6, geometry.size.width * snapshot.gaugeLevel))
                }
            }
            .frame(height: 6)
            Text(forecastText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var forecastText: String {
        if snapshot.isLow { return "电量偏低，记得充值" }
        guard let days = snapshot.predictedDays else { return "用量记录足够后可估算" }
        return String(format: "约还能用 %.1f 天", days)
    }
}

struct DailyFigure: View {
    let title: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(String(format: "%.1f", value))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Last seven recorded days, lighting stacked under air conditioning.
struct UsageBars: View {
    let days: [PowerWidgetSnapshot.Day]
    let theme: PowerThemeStyle

    var body: some View {
        let peak = max(days.map(\.total).max() ?? 1, 0.1)
        let height: CGFloat = 40
        HStack(alignment: .bottom, spacing: 7) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 3) {
                    // Air conditioning sits on top of lighting, like the chart in the app.
                    VStack(spacing: 1.5) {
                        RoundedRectangle(cornerRadius: 2.5).fill(Color(theme.accent))
                            .frame(width: 6, height: max(2, height * day.airConditioning / peak))
                        RoundedRectangle(cornerRadius: 2.5).fill(Color(theme.secondary))
                            .frame(width: 6, height: max(2, height * day.lighting / peak))
                    }
                    Text("\(Calendar.current.component(.day, from: day.date))")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Lock screen

struct CircularView: View {
    let snapshot: PowerWidgetSnapshot

    var body: some View {
        Gauge(value: snapshot.gaugeLevel) {
            Image(systemName: "bolt.fill")
        } currentValueLabel: {
            Text(String(format: "%.0f", snapshot.balanceKWh))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

struct RectangularView: View {
    let snapshot: PowerWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(snapshot.room ?? "我的宿舍", systemImage: "bolt.fill")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            Text(String(format: "%.2f 度", snapshot.balanceKWh))
                .font(.headline)
            if let days = snapshot.predictedDays {
                Text(String(format: "约还能用 %.1f 天", days))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Nothing stored yet

struct EmptyStateView: View {
    let theme: PowerThemeStyle
    let family: WidgetFamily

    var body: some View {
        if family == .accessoryInline {
            Label("打开湖科电量", systemImage: "bolt.slash")
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "bolt.slash.fill")
                    .foregroundStyle(Color(theme.accent))
                Text("还没有电量数据")
                    .font(.caption.weight(.semibold))
                Text("打开一次湖科电量，登录后小组件就会显示。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

