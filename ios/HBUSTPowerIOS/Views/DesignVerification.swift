#if DEBUG
import UIKit

/// An offline component smoke test and repeatable motion preview, omitted from Release.
@MainActor
enum DesignVerification {
    static func run(root: RootTabBarController) {
        guard CommandLine.arguments.contains("--verify-design") || CommandLine.arguments.contains("--verify-welcome") else { return }
        Task { @MainActor in
            @MainActor func pause(_ seconds: Double) async {
                try? await Task.sleep(for: .seconds(seconds))
            }
            @MainActor func descendants(_ view: UIView) -> [UIView] {
                [view] + view.subviews.flatMap(descendants)
            }
            @MainActor func visibleController() -> UIViewController {
                (root.selectedViewController as! UINavigationController).topViewController!
            }
            @MainActor func findControl(_ label: String) -> UIControl {
                let views = descendants(visibleController().view)
                return views.compactMap { $0 as? UIControl }.first { $0.accessibilityLabel?.contains(label) == true }!
            }
            @MainActor func press(_ control: UIControl) async {
                precondition(control.isEnabled, "A visible action must be enabled")
                control.isHighlighted = true
                await pause(0.18)
                control.isHighlighted = false
                control.sendActions(for: .touchUpInside)
                await pause(0.65)
            }
            await pause(1.5)
            let overview = visibleController()
            overview.view.layoutIfNeeded()
            if CommandLine.arguments.contains("--verify-welcome") {
                let center = findControl("点亮电力插画")
                await press(center)
                await press(center)
                center.sendActions(for: .touchUpInside)
                await pause(0.06)
                center.sendActions(for: .touchUpInside)
                await pause(0.7)
                let tile = findControl("照明互动贴纸")
                await press(tile)
                await press(center)
                precondition(overview.view.window != nil)
                print("DESIGN_CHECK PASS: repeated welcome presses, completed and interrupted springs, satellite feedback")
                return
            }
            let recharge = descendants(overview.view).compactMap { $0 as? UIButton }.first { $0.configuration?.title == "电费充值" }!
            print("DESIGN_CHECK rechargeEnabled=\(recharge.isEnabled), alpha=\(recharge.alpha), foreground=\(String(describing: recharge.configuration?.baseForegroundColor))")
            let hero = findControl("剩余电量")
            await press(hero)
            precondition(hero.accessibilityValue?.contains("日均") == true)
            await pause(1)
            await press(hero)
            precondition(hero.accessibilityValue == "估算说明已收起")
            await pause(0.7)
            await press(findControl("照明每日平均用量"))
            precondition(root.selectedIndex == 1)
            let usage = visibleController()
            let chart = descendants(usage.view).compactMap { $0 as? UsageChartView }.first!
            precondition(chart.series == .lighting)
            await pause(1)
            for index in [1, 3, 5] {
                chart.selectDay(at: index)
                precondition(chart.selectedIndex == index)
                await pause(0.6)
            }
            let dayReadout = descendants(usage.view).compactMap { $0 as? UILabel }.first { $0.text?.contains("照明") == true && $0.text?.contains("度") == true }
            precondition(dayReadout != nil, "Chart selection must update the daily readout")
            chart.clearSelection()
            precondition(chart.selectedIndex == nil)
            await pause(0.8)
            root.selectedIndex = 0
            print("DESIGN_CHECK PASS: hero disclosure, press states, category navigation, chart selection, linked readout, clear selection")
        }
    }
}
#endif
