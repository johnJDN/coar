import Foundation

/// One of four optional nutrition values an Entry may carry beyond its Macros (CONTEXT.md
/// "Extra"): fiber, sodium, caffeine, and alcohol. Shown only on an Entry's page and read by
/// the coach; never a Target, a total, or a card.
enum Extra: CaseIterable {
    case fiber, sodium, caffeine, alcohol

    var title: String {
        switch self {
        case .fiber: return "Fiber"
        case .sodium: return "Sodium"
        case .caffeine: return "Caffeine"
        case .alcohol: return "Alcohol"
        }
    }

    /// Grams, milligrams, milligrams, and US standard drinks (14 g of pure alcohol).
    var unit: String {
        switch self {
        case .fiber: return "g"
        case .sodium, .caffeine: return "mg"
        case .alcohol: return "drinks"
        }
    }

    var systemImage: String {
        switch self {
        case .fiber: return "carrot.fill"
        case .sodium: return "cube.fill"
        case .caffeine: return "cup.and.saucer.fill"
        case .alcohol: return "wineglass.fill"
        }
    }

    var keyPath: WritableKeyPath<Extras, Double?> {
        switch self {
        case .fiber: return \.fiber
        case .sodium: return \.sodium
        case .caffeine: return \.caffeine
        case .alcohol: return \.alcohol
        }
    }

    /// "12 g", "230 mg", "95 mg", "1 drink", "1.5 drinks".
    func text(_ value: Double) -> String {
        let rounded = self == .alcohol ? (value * 10).rounded() / 10 : value.rounded()
        let number = rounded.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
        return self == .alcohol && rounded == 1 ? "1 drink" : "\(number) \(unit)"
    }
}

/// The four Extras together, each present only when something recorded it. Nil is "not
/// recorded", never 0: caffeine and alcohol say nothing when there is none (`normalised`),
/// while a recorded 0 fiber or sodium is a fact. Totals count what was recorded, so they can
/// only undercount.
struct Extras: Hashable, Codable {
    var fiber: Double?
    var sodium: Double?
    var caffeine: Double?
    var alcohol: Double?

    subscript(extra: Extra) -> Double? {
        get { self[keyPath: extra.keyPath] }
        set { self[keyPath: extra.keyPath] = newValue }
    }

    var isEmpty: Bool {
        Extra.allCases.allSatisfy { self[$0] == nil }
    }

    /// The Extras with a value, in the usual order.
    var recorded: [(extra: Extra, value: Double)] {
        Extra.allCases.compactMap { extra in self[extra].map { (extra, $0) } }
    }

    /// Without readings that can't be true (negative, not a number), and with a caffeine or
    /// alcohol of 0 taken as none recorded: what an Entry stores.
    func normalised() -> Extras {
        var result = self
        for extra in Extra.allCases {
            guard let value = result[extra] else { continue }
            if value < 0 || !value.isFinite {
                result[extra] = nil
            } else if value == 0, extra == .caffeine || extra == .alcohol {
                result[extra] = nil
            }
        }
        return result
    }

    /// The Extras for `quantity` of something whose Extras for one are `self`.
    func scaled(by quantity: Double) -> Extras {
        var result = self
        for extra in Extra.allCases {
            result[extra] = self[extra].map { $0 * quantity }
        }
        return result
    }

    /// What was recorded across all of them, added up; an Extra nothing recorded stays nil.
    static func sum(_ all: [Extras]) -> Extras {
        var total = Extras()
        for extra in Extra.allCases {
            let values = all.compactMap { $0[extra] }
            total[extra] = values.isEmpty ? nil : values.reduce(0, +)
        }
        return total
    }

    /// The four as typed into a form: an empty field is not recorded; a negative or non-finite
    /// value makes the whole thing invalid.
    init?(typed fields: [Extra: Double?]) {
        self.init()
        for extra in Extra.allCases {
            guard let value = fields[extra] ?? nil else { continue }
            guard value >= 0, value.isFinite else { return nil }
            self[extra] = value
        }
    }

    init(fiber: Double? = nil, sodium: Double? = nil, caffeine: Double? = nil, alcohol: Double? = nil) {
        self.fiber = fiber
        self.sodium = sodium
        self.caffeine = caffeine
        self.alcohol = alcohol
    }
}
