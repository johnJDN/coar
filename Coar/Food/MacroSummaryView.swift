import UIKit

/// The Food tab's summary row (DESIGN.md §8): four columns, one per macro, each a small
/// title, "consumed / target", and a thin bar in the macro's accent over a `fill` track
/// (the row sits on `background`, where a `surfaceSunken` track all but vanishes in dark). Without a Target the slot reads `—` and the track stays empty (§1.5); the row
/// never collapses.
final class MacroSummaryView: UIView {

    private let columns: [Column]

    override init(frame: CGRect) {
        columns = Macro.allCases.map(Column.init)
        super.init(frame: frame)
        let row = UIStackView(arrangedSubviews: columns)
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = Metrics.spaceTight
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: Metrics.spaceTight),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.spaceEdge),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Metrics.spaceEdge),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Metrics.spaceCard),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(with summary: MacroSummary) {
        for (column, bar) in zip(columns, summary.bars) {
            column.configure(with: bar, animated: window != nil)
        }
    }

    /// One macro: title, "1,240 / 2,100", bar.
    private final class Column: UIView {

        private let macro: Macro
        private let titleLabel = UILabel()
        private let valueLabel = UILabel()
        private let bar: ThinBarView

        init(macro: Macro) {
            self.macro = macro
            bar = ThinBarView(accent: macro.uiAccent)
            super.init(frame: .zero)

            titleLabel.text = macro.title
            titleLabel.font = UIFont.label
            titleLabel.textColor = UIColor.textSecondary
            titleLabel.adjustsFontForContentSizeCategory = true

            valueLabel.font = UIFont.label
            valueLabel.adjustsFontForContentSizeCategory = true
            valueLabel.adjustsFontSizeToFitWidth = true
            valueLabel.minimumScaleFactor = 0.7

            let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel, bar])
            stack.axis = .vertical
            stack.spacing = 4
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

        /// Numbers cross-dissolve and the bar springs (DESIGN.md §9) when a change lands on
        /// screen; both are set plainly on first display.
        func configure(with model: MacroSummary.Bar, animated: Bool) {
            let text = NSMutableAttributedString(string: model.consumed, attributes: [.foregroundColor: UIColor.textPrimary])
            text.append(NSAttributedString(string: " / \(model.target)", attributes: [.foregroundColor: model.fraction == nil ? UIColor.textTertiary : UIColor.textSecondary]))
            if animated, valueLabel.attributedText?.string != text.string {
                UIView.transition(with: valueLabel, duration: 0.2, options: .transitionCrossDissolve) { self.valueLabel.attributedText = text }
            } else {
                valueLabel.attributedText = text
            }
            bar.setFraction(model.fraction ?? 0, animated: animated)
            let unit = macro.unit
            accessibilityLabel = model.fraction == nil
                ? "\(macro.title), \(model.consumed) \(unit), no target"
                : "\(macro.title), \(model.consumed) of \(model.target) \(unit)"
        }
    }
}

/// A 4pt bar: `fill` track, accent fill from the leading edge by a fraction of the
/// width, moved with the §9 layout spring.
final class ThinBarView: UIView {

    static let height: CGFloat = 4

    private let fill = UIView()
    private var fraction: CGFloat = 0

    init(accent: UIColor) {
        super.init(frame: .zero)
        backgroundColor = UIColor.fill
        layer.cornerRadius = Self.height / 2
        clipsToBounds = true
        fill.backgroundColor = accent
        fill.layer.cornerRadius = Self.height / 2
        addSubview(fill)
        heightAnchor.constraint(equalToConstant: Self.height).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        fill.frame = CGRect(x: 0, y: 0, width: bounds.width * fraction, height: bounds.height)
    }

    func setFraction(_ value: Double, animated: Bool) {
        fraction = CGFloat(min(max(value, 0), 1))
        setNeedsLayout()
        guard animated else { return layoutIfNeeded() }
        UIView.animate(springDuration: 0.5, bounce: 0) { self.layoutIfNeeded() }
    }
}
