import SwiftUI
import UIKit

/// Home's macros card (DESIGN.md §8, §11): a full-width `Card` with today's four macros
/// against the Target in force, each a `DotMatrix` in its fixed accent under its value.
/// Calories is the card's one hero number; protein, fat, and carbs are metric numbers in
/// their accents. With no Target the numbers stay, the captions read `— target`, there are
/// no dot rows, and a Set targets action opens Settings (`.scratch/data-model/issues/02`).
/// Tapping the card opens Food on today.
final class MacrosCardControl: UIControl {

    var onSetTargets: (() -> Void)?

    private let card = CardView(title: "Macros", systemImage: "fork.knife", accessory: .navigates)
    private let rows = Macro.allCases.map(MacroRowView.init)
    private lazy var setTargets = UIButton.inCardAction(title: "Set targets", systemImage: "target") { [weak self] in self?.onSetTargets?() }

    init() {
        super.init(frame: .zero)

        for row in rows {
            card.contentStack.addArrangedSubview(row)
            card.contentStack.setCustomSpacing(Metrics.spaceInner, after: row)
        }
        let actions = UIStackView(arrangedSubviews: [setTargets, UIView()])
        actions.axis = .horizontal
        card.contentStack.addArrangedSubview(actions)
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        accessibilityTraits = .button
        render(rows: HomeSnapshot.empty.macros, hasTarget: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func render(rows models: [HomeSnapshot.MacroRow], hasTarget: Bool) {
        for (row, model) in zip(rows, models) {
            row.configure(with: model, animated: window != nil)
        }
        setTargets.superview?.isHidden = hasTarget
    }

    override var isHighlighted: Bool {
        didSet { card.alpha = isHighlighted ? 0.85 : 1 }
    }
}

/// One macro on the card: `[icon] Protein`, the value with its target caption on one
/// baseline, then the `DotMatrix` (hidden without a Target).
private final class MacroRowView: UIView {

    private let macro: Macro
    private let valueLabel = UILabel()
    private let captionLabel = UILabel()
    private let dotsView: UIView & UIContentView

    init(macro: Macro) {
        self.macro = macro
        dotsView = Self.dotsConfiguration(.init(total: 0, filled: 0, columns: 1, accent: macro.accent)).makeContentView()
        super.init(frame: .zero)

        let icon = UIImageView(image: UIImage(systemName: macro.systemImage))
        icon.tintColor = macro.uiAccent
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote)
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let title = UILabel()
        title.text = macro.title
        title.font = UIFont.label
        title.textColor = UIColor.textSecondary
        title.adjustsFontForContentSizeCategory = true
        let header = UIStackView(arrangedSubviews: [icon, title])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = Metrics.spaceTight / 2

        // Calories is the card's hero (DESIGN.md §10); the others are metric numbers in their accent (§5).
        valueLabel.font = macro == .calories ? UIFont.heroNumber : UIFont.metricNumber
        valueLabel.textColor = macro == .calories ? UIColor.textPrimary : macro.uiAccent
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        captionLabel.font = UIFont.label
        captionLabel.textColor = UIColor.textSecondary
        captionLabel.adjustsFontForContentSizeCategory = true
        let value = UIStackView(arrangedSubviews: [valueLabel, captionLabel])
        value.axis = .horizontal
        value.alignment = .firstBaseline
        value.spacing = Metrics.spaceTight

        let stack = UIStackView(arrangedSubviews: [header, value, dotsView])
        stack.axis = .vertical
        stack.spacing = Metrics.spaceTight / 2
        stack.setCustomSpacing(Metrics.spaceTight, after: value)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        isAccessibilityElement = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// The number cross-dissolves (DESIGN.md §9) when a change lands on screen.
    func configure(with model: HomeSnapshot.MacroRow, animated: Bool) {
        if animated, valueLabel.text != model.consumed {
            UIView.transition(with: valueLabel, duration: 0.25, options: .transitionCrossDissolve) { self.valueLabel.text = model.consumed }
        } else {
            valueLabel.text = model.consumed
        }
        captionLabel.text = model.targetCaption
        captionLabel.textColor = model.dots == nil ? UIColor.textTertiary : UIColor.textSecondary
        if let dots = model.dots {
            dotsView.configuration = Self.dotsConfiguration(.init(total: dots.total, filled: dots.filled, columns: dots.columns, accent: macro.accent))
        }
        dotsView.isHidden = model.dots == nil
        accessibilityLabel = model.dots == nil
            ? "\(macro.title), \(model.consumed) \(macro.unit), no target"
            : "\(macro.title), \(model.consumed) \(model.targetCaption)"
    }

    private static func dotsConfiguration(_ model: DotMatrix.Model) -> UIHostingConfiguration<DotMatrix, EmptyView> {
        UIHostingConfiguration { DotMatrix(model: model) }.margins(.all, 0)
    }
}
