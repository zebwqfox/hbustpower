import UIKit

/// Small, interruptible responses shared by all custom controls.
enum PowerMotion {
    static func animate(duration: TimeInterval = 0.36, damping: CGFloat = 1, _ changes: @escaping () -> Void) {
        if UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.12, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: changes)
        } else {
            UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: damping,
                           initialSpringVelocity: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: changes)
        }
    }

    static func reveal(_ views: [UIView]) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        for (index, view) in views.enumerated() {
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: 0, y: 12)
            UIView.animate(withDuration: 0.42, delay: Double(index) * 0.045, usingSpringWithDamping: 1,
                           initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                view.alpha = 1
                view.transform = .identity
            }
        }
    }

    static func replaceText(on label: UILabel, with text: String) {
        guard label.text != text else { return }
        UIView.transition(with: label, duration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.2,
                          options: [.transitionCrossDissolve, .beginFromCurrentState, .allowUserInteraction]) {
            label.text = text
        }
    }
}

final class PowerActionButton: UIButton {
    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted, isEnabled else { return }
            if isHighlighted { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55) }
            let pressed = isHighlighted
            PowerMotion.animate(duration: pressed ? 0.16 : 0.34, damping: pressed ? 1 : 0.86) {
                self.transform = pressed && !UIAccessibility.isReduceMotionEnabled
                    ? CGAffineTransform(scaleX: 0.965, y: 0.965) : .identity
                self.alpha = pressed ? 0.82 : 1
            }
        }
    }
}

/// Card controls use the same press language as buttons, with a subtler scale.
class PowerInteractiveControl: UIControl {
    override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else { return }
            let pressed = isHighlighted
            if pressed { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.45) }
            PowerMotion.animate(duration: pressed ? 0.16 : 0.38, damping: pressed ? 1 : 0.86) {
                self.transform = pressed && !UIAccessibility.isReduceMotionEnabled
                    ? CGAffineTransform(scaleX: 0.978, y: 0.978) : .identity
                self.alpha = pressed ? 0.88 : 1
            }
        }
    }
}
