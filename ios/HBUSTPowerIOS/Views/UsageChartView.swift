import UIKit

struct DailyUsagePoint: Hashable {
    let date: Date
    let lighting: Double
    let airConditioning: Double

    var total: Double { lighting + airConditioning }
}

final class UsageChartView: UIView, UIGestureRecognizerDelegate {
    private(set) var selectedIndex: Int?
    var selectionChanged: ((DailyUsagePoint?) -> Void)?
    private let selectionFeedback = UISelectionFeedbackGenerator()
    var points: [DailyUsagePoint] = [] {
        didSet {
            if let selectedIndex, oldValue.indices.contains(selectedIndex) {
                self.selectedIndex = points.firstIndex { Calendar.current.isDate($0.date, inSameDayAs: oldValue[selectedIndex].date) }
            }
            if points.isEmpty { selectedIndex = nil }
            selectionChanged?(selectedIndex.map { points[$0] })
            updateAccessibility()
            setNeedsDisplay()
        }
    }
    var showsLighting = true { didSet { seriesVisibilityChanged() } }
    var showsAirConditioning = true { didSet { seriesVisibilityChanged() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        // Redraw instead of stretching when a folding phone opens or closes.
        contentMode = .redraw
        isAccessibilityElement = true
        accessibilityLabel = "照明和空调用量图表"
        accessibilityTraits = .adjustable
        accessibilityHint = "上下轻扫选择日期，或轻点、横向拖动图表查看当天用量"
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(chartTapped(_:))))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(chartDragged(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitPreferredContentSizeCategory.self]) { (view: UsageChartView, _) in view.setNeedsDisplay() }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard !points.isEmpty else {
            drawEmptyState(in: bounds)
            return
        }

