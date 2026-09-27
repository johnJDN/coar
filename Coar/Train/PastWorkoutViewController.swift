import SwiftUI
import UIKit
import os

/// Hosts `PastWorkoutForm` (ADR 0001). Creating follows DESIGN.md §7a: Add saves, Cancel
/// asks before losing what was filled in. Editing an Activity or moving a past Workout saves
/// as it changes, with Done.
final class PastWorkoutViewController: UIHostingController<PastWorkoutForm> {

    enum Purpose {
        /// A new past Workout; `day` pre-picks the Day (a tap on the month grid).
        case create(day: Day?)
        case editActivity(WorkoutRecord)
        case editTime(WorkoutRecord)
    }

    private static let logger = Logger(category: "Train")

    private let dependencies: AppDependencies
    private let purpose: Purpose
    /// Creating only: runs after Add with the new Workout, once the sheet is down.
    private let onCreated: (WorkoutRecord) -> Void
    /// Editing only: runs after each save.
    private let onChange: () -> Void
    private let initial: PastWorkoutForm.Draft
    private var draft: PastWorkoutForm.Draft
    private let addItem = UIBarButtonItem(title: "Add")
    private var discardGuard: SheetDiscardGuard?
    private lazy var autosaver = Autosaver { [weak self] in self?.saveEdit() }

    init(dependencies: AppDependencies, purpose: Purpose, onCreated: @escaping (WorkoutRecord) -> Void = { _ in }, onChange: @escaping () -> Void = {}) {
        self.dependencies = dependencies
        self.purpose = purpose
        self.onCreated = onCreated
        self.onChange = onChange
        let unit = DistanceUnit(dependencies.preferences.massUnit)
        var plans: [PastWorkoutForm.PlanOption] = []
        var names: [String] = []
        do {
            plans = try dependencies.store.plans().map { .init(id: $0.id, name: $0.name) }
            names = try dependencies.store.activityNames()
        } catch {
            Self.logger.error("Failed to read for Log past workout: \(error, privacy: .public)")
        }
        var draft = Self.initialDraft(for: purpose, unit: unit)
        // A new strength Workout starts from the most recently used Plan: the usual case is
        // "I did Push but forgot to start it".
        if case .create = purpose {
            draft.planID = plans.first?.id
        }
        initial = draft
        self.draft = draft
        super.init(rootView: PastWorkoutForm(draft: draft, mode: .create, distanceSymbol: unit.symbol) { _ in })

        let mode: PastWorkoutForm.Mode
        switch purpose {
        case .create:
            mode = .create
            title = "Log Past Workout"
            navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
                self?.discardGuard?.cancel()
            })
            addItem.primaryAction = UIAction(title: "Add") { [weak self] _ in self?.add() }
            addItem.style = .prominent
            navigationItem.rightBarButtonItem = addItem
            discardGuard = SheetDiscardGuard(controller: self, title: "Discard this workout?") { [weak self] in
                guard let self else { return false }
                return self.draft != initial
            }
        case .editActivity:
            mode = .editActivity
            title = "Edit Activity"
        case .editTime:
            mode = .editTime
            title = "Date and Time"
        }
        if case .create = purpose {} else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            })
        }

        rootView = PastWorkoutForm(draft: draft, mode: mode, plans: plans, activityNames: Array(names.prefix(8)), distanceSymbol: unit.symbol) { [weak self] in
            self?.draftChanged($0)
        }
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        discardGuard?.refresh()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if case .create = purpose { return }
        autosaver.flush()
    }

    static func sheet(dependencies: AppDependencies, purpose: Purpose, onCreated: @escaping (WorkoutRecord) -> Void = { _ in }, onChange: @escaping () -> Void = {}) -> UIViewController {
        PastWorkoutViewController(dependencies: dependencies, purpose: purpose, onCreated: onCreated, onChange: onChange)
            .inSheet(detents: [.large()])
    }

    // MARK: - Draft

    /// A new one starts an hour before now today, or at 6 PM on an earlier Day; an existing
    /// one starts as it stands.
    private static func initialDraft(for purpose: Purpose, unit: DistanceUnit) -> PastWorkoutForm.Draft {
        switch purpose {
        case .create(let day):
            let now = Date()
            let calendar = Calendar.current
            let startedAt: Date
            if let day, day < Day.today() {
                startedAt = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day.start(in: calendar)) ?? now
            } else {
                startedAt = now.addingTimeInterval(-3_600)
            }
            return .init(startedAt: startedAt)
        case .editActivity(let workout), .editTime(let workout):
            return .init(
                kind: workout.activity == nil ? .strength : .activity,
                planID: workout.planID,
                activityName: workout.activity?.name ?? "",
                distance: workout.activity?.distanceMeters.map { unit.value(meters: $0) },
                notes: workout.activity?.notes ?? "",
                startedAt: workout.startedAt,
                minutes: max(5, Int(((workout.duration ?? 3_600) / 60).rounded()))
            )
        }
    }

    private func draftChanged(_ draft: PastWorkoutForm.Draft) {
        self.draft = draft
        switch purpose {
        case .create:
            addItem.isEnabled = draft.isComplete
            discardGuard?.refresh()
        case .editActivity, .editTime:
            autosaver.schedule()
        }
    }

    private var distanceMeters: Double? {
        draft.distance.map { DistanceUnit(dependencies.preferences.massUnit).meters(from: $0) }
    }

    // MARK: - Saving

    private func add() {
        guard draft.isComplete else { return }
        let duration = TimeInterval(draft.minutes * 60)
        do {
            let workout: WorkoutRecord
            switch draft.kind {
            case .strength:
                workout = try dependencies.store.logPastWorkout(from: draft.planID, startedAt: draft.startedAt, duration: duration)
            case .activity:
                workout = try dependencies.store.logActivity(
                    name: draft.trimmedActivityName, startedAt: draft.startedAt, duration: duration, distanceMeters: distanceMeters, notes: draft.notes
                )
            }
            let onCreated = onCreated
            presentingViewController?.dismiss(animated: true) { onCreated(workout) }
        } catch {
            Self.logger.error("Failed to log past Workout: \(error, privacy: .public)")
        }
    }

    private func saveEdit() {
        guard draft != initial, draft.isComplete else { return }
        let duration = TimeInterval(draft.minutes * 60)
        do {
            switch purpose {
            case .create:
                return
            case .editActivity(let workout):
                try dependencies.store.updateActivity(workout.id, name: draft.trimmedActivityName, distanceMeters: distanceMeters, notes: draft.notes)
                try dependencies.store.setWorkoutTime(workout.id, startedAt: draft.startedAt, duration: duration)
            case .editTime(let workout):
                try dependencies.store.setWorkoutTime(workout.id, startedAt: draft.startedAt, duration: duration)
            }
            onChange()
        } catch {
            Self.logger.error("Failed to save past Workout: \(error, privacy: .public)")
        }
    }
}
