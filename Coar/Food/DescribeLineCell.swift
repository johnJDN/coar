import UIKit

/// One Describe line (spec "Describing"), Reminders-style: a single-line field to type one
/// food into and, under it, the line's Estimate or state. Return asks for a new line below;
/// backspace in an empty field asks to remove the line. The field keeps its text and caret
/// across reconfigures: it is only overwritten when the line's text differs from what it shows.
/// A filled line that isn't already one of the user's foods has a Save to Foods toggle under
/// its Estimate, on by default, so it needn't be opened to change it.
final class DescribeLineCell: UICollectionViewListCell {

    struct Actions {
        var onEdit: (String) -> Void = { _ in }
        var onReturn: () -> Void = {}
        var onDeleteEmpty: () -> Void = {}
        var onEndEditing: () -> Void = {}
        var onSaveAsFood: (Bool) -> Void = { _ in }
    }

    private let field = LineTextField()
    private let caption = UILabel()
    private let saveButton = UIButton(type: .system)
    private let below = UIStackView()
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

        var save = UIButton.Configuration.plain()
        save.title = "Save to Foods"
        save.imagePadding = 6
        save.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 2, trailing: 8)
        save.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .footnote)
        save.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.label
            return attributes
        }
        saveButton.configuration = save
        saveButton.changesSelectionAsPrimaryAction = true
        saveButton.configurationUpdateHandler = { button in
            button.configuration?.image = UIImage(systemName: button.isSelected ? "checkmark.circle.fill" : "circle")
            button.configuration?.baseForegroundColor = button.isSelected ? UIColor.accentGreen : UIColor.textSecondary
        }
        saveButton.accessibilityTraits.insert(.toggleButton)
        saveButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            actions.onSaveAsFood(saveButton.isSelected)
        }, for: .primaryActionTriggered)

        below.axis = .vertical
        below.alignment = .leading
        below.spacing = 2
        below.addArrangedSubview(caption)
        below.addArrangedSubview(saveButton)

        for view in [field, below] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
        }
        captionGap = below.topAnchor.constraint(equalTo: field.bottomAnchor)
        let margins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: margins.topAnchor),
            field.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            field.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            field.heightAnchor.constraint(greaterThanOrEqualToConstant: 28),
            captionGap,
            below.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            below.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            below.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
            caption.widthAnchor.constraint(equalTo: below.widthAnchor),
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
        caption.isHidden = text == nil
        captionGap.constant = text == nil ? 0 : 4
        let offersSave = Self.offersSaveAsFood(line)
        if saveButton.isHidden == offersSave { saveButton.isHidden = !offersSave }
        saveButton.isSelected = line.saveAsFood
    }

    func focus() {
        field.becomeFirstResponder()
    }

    var isEditingText: Bool {
        field.isFirstResponder
    }

    /// The toggle shows on a filled line that isn't already one of the user's foods or meals.
    static func offersSaveAsFood(_ line: DescribeLine) -> Bool {
        guard let estimate = line.estimate else { return false }
        return estimate.match == nil
    }

    // MARK: - Caption

    /// What sits under the typed text: nothing while typing; a state while one is pending;
    /// the Estimate as a macro line over "name · portion · source"; or the failure in coral.
    static func caption(for line: DescribeLine) -> NSAttributedString? {
        switch line.state {
        case .typing:
            return line.isPhoto ? plain("Waiting to be read.", color: UIColor.textTertiary) : nil
        case .checking:
            return plain(line.isPhoto ? "Reading photo…" : "Checking…", color: UIColor.textTertiary)
        case .waiting:
            return withSymbol("wifi.slash", "Waiting for connection.", color: UIColor.textSecondary)
        case .failed(let reason):
            let sentence = reason.last.map { ".!?".contains($0) } == true ? reason : reason + "."
            return withSymbol("exclamationmark.triangle.fill", "\(sentence) Tap to try again or type it in.", color: UIColor.accentCoral, textColor: UIColor.textPrimary)
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
