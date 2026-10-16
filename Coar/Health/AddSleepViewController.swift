import SwiftUI
import UIKit
import os

/// Writes sleep to Apple Health (`.scratch/health-pages/issues/04`): a nap, or sleep the Watch
/// missed. Asks for Health's permission to write sleep the first time. Faked in tests.
protocol SleepWriter: AnyObject {
    /// Saves a span as "Asleep" in Apple Health.
    func addSleep(from start: Date, to end: Date) async throws
}

/// The Add sleep sheet's content (ADR 0001: SwiftUI leaf, values in, closures out): when it
/// started and ended, how long that is, and where it lands.
struct AddSleepForm: View {

    @State var start: Date
    @State var end: Date
    let onSave: (Date, Date) -> Void

    /// Saveable: it ends after it starts, by at most 16 hours, and not in the future.
    static func isValid(start: Date, end: Date, now: Date = Date()) -> Bool {
        end > start && end.timeIntervalSince(start) <= 16 * 3_600 && end <= now.addingTimeInterval(60)
    }

    var body: some View {
        Form {
            Section {
                DatePicker("Fell asleep", selection: $start, in: ...Date())
                    .foregroundStyle(Color.textPrimary)
                    .formRow()
                DatePicker("Woke up", selection: $end, in: ...Date())
                    .foregroundStyle(Color.textPrimary)
                    .formRow()
                HStack {
                    Text("Asleep").foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(end > start ? HealthText.duration(end.timeIntervalSince(start)) : "—")
                        .font(Font.metricNumber)
                        .foregroundStyle(Self.isValid(start: start, end: end) ? Color.accentTeal : Color.textTertiary)
                }
                .formRow()
            } footer: {
                Text("Saved to Apple Health as Asleep, so both apps agree. It counts toward the night that ends on its Day (6 PM to 6 PM); a nap more than an hour after waking doesn't move your wake time.")
            }
            Section {
                Button("Add to Apple Health") { onSave(start, end) }
                    .disabled(!Self.isValid(start: start, end: end))
                    .formRow()
            }
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .background(Color.background)
    }
}

/// The Add sleep sheet, from the Sleep page.
final class AddSleepViewController: UIHostingController<AddSleepForm> {

    private static let logger = Logger(category: "Health")

    private let writer: SleepWriter
    private let onSaved: () -> Void

    init(writer: SleepWriter, onSaved: @escaping () -> Void) {
        self.writer = writer
        self.onSaved = onSaved
        // An hour ending now, on the quarter hour.
        let now = Date()
        let quarter = Date(timeIntervalSinceReferenceDate: (now.timeIntervalSinceReferenceDate / 900).rounded(.down) * 900)
        super.init(rootView: AddSleepForm(start: quarter.addingTimeInterval(-3_600), end: quarter, onSave: { _, _ in }))
        rootView = AddSleepForm(start: quarter.addingTimeInterval(-3_600), end: quarter) { [weak self] in self?.save(from: $0, to: $1) }
        title = "Add Sleep"
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    static func sheet(writer: SleepWriter, onSaved: @escaping () -> Void) -> UIViewController {
        AddSleepViewController(writer: writer, onSaved: onSaved).inSheet(detents: [.medium(), .large()])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
    }

    private func save(from start: Date, to end: Date) {
        Task {
            do {
                try await writer.addSleep(from: start, to: end)
                onSaved()
                dismiss(animated: true)
            } catch {
                Self.logger.error("Failed to add sleep to Apple Health: \(error, privacy: .public)")
                let alert = UIAlertController(title: "Couldn't add sleep", message: "Coar may not be allowed to write sleep. Check Coar's access in the Health app (Sleep → Data Sources & Access).", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }
}
