import UIKit

/// A short message on a glass capsule, floating above the tab bar (DESIGN.md §2), with an
/// optional action beside it: "Deleted Eggs  Undo". It goes by itself after a few seconds, or
/// when its action is used. One at a time: showing another replaces it.
final class ToastView: UIView {

    private let effectView: UIVisualEffectView
    private let label = UILabel()
    private let actionButton = UIButton(type: .system)
    private var action: (() -> Void)?
    private var hideTask: Task<Void, Never>?

    override init(frame: CGRect) {
        let glass = UIGlassEffect()
        glass.isInteractive = true
        effectView = UIVisualEffectView(effect: glass)
        super.init(frame: frame)

        effectView.cornerConfiguration = .capsule()
        effectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effectView)

        label.font = UIFont.bodyText
        label.textColor = UIColor.textPrimary
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = UIColor.accentGreen
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        configuration.titleTextAttributesTransformer = .cardTitle
        actionButton.configuration = configuration
        actionButton.setContentHuggingPriority(.required, for: .horizontal)
        actionButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        actionButton.addAction(UIAction { [weak self] _ in self?.perform() }, for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [label, actionButton])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Metrics.spaceTight
        row.translatesAutoresizingMaskIntoConstraints = false
        effectView.contentView.addSubview(row)

        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.topAnchor.constraint(equalTo: effectView.contentView.topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: effectView.contentView.bottomAnchor, constant: -6),
            row.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor, constant: Metrics.spaceInner),
            row.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor, constant: -Metrics.spaceTight),
        ])
        alpha = 0
        isHidden = true
        accessibilityViewIsModal = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Shows `message` with an optional action; gone after `duration` seconds.
    func show(_ message: String, actionTitle: String? = nil, duration: TimeInterval = 7, action: (() -> Void)? = nil) {
        hideTask?.cancel()
        label.text = message
        self.action = action
        actionButton.configuration?.title = actionTitle
        actionButton.isHidden = actionTitle == nil
        isHidden = false
        UIView.animate(springDuration: 0.4, bounce: 0.15) { self.alpha = 1 }
        UIAccessibility.post(notification: .announcement, argument: message)
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    func hide() {
        hideTask?.cancel()
        action = nil
        UIView.animate(withDuration: 0.25, animations: { self.alpha = 0 }, completion: { _ in
            if self.alpha == 0 { self.isHidden = true }
        })
    }

    private func perform() {
        let action = action
        hide()
        action?()
    }
}
