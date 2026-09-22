import UIKit

/// Shown in place of a feature the developer switched off from the published config, normally because the
/// school changed a page and the old path now fails. Switches fail open, so this only appears when the config
/// explicitly says `false`.
final class FeatureUnavailableView: UIView {
    init(title: String, detail: String) {
        super.init(frame: .zero)
        backgroundColor = PowerTheme.surface
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous

        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle"))
        icon.tintColor = .secondaryLabel
        icon.contentMode = .scaleAspectFit
        icon.heightAnchor.constraint(equalToConstant: 30).isActive = true

        let titleLabel = UILabel.powerLabel(title, style: .headline)
        titleLabel.textAlignment = .center
        let detailLabel = UILabel.powerLabel(detail, style: .footnote, color: .secondaryLabel)
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}
