import SwiftUI
import WidgetKit

@main
struct HBUSTPowerWidgets: WidgetBundle {
    var body: some Widget { BalanceWidget() }
}

struct BalanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> BalanceEntry {
        BalanceEntry(date: .now, snapshot: PowerWidgetStore.placeholder, theme: .classic)
    }

    func getSnapshot(in context: Context, completion: @escaping (BalanceEntry) -> Void) {
        let stored = PowerWidgetStore.load()
        completion(BalanceEntry(date: .now, snapshot: context.isPreview ? (stored ?? PowerWidgetStore.placeholder) : stored,
                                theme: PowerWidgetStore.theme()))
    }

    /// The app refreshes when you open it; the widget just re-reads what was stored, and asks to be woken hourly
    /// so the "updated" line and the forecast stay roughly current.
    func getTimeline(in context: Context, completion: @escaping (Timeline<BalanceEntry>) -> Void) {
        let entry = BalanceEntry(date: .now, snapshot: PowerWidgetStore.load(), theme: PowerWidgetStore.theme())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600))))
    }
}

struct BalanceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: PowerWidgetStore.widgetKind, provider: BalanceProvider()) { entry in
            BalanceWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(entry.theme.hero) }
        }
        .configurationDisplayName("宿舍电量")
        .description("剩余电量、还能用多久，以及最近几天的用量。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

#Preview("小号", as: .systemSmall) {
    BalanceWidget()
} timeline: {
    BalanceEntry(date: .now, snapshot: PowerWidgetStore.placeholder, theme: .classic)
    BalanceEntry(date: .now, snapshot: PowerWidgetStore.placeholder, theme: .purpleBird)
}

#Preview("中号", as: .systemMedium) {
    BalanceWidget()
} timeline: {
    BalanceEntry(date: .now, snapshot: PowerWidgetStore.placeholder, theme: .mapleYellow)
}
