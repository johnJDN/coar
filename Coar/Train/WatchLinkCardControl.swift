import UIKit

/// The Apple Watch card at the top of a finished Workout (DESIGN.md §7 `Card` with a
/// trailing `→`; `.scratch/watch-link/`): the Health Workout it is linked to as its effort
/// ("320 cal · 118 bpm") over what it was; or, unlinked, an invitation to link one, with the
/// Health Workout that overlaps it offered in one tap when there is exactly one. Tapping the
/// card opens the list of Health Workouts for the Day; the inline button links the offered
/// one. The owner reads Health and keeps the link; the card only shows what it is given.
final class WatchLinkCardControl: CardControl {

    enum Content: Equatable {
        /// Health has not answered yet.
        case loading
        case unlinked(suggestion: HealthWorkout?)
        case linked(HealthWorkout)
        /// Linked, but Health does not hold that workout now (deleted, or not readable).
        case linkedMissing
    }

    /// Runs when the inline button links the offered Health Workout.
    var onLink: ((HealthWorkout) -> Void)?

    private let valueLabel = UILabel()
    private let captionLabel = UILabel()
    private var offered: HealthWorkout?
    private lazy var linkButton = UIButton.inCardAction(title: "Link", systemImage: "link") { [weak self] in
        if let offered = self?.offered { self?.onLink?(offered) }
    }

    init() {
        super.init(card: CardView(title: "Apple Watch", systemImage: "applewatch", iconTint: UIColor.accentGreen, accessory: .navigates), interactiveContent: true)

        valueLabel.font = UIFont.metricNumber
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.6
        captionLabel.font = UIFont.label
        captionLabel.textColor = UIColor.textSecondary
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.numberOfLines = 0

        let actions = UIStackView(arrangedSubviews: [linkButton, UIView()])
        actions.axis = .horizontal
        card.contentStack.addArrangedSubview(valueLabel)
        card.contentStack.addArrangedSubview(captionLabel)
        card.contentStack.addArrangedSubview(actions)
        card.contentStack.setCustomSpacing(Metrics.spaceInner, after: captionLabel)
        isAccessibilityElement = false
        render(.loading)
    }

    func render(_ content: Content) {
        offered = nil
        var value: String?
        let caption: String
        switch content {
        case .loading:
            caption = "Checking Apple Health…"
        case .unlinked(let suggestion):
            offered = suggestion
            if let suggestion {
                value = suggestion.effortText
                caption = "\(Self.what(suggestion)). Link it to keep its effort with this workout."
            } else {
                caption = "Link a workout your Watch recorded to see its calories and heart rate here."
            }
        case .linked(let healthWorkout):
            value = healthWorkout.effortText
            caption = value == nil ? "\(Self.what(healthWorkout)). Apple Health has no calories or heart rate for it." : "\(Self.what(healthWorkout)), from Apple Health."
        case .linkedMissing:
            caption = "The linked workout isn't in Apple Health right now."
        }
        valueLabel.text = value ?? "—"
        valueLabel.textColor = value == nil ? UIColor.textTertiary : UIColor.textPrimary
        captionLabel.text = caption
        linkButton.superview?.isHidden = offered == nil
        if let offered, let effort = offered.effortText {
            linkButton.configuration?.title = "Link \(effort.components(separatedBy: " · ")[0])"
        } else {
            linkButton.configuration?.title = "Link"
        }
        accessibilityLabel = "Apple Watch, \(value ?? "no effort"), \(caption)"
        accessibilityHint = "Chooses the Watch workout to link"
        isAccessibilityElement = true
    }

    /// "Strength training · 5:12 PM · 48 min".
    private static func what(_ healthWorkout: HealthWorkout) -> String {
        [healthWorkout.name, TrainText.timeText(healthWorkout.start), TrainText.duration(from: healthWorkout.start, to: healthWorkout.end)].joined(separator: " · ")
    }
}
