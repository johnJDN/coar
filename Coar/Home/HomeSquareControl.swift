import UIKit

/// A Home square (DESIGN.md §11): a `Card` with an icon and title, one hero value for
/// today, and a caption; the empty form in the value slot when there is nothing (§1.5). The
/// square is a control: tapping it opens the screen behind it. A Health square can also let
/// the empty value slot show the Apple Health prompt (spec story 80). Wrapped as a control
/// the way the Train root's cards are.
final class HomeSquareControl: CardControl {

    /// Runs when the empty value slot is tapped while the square `connects`.
    var onTapEmpty: (() -> Void)?

    private let title: String
    private let emptyText: String
    private let emptyActionName: String?
    private let heroLabel = HeroNumberLabel()
    private let captionLabel = UILabel()

    /// `emptyText` is what the value slot shows with no value (`—`, or `No data` for a
    /// Health square); `emptyActionName` names the VoiceOver action for tapping it.
    init(title: String, systemImage: String, iconTint: UIColor, emptyText: String = "—", emptyActionName: String? = nil) {
        self.title = title
        self.emptyText = emptyText
        self.emptyActionName = emptyActionName
        super.init(card: CardView(title: title, systemImage: systemImage, iconTint: iconTint, accessory: .navigates), interactiveContent: true)

        heroLabel.adjustsFontSizeToFitWidth = true
        heroLabel.minimumScaleFactor = 0.5

        captionLabel.font = UIFont.label
        captionLabel.textColor = UIColor.textSecondary
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.numberOfLines = 2

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        card.contentStack.addArrangedSubview(spacer)
        card.contentStack.addArrangedSubview(heroLabel)
        card.contentStack.addArrangedSubview(captionLabel)
        heightAnchor.constraint(equalTo: widthAnchor).isActive = true

        isAccessibilityElement = true
        render(HomeSquare(value: nil, caption: ""))
    }

    func render(_ square: HomeSquare) {
        heroLabel.setValue(square.value ?? emptyText, isEmpty: square.value == nil)
        heroLabel.onTapEmpty = square.connects ? { [weak self] in self?.onTapEmpty?() } : nil
        captionLabel.text = square.caption

        accessibilityLabel = "\(title), \(square.value ?? emptyText), \(square.caption)"
        if square.connects, let emptyActionName {
            accessibilityCustomActions = [UIAccessibilityCustomAction(name: emptyActionName) { [weak self] _ in self?.onTapEmpty?(); return true }]
        } else {
            accessibilityCustomActions = []
        }
    }
}

extension HomeSquareControl {
    /// The Sleep or Steps square: `No data` in the slot, with the Apple Health prompt
    /// offered from it while the prompt has never been shown.
    convenience init(metric: HealthMetric) {
        self.init(title: metric.title, systemImage: metric.systemImage, iconTint: metric.uiAccent, emptyText: "No data", emptyActionName: "Connect Apple Health")
    }
}
