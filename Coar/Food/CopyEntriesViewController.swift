import SwiftUI
import UIKit
import os

/// Copy to… (`.scratch/food-logging/issues/03`; ADR 0001: SwiftUI leaf, values in, closures
/// out): the Day and time the selected Entries are copied to, or each at its own time of day.
struct CopyEntriesForm: View {

    let count: Int
    @State var day: Date
    @State var time: Date
    @State var keepTimes = false
    let onCopy: (Date, Bool) -> Void

    var body: some View {
        Form {
            Section {
                DatePicker("Day", selection: $day, displayedComponents: .date)
                    .foregroundStyle(Color.textPrimary)
                    .formRow()
                Toggle("Keep their own times", isOn: $keepTimes)
                    .foregroundStyle(Color.textPrimary)
                    .tint(Color.accentGreen)
                    .formRow()
                if !keepTimes {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .foregroundStyle(Color.textPrimary)
                        .formRow()
                }
            } footer: {
                Text(keepTimes ? "Each copy at the time of day its original was logged." : "Every copy at this time.")
            }
            Section {
                Button(count == 1 ? "Copy 1 entry" : "Copy \(count) entries") {
                    onCopy(Self.instant(day: day, time: time), keepTimes)
                }
                .foregroundStyle(Color.accentGreen)
                .formRow()
            }
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .background(Color.background)
    }

    /// The Day's date at the time's hour and minute.
    static func instant(day: Date, time: Date, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: parts.hour ?? 12, minute: parts.minute ?? 0, second: 0, of: day) ?? day
    }
}

/// The Copy to… sheet over the Food tab's selection.
final class CopyEntriesViewController: UIHostingController<CopyEntriesForm> {

    private static let logger = Logger(category: "Food")

    init(store: Store, entries: [EntryRecord], day: Day, onCopied: @escaping (Day, Int) -> Void) {
        let now = Date()
        super.init(rootView: CopyEntriesForm(count: entries.count, day: day.start(), time: now) { _, _ in })
        rootView = CopyEntriesForm(count: entries.count, day: day.start(), time: now) { [weak self] instant, keepTimes in
            do {
                let copies = try store.copyEntries(entries, to: instant, keepingTimes: keepTimes)
                self?.dismiss(animated: true)
                onCopied(Day(instant), copies.count)
            } catch {
                Self.logger.error("Failed to copy Entries: \(error, privacy: .public)")
            }
        }
        title = "Copy to"
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
    }
}
