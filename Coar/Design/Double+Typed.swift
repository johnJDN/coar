import Foundation

extension Double {
    /// The number a text field holds, read in the user's locale ("22,5" as well as "22.5");
    /// nil when the text is not a finite number. The log sheets and set fields share it.
    init?(typed text: String) {
        guard let value = Self.typedParser.number(from: text)?.doubleValue ?? Double(text), value.isFinite else { return nil }
        self = value
    }

    private static let typedParser: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        return formatter
    }()
}
