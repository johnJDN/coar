import SwiftUI
import UIKit
import os

/// The weight screen, pushed from the Train root. One card: Trend Weight as the hero (the
/// raw value with a `—` trend caption while there is only one point; `—` when there are
/// none), the chart of raw points and trend, and a Log action. Reads through the façade on
/// every appearance, after every log, and whenever the unit changes.
final class BodyWeightViewController: ScreenViewController {

    private static let logger = Logger(category: "BodyWeight")

    private let dependencies: AppDependencies
    private let heroLabel = HeroNumberLabel()
    private let captionLabel = UILabel()
    private let chart = UIHostingController(rootView: BodyWeightChart(model: .init(raw: [], trend: [], unit: "")))
    private var unitObservation: MassUnitObservation?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        super.init(title: "Body Weight")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let log = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { [weak self] _ in self?.presentLog() })
        log.accessibilityLabel = "Log Body Weight"
        navigationItem.rightBarButtonItem = log

        captionLabel.font = UIFont.label
        captionLabel.textColor = UIColor.textSecondary
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.numberOfLines = 0

        chart.view.backgroundColor = .clear
        chart.sizingOptions = .intrinsicContentSize
        addChild(chart)

        let card = CardView()
        card.contentStack.addArrangedSubview(heroLabel)
        card.contentStack.addArrangedSubview(captionLabel)
        card.contentStack.setCustomSpacing(Metrics.spaceInner, after: captionLabel)
        card.contentStack.addArrangedSubview(chart.view)
        contentStack.addArrangedSubview(card)
        chart.didMove(toParent: self)

        unitObservation = dependencies.preferences.observeMassUnit { [weak self] in self?.render() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    // MARK: - Rendering

    private func render() {
        let records: [BodyWeightRecord]
        do {
            records = try dependencies.store.bodyWeights()
        } catch {
            Self.logger.error("Failed to read Body Weights: \(error, privacy: .public)")
            records = []
        }
        let unit = dependencies.preferences.massUnit
        let trend = TrendWeight.series(of: records.map(\.kilograms))

        let caption: String
        if let latest = records.last {
            caption = trend.isEmpty
                ? "\(latest.day.shortText) · Trend —"
                : "Trend Weight · latest \(unit.displayText(fromKilograms: latest.kilograms)), \(latest.day.shortText)"
        } else {
            caption = "No Body Weight yet"
        }
        let hero = TrendWeight.hero(of: records.map(\.kilograms)).map { unit.displayText(fromKilograms: $0) }
        heroLabel.setValue(hero ?? "—", isEmpty: hero == nil)
        captionLabel.text = caption

        let raw = records.map { TrendPoint(date: $0.day.start(), value: unit.displayValue(fromKilograms: $0.kilograms)) }
        let smoothed = zip(raw, trend).map { TrendPoint(date: $0.date, value: unit.displayValue(fromKilograms: $1)) }
        chart.rootView = BodyWeightChart(model: .init(raw: raw, trend: smoothed, unit: unit.symbol))
    }

    // MARK: - Log

    private func presentLog() {
        let sheet = BodyWeightLogViewController.sheet(dependencies: dependencies) { [weak self] in self?.render() }
        present(sheet, animated: true)
    }
}
