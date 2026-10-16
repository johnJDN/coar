import SwiftUI
import UIKit

/// The mood and energy check-in (`.scratch/day-page/issues/03`; ADR 0001: SwiftUI leaf, values
/// in, closures out): mood as five faces, the picked one full and the rest dimmed; energy as
/// five bolts filled up to the pick. Each tap reports at once; the owner saves.
struct MoodEnergyView: View {

    static let faces = ["😫", "😕", "😐", "🙂", "😄"]
    static let moodWords = ["Awful", "Low", "Okay", "Good", "Great"]
    static let energyWords = ["Drained", "Tired", "Steady", "Energetic", "Wired"]

    let mood: Int?
    let energy: Int?
    let onMood: (Int) -> Void
    let onEnergy: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spaceInner) {
            row(title: "Mood", word: mood.map { Self.moodWords[$0 - 1] }) {
                ForEach(1...5, id: \.self) { value in
                    Button { onMood(value) } label: {
                        Text(Self.faces[value - 1])
                            .font(.title2)
                            .opacity(mood == nil || mood == value ? 1 : 0.35)
                            .scaleEffect(mood == value ? 1.15 : 1)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Mood \(Self.moodWords[value - 1])")
                    .accessibilityAddTraits(mood == value ? .isSelected : [])
                }
            }
            row(title: "Energy", word: energy.map { Self.energyWords[$0 - 1] }) {
                ForEach(1...5, id: \.self) { value in
                    Button { onEnergy(value) } label: {
                        Image(systemName: value <= (energy ?? 0) ? "bolt.fill" : "bolt")
                            .font(.title3)
                            .foregroundStyle(value <= (energy ?? 0) ? Color.accentAmber : Color.textTertiary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Energy \(Self.energyWords[value - 1])")
                    .accessibilityAddTraits(energy == value ? .isSelected : [])
                }
            }
        }
        .sensoryFeedback(.selection, trigger: mood)
        .sensoryFeedback(.selection, trigger: energy)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: mood)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: energy)
    }

    private func row<Content: View>(title: String, word: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(Font.label).foregroundStyle(Color.textSecondary)
                Spacer()
                Text(word ?? "").font(Font.label).foregroundStyle(Color.textTertiary)
            }
            HStack(spacing: 0) { content() }
        }
    }
}

/// Home's check-in card, "How's today?", until both are set for today; tapping a face or a
/// bolt saves at once.
final class MoodCardView: UIView {

    var onMood: ((Int) -> Void)?
    var onEnergy: ((Int) -> Void)?

    private let card = CardView(title: "How's today?", systemImage: "face.smiling", iconTint: UIColor.accentAmber)
    private var content: (UIView & UIContentView)?

    init() {
        super.init(frame: .zero)
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        render(nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func render(_ record: MoodRecord?) {
        let configuration = UIHostingConfiguration {
            MoodEnergyView(mood: record?.mood, energy: record?.energy,
                           onMood: { [weak self] in self?.onMood?($0) },
                           onEnergy: { [weak self] in self?.onEnergy?($0) })
        }
        .margins(.all, 0)
        if let content {
            content.configuration = configuration
        } else {
            let view = configuration.makeContentView()
            card.contentStack.addArrangedSubview(view)
            content = view
        }
    }
}
