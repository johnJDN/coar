import SwiftUI

/// A Night's stages (DESIGN.md §8): one bar split by time in each stage, in sleep's teal at
/// falling strengths (deep strongest) with awake in `textTertiary`, then a row per stage with
/// its time and share. A SwiftUI leaf: values in, nothing out (ADR 0001).
struct SleepStagesView: View {

    let stages: [SleepStage: TimeInterval]

    static func color(_ stage: SleepStage) -> Color {
        switch stage {
        case .awake: return Color.textTertiary
        case .rem: return Color.accentTeal.opacity(0.4)
        case .core: return Color.accentTeal.opacity(0.7)
        case .deep: return Color.accentTeal
        }
    }

    private var total: TimeInterval {
        stages.values.reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spaceInner) {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(SleepStage.allCases.reversed(), id: \.self) { stage in
                        if let seconds = stages[stage], seconds > 0, total > 0 {
                            Capsule()
                                .fill(Self.color(stage))
                                .frame(width: max(4, (geometry.size.width - 6) * seconds / total))
                        }
                    }
                }
            }
            .frame(height: 10)

            VStack(spacing: Metrics.spaceTight) {
                ForEach(SleepStage.allCases, id: \.self) { stage in
                    HStack(spacing: Metrics.spaceTight) {
                        Circle().fill(Self.color(stage)).frame(width: 8, height: 8)
                        Text(stage.title).foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text(HealthText.duration(stages[stage] ?? 0))
                            .foregroundStyle(Color.textPrimary)
                            .monospacedDigit()
                        Text(total > 0 ? "\(Int(((stages[stage] ?? 0) / total * 100).rounded()))%" : "")
                            .foregroundStyle(Color.textSecondary)
                            .monospacedDigit()
                            .frame(minWidth: 40, alignment: .trailing)
                    }
                    .font(Font.label)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SleepStage.allCases.map { "\($0.title) \(HealthText.duration(stages[$0] ?? 0))" }.joined(separator: ", "))
    }
}

#Preview {
    SleepStagesView(stages: [.awake: 900, .rem: 5_400, .core: 13_800, .deep: 4_200])
        .padding()
        .background(Color.surface)
}