        let visibleValues = points.flatMap { point -> [Double] in
            var values: [Double] = []
            if showsLighting { values.append(point.lighting) }
            if showsAirConditioning { values.append(point.airConditioning) }
            return values
        }
        let rawMaximum = max(1, visibleValues.max() ?? 1)
        let scaleMaximum = niceScaleMaximum(rawMaximum)
        let plot = plotRect
        let gridAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: min(15, UIFont.preferredFont(forTextStyle: .caption2).pointSize), weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]

        for index in 0...3 {
            let ratio = CGFloat(index) / 3
            let y = plot.maxY - plot.height * ratio
            let line = UIBezierPath()
            line.move(to: CGPoint(x: plot.minX, y: y))
            line.addLine(to: CGPoint(x: plot.maxX, y: y))
            UIColor.separator.withAlphaComponent(index == 0 ? 0.55 : 0.24).setStroke()
            line.lineWidth = 0.5
            line.stroke()

            let value = scaleMaximum * Double(index) / 3
            let text = formatAxisValue(value) as NSString
            let size = text.size(withAttributes: gridAttributes)
            text.draw(at: CGPoint(x: plot.minX - size.width - 7, y: y - size.height / 2), withAttributes: gridAttributes)
        }

        let groupWidth = plot.width / CGFloat(points.count)
        let visibleCount = (showsLighting ? 1 : 0) + (showsAirConditioning ? 1 : 0)
        let barWidth = min(14, groupWidth * (visibleCount == 1 ? 0.34 : 0.22))
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: min(15, UIFont.preferredFont(forTextStyle: .caption2).pointSize)),
            .foregroundColor: UIColor.secondaryLabel
        ]

        for (index, point) in points.enumerated() {
            let center = plot.minX + groupWidth * (CGFloat(index) + 0.5)
            if selectedIndex == index {
                PowerTheme.accent.withAlphaComponent(0.09).setFill()
                UIBezierPath(roundedRect: CGRect(x: center - groupWidth / 2 + 1, y: plot.minY, width: groupWidth - 2, height: plot.height), cornerRadius: 9).fill()
            }
            let emphasis: CGFloat = selectedIndex == nil || selectedIndex == index ? 1 : 0.35
            if showsLighting && showsAirConditioning {
                drawBar(value: point.lighting, maximum: scaleMaximum, x: center - barWidth - 2, width: barWidth, plot: plot, color: PowerTheme.lighting.withAlphaComponent(emphasis))
                drawBar(value: point.airConditioning, maximum: scaleMaximum, x: center + 2, width: barWidth, plot: plot, color: PowerTheme.cooling.withAlphaComponent(emphasis))
            } else if showsLighting {
                drawBar(value: point.lighting, maximum: scaleMaximum, x: center - barWidth / 2, width: barWidth, plot: plot, color: PowerTheme.lighting.withAlphaComponent(emphasis))
            } else if showsAirConditioning {
                drawBar(value: point.airConditioning, maximum: scaleMaximum, x: center - barWidth / 2, width: barWidth, plot: plot, color: PowerTheme.cooling.withAlphaComponent(emphasis))
            }

            let text = (Calendar.current.isDateInToday(point.date) ? "今天" : formatter.string(from: point.date)) as NSString
            let size = text.size(withAttributes: dateAttributes)
            if size.width < groupWidth - 2 || index == 0 || index == points.count - 1 || (index % 2 == 0 && index < points.count - 2) {
                text.draw(at: CGPoint(x: center - size.width / 2, y: plot.maxY + 9), withAttributes: dateAttributes)
            }
        }
    }

    private var plotRect: CGRect {
        CGRect(x: 36, y: 8, width: max(1, bounds.width - 42), height: max(1, bounds.height - 42))
    }

    func selectDay(at index: Int) {
        guard points.indices.contains(index), selectedIndex != index else { return }
        selectedIndex = index
        selectionFeedback.selectionChanged()
        selectionChanged?(points[index])
        updateAccessibility()
        setNeedsDisplay()
    }

    func clearSelection() {
        selectedIndex = nil
        selectionChanged?(nil)
        updateAccessibility()
        setNeedsDisplay()
    }

    private func select(at location: CGPoint) {
        guard !points.isEmpty else { return }
        let index = Int((location.x - plotRect.minX) / (plotRect.width / CGFloat(points.count)))
        selectDay(at: min(points.count - 1, max(0, index)))
    }

    @objc private func chartTapped(_ gesture: UITapGestureRecognizer) { select(at: gesture.location(in: self)) }
    @objc private func chartDragged(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began { selectionFeedback.prepare() }
        if gesture.state == .began || gesture.state == .changed || gesture.state == .ended { select(at: gesture.location(in: self)) }
    }
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: self)
        return abs(velocity.x) > abs(velocity.y)
    }
    override func accessibilityIncrement() { selectDay(at: min(points.count - 1, (selectedIndex ?? -1) + 1)) }
    override func accessibilityDecrement() { selectDay(at: max(0, (selectedIndex ?? points.count) - 1)) }

    private func niceScaleMaximum(_ value: Double) -> Double {
        let roughStep = value / 3
        let magnitude = pow(10, floor(log10(roughStep)))
        let normalized = roughStep / magnitude
        let step: Double
        if normalized <= 1 { step = 1 }
        else if normalized <= 2 { step = 2 }
        else if normalized <= 2.5 { step = 2.5 }
        else if normalized <= 5 { step = 5 }
        else { step = 10 }
        return step * magnitude * 3
    }

    private func formatAxisValue(_ value: Double) -> String {
        if value == 0 { return "0" }
        return value >= 10 ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }

    private func drawBar(value: Double, maximum: Double, x: CGFloat, width: CGFloat, plot: CGRect, color: UIColor) {
        let height = max(value > 0 ? 4 : 0, plot.height * CGFloat(value / maximum))
        let rect = CGRect(x: x, y: plot.maxY - height, width: width, height: height)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: min(width / 2, 5))
        color.setFill()
        path.fill()
    }

    private func drawEmptyState(in rect: CGRect) {
        let text = "暂无用量记录" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .subheadline),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2), withAttributes: attributes)
    }

    private func seriesVisibilityChanged() {
        updateAccessibility()
        if UIAccessibility.isReduceMotionEnabled {
            setNeedsDisplay()
        } else {
            UIView.transition(with: self, duration: 0.28, options: [.transitionCrossDissolve, .allowUserInteraction]) {
                self.setNeedsDisplay()
                self.layoutIfNeeded()
            }
        }
    }

    private func updateAccessibility() {
        let lighting = points.map(\.lighting).reduce(0, +)
        let ac = points.map(\.airConditioning).reduce(0, +)
        var visible: [String] = []
        if showsLighting { visible.append("照明") }
        if showsAirConditioning { visible.append("空调") }
        if let selectedIndex, points.indices.contains(selectedIndex) {
            let point = points[selectedIndex]
            accessibilityValue = String(format: "%@，照明 %.2f 度，空调 %.2f 度，合计 %.2f 度", point.date.formatted(date: .abbreviated, time: .omitted), point.lighting, point.airConditioning, point.total)
        } else {
            accessibilityValue = String(format: "当前显示%@，照明合计 %.2f 度，空调合计 %.2f 度", visible.joined(separator: "和"), lighting, ac)
        }
    }
}
