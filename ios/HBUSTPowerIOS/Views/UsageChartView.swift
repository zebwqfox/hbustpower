import UIKit

struct DailyUsagePoint: Hashable {
    let date: Date
    let lighting: Double
    let airConditioning: Double

    var total: Double { lighting + airConditioning }
}

enum UsageSeries: CaseIterable {
    case total
    case lighting
    case airConditioning

    var title: String {
        switch self {
        case .total: "总量"
        case .lighting: "照明"
        case .airConditioning: "空调"
        }
    }

    func value(for point: DailyUsagePoint) -> Double {
        switch self {
        case .total: point.total
        case .lighting: point.lighting
        case .airConditioning: point.airConditioning
        }
    }
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
    var series: UsageSeries = .total {
        didSet {
            guard series != oldValue else { return }
            seriesChanged()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        // Redraw instead of stretching when a folding phone opens or closes.
        contentMode = .redraw
        isAccessibilityElement = true
        accessibilityLabel = "总量用量图表"
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

        let visibleValues = points.map { series.value(for: $0) }
        let rawMaximum = max(1, visibleValues.max() ?? 1)
        let scaleMaximum = niceScaleMaximum(rawMaximum)
        let plot = plotRect
        let barColor: UIColor = switch series {
        case .total: PowerTheme.accent
        case .lighting: PowerTheme.lighting
        case .airConditioning: PowerTheme.cooling
        }
        let axisSize = min(15, UIFont.preferredFont(forTextStyle: .caption2).pointSize)
        let gridAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: axisSize, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]
        // The daily average gets a dashed line and its own label on the axis, in the series colour.
        let average = visibleValues.reduce(0, +) / Double(visibleValues.count)
        let showsAverage = points.count > 1 && average > 0
        let averageY = plot.maxY - plot.height * CGFloat(average / scaleMaximum)
        let averageText = (average >= 100 ? String(format: "%.0f", average) : String(format: "%.1f", average)) as NSString
        let averageAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: axisSize, weight: .semibold),
            .foregroundColor: barColor
        ]
        let averageSize = averageText.size(withAttributes: averageAttributes)

        for index in 0...3 {
            let ratio = CGFloat(index) / 3
            let y = plot.maxY - plot.height * ratio
            let line = UIBezierPath()
            line.move(to: CGPoint(x: plot.minX, y: y))
            line.addLine(to: CGPoint(x: plot.maxX, y: y))
            UIColor.separator.withAlphaComponent(index == 0 ? 0.55 : 0.24).setStroke()
            line.lineWidth = 0.5
            line.stroke()

            guard !showsAverage || abs(y - averageY) >= averageSize.height else { continue }
            let value = scaleMaximum * Double(index) / 3
            let text = formatAxisValue(value) as NSString
            let size = text.size(withAttributes: gridAttributes)
            text.draw(at: CGPoint(x: plot.minX - size.width - 7, y: y - size.height / 2), withAttributes: gridAttributes)
        }

        let groupWidth = plot.width / CGFloat(points.count)
        let barWidth = min(14, groupWidth * 0.34)
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
            // 总量 shows what the total is made of: air conditioning at the base, lighting on top.
            let segments: [(value: Double, color: UIColor)] = series == .total
                ? [(point.airConditioning, PowerTheme.cooling), (point.lighting, PowerTheme.lighting)]
                : [(series.value(for: point), barColor)]
            let isToday = Calendar.current.isDateInToday(point.date)
            drawBar(segments, maximum: scaleMaximum, x: center - barWidth / 2, width: barWidth, plot: plot,
                    emphasis: emphasis, outline: isToday ? barColor : nil)

            let text = (isToday ? "今天" : formatter.string(from: point.date)) as NSString
            let size = text.size(withAttributes: dateAttributes)
            if size.width < groupWidth - 2 || index == 0 || index == points.count - 1 || (index % 2 == 0 && index < points.count - 2) {
                text.draw(at: CGPoint(x: center - size.width / 2, y: plot.maxY + 9), withAttributes: dateAttributes)
            }
        }

        if showsAverage {
            let line = UIBezierPath()
            line.move(to: CGPoint(x: plot.minX, y: averageY))
            line.addLine(to: CGPoint(x: plot.maxX, y: averageY))
            line.lineWidth = 1
            line.setLineDash([3, 3], count: 2, phase: 0)
            barColor.withAlphaComponent(0.6).setStroke()
            line.stroke()
            averageText.draw(at: CGPoint(x: max(0, plot.minX - averageSize.width - 7), y: averageY - averageSize.height / 2),
                             withAttributes: averageAttributes)
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

    /// One bar, stacked from the bottom. Segments share a single rounded outline and are parted by a thin gap.
    /// A bar with an `outline` is a day still in progress: a lighter fill inside a crisp edge.
    private func drawBar(_ segments: [(value: Double, color: UIColor)], maximum: Double, x: CGFloat, width: CGFloat,
                         plot: CGRect, emphasis: CGFloat, outline: UIColor?) {
        let total = segments.map(\.value).reduce(0, +)
        guard total > 0, let context = UIGraphicsGetCurrentContext() else { return }
        let height = max(4, plot.height * CGFloat(total / maximum))
        let rect = CGRect(x: x, y: plot.maxY - height, width: width, height: height)
        let radius = min(width / 2, 5)
        context.saveGState()
        UIBezierPath(roundedRect: rect, cornerRadius: radius).addClip()
        var bottom = rect.maxY
        for segment in segments where segment.value > 0 {
            let top = bottom - height * CGFloat(segment.value / total)
            let base = bottom < rect.maxY ? bottom - 1.5 : bottom
            segment.color.withAlphaComponent(emphasis * (outline == nil ? 1 : 0.4)).setFill()
            UIBezierPath(rect: CGRect(x: rect.minX, y: top, width: rect.width, height: max(0, base - top))).fill()
            bottom = top
        }
        context.restoreGState()
        guard let outline else { return }
        let edge = UIBezierPath(roundedRect: rect.insetBy(dx: 0.6, dy: 0.6), cornerRadius: max(0, radius - 0.6))
        edge.lineWidth = 1.2
        outline.withAlphaComponent(emphasis).setStroke()
        edge.stroke()
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

    private func seriesChanged() {
        updateAccessibility()
        accessibilityLabel = "\(series.title)用量图表"
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
        let total = points.map { series.value(for: $0) }.reduce(0, +)
        if let selectedIndex, points.indices.contains(selectedIndex) {
            let point = points[selectedIndex]
            accessibilityValue = String(format: "%@，%@ %.2f 度", point.date.formatted(date: .abbreviated, time: .omitted), series.title, series.value(for: point))
        } else {
            let average = points.isEmpty ? 0 : total / Double(points.count)
            accessibilityValue = String(format: "当前显示%@，近 7 日合计 %.2f 度，日均 %.2f 度", series.title, total, average)
        }
    }
}
