import UIKit

/// The notice the developer published, shown as a card at the top of 电量. It is text only, it can be closed
/// for good, and it disappears on its own once `expiresAt` passes even if nothing new is published.
final class NoticeBannerView: UIView {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private var onDismiss: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        layer.borderWidth = 1

        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0

        bodyLabel.font = .preferredFont(forTextStyle: .footnote)
        bodyLabel.adjustsFontForContentSizeCategory = true
        bodyLabel.numberOfLines = 0
        bodyLabel.textColor = .secondaryLabel

        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.accessibilityLabel = "关闭公告"
        closeButton.tintColor = .tertiaryLabel
        closeButton.setContentHuggingPriority(.required, for: .horizontal)
        closeButton.addAction(UIAction { [weak self] _ in self?.onDismiss?() }, for: .touchUpInside)

        let text = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        text.axis = .vertical
        text.spacing = 3

        let row = UIStackView(arrangedSubviews: [iconView, text, closeButton])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            closeButton.widthAnchor.constraint(equalToConstant: 24)
        ])
        isAccessibilityElement = false
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    /// Returns false when there is nothing to show, so the caller can hide the whole view.
    @discardableResult
    func apply(_ notice: CloudConfig.Notice?, onDismiss: @escaping () -> Void) -> Bool {
        guard let notice else { return false }
        self.onDismiss = onDismiss

        let warning = notice.level == .warning
        let tint = warning ? UIColor.systemRed : PowerTheme.accent
        backgroundColor = tint.withAlphaComponent(0.09)
        layer.borderColor = tint.withAlphaComponent(0.28).cgColor
        iconView.image = UIImage(systemName: warning ? "exclamationmark.triangle.fill" : "megaphone.fill")
        iconView.tintColor = tint
        titleLabel.text = notice.title
        bodyLabel.text = notice.body
        closeButton.isHidden = !notice.dismissible
        accessibilityLabel = "\(notice.title)。\(notice.body)"
        return true
    }
}
