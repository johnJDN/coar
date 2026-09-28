import UIKit

/// One Describe line (spec "Describing"), Reminders-style: a single-line field to type one
/// food into and, under it, the line's Estimate or state. Return asks for a new line below;
/// backspace in an empty field asks to remove the line. The field keeps its text and caret
/// across reconfigures: it is only overwritten when the line's text differs from what it shows.
final class DescribeLineCell: UICollectionViewListCell {

    struct Actions {
        var onEdit: (String) -> Void = { _ in }
        var onReturn: () -> Void = {}
        var onDeleteEmpty: () -> Void = {}
        var onEndEditing: () -> Void = {}
    }

    private let field = LineTextField()
    private let caption = UILabel()
    private var captionGap: NSLayoutConstraint!
    private var actions = Actions()

    override init(frame: CGRect) {
        super.init(frame: frame)
        field.font = UIFont.cardTitle
        field.textColor = UIColor.textPrimary
        field.returnKeyType = .next
        field.autocapitalizationType = .none
        field.clearButtonMode = .never
        field.delegate = self
        field.addAction(UIAction { [weak self] _ in self?.actions.onEdit(self?.field.text ?? "") }, for: .editingChanged)
        field.addAction(UIAction { [weak self] _ in self?.actions.onEndEditing() }, for: .editingDidEnd)
        field.onDeleteBackwardWhenEmpty = { [weak self] in self?.actions.onDeleteEmpty() }

        caption.numberOfLines = 0
        caption.font = UIFont.label
        // The macro line's numbers take the label's colour; its P / F / C letters their accents.
        caption.textColor = UIColor.textSecondary
        caption.adjustsFontForContentSizeCategory = true

        for view in [field, caption] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
        }
        captionGap = caption.topAnchor.constraint(equalTo: field.bottomAnchor)
        let margins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: margins.topAnchor),
            field.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            field.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            field.heightAnchor.constraint(greaterThanOrEqualToConstant: 28),
            captionGap,
            caption.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            caption.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            caption.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
        ])
        backgroundConfiguration = UIBackgroundConfiguration.listCell()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(_ line: DescribeLine, placeholder: String, actions: Actions) {
        self.actions = actions
        if field.text != line.text {
            field.text = line.text
        }
        field.placeholder = placeholder
        field.accessibilityLabel = "Food"
        let text = Self.caption(for: line)
        caption.attributedText = text
        captionGap.constant = text == nil ? 0 : 4
    }

    func focus() {
        field.becomeFirstResponder()
    }

    var isEditingText: Bool {
        field.isFirstResponder
    }

    // MARK: - Caption

    /// What sits under the typed text: nothing while typing; a state while one is pending;
    /// the Estimate as a macro line over "name · portion · source"; or the failure in coral.
    static func caption(for line: DescribeLine) -> NSAttributedString? {
        switch line.state {
        case .typing:
            return nil
        case .checking:
            return plain("Checking…", color: UIColor.textTertiary)
        case .waiting:
            return withSymbol("wifi.slash", "Waiting for connection. Tap to try again.", color: UIColor.textSecondary)
        case .failed(let reason):
            let sentence = reason.last.map { ".!?".contains($0) } == true ? reason : reason + "."
            return withSymbol("exclamationmark.triangle.fill", "\(sentence) Tap to try again.", color: UIColor.accentCoral, textColor: UIColor.textPrimary)
        case .filled(let estimate):
            let text = NSMutableAttributedString(attributedString: FoodText.styledMacroLineUIKit(estimate.macros))
            text.append(plain("\n\([estimate.name, estimate.portion, estimate.source.title].joined(separator: " · "))", color: UIColor.textSecondary))
            if estimate.caloriesDisagree {
                text.append(NSAttributedString(string: "\n"))
                text.append(withSymbol("exclamationmark.triangle.fill", "Calories don't match the macros. Check before adding.", color: UIColor.accentCoral, textColor: UIColor.textSecondary))
            }
            return text
        }
    }

    private static func plain(_ string: String, color: UIColor) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.font: UIFont.label, .foregroundColor: color])
    }

    private static func withSymbol(_ symbol: String, _ string: String, color: UIColor, textColor: UIColor? = nil) -> NSAttributedString {
        let text = NSMutableAttributedString()
        if let image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(font: UIFont.label))?.withTintColor(color, renderingMode: .alwaysOriginal) {
            text.append(NSAttributedString(attachment: NSTextAttachment(image: image)))
            text.append(NSAttributedString(string: " "))
        }
        text.append(plain(string, color: textColor ?? color))
        return text
    }
}

extension DescribeLineCell: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        actions.onReturn()
        return false
    }
}

/// A text field that reports backspace pressed while it is already empty.
private final class LineTextField: UITextField {
    var onDeleteBackwardWhenEmpty: (() -> Void)?

    override func deleteBackward() {
        let wasEmpty = text?.isEmpty ?? true
        super.deleteBackward()
        if wasEmpty { onDeleteBackwardWhenEmpty?() }
    }
}
