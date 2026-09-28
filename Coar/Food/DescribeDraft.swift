import Foundation

/// One line of the Describe tab: one food as the user typed it, and how far it has got.
struct DescribeLine: Identifiable, Equatable, Codable {

    enum State: Equatable, Codable {
        /// Typed and not sent yet, or empty.
        case typing
        /// Sent; the Estimate is on its way.
        case checking
        /// Sent with no connection; it goes again once there is one.
        case waiting
        /// Filled in and ready to log.
        case filled(Estimate)
        /// Could not be filled in, and why, in a sentence; the screen offers to try again.
        case failed(String)
    }

    let id: UUID
    var text: String
    var state: State
    /// Add also saves it to Foods (ticket 05).
    var saveAsFood = false

    init(id: UUID = UUID(), text: String = "", state: State = .typing) {
        self.id = id
        self.text = text
        self.state = state
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, state, saveAsFood
    }

    /// Reads drafts saved before a field existed: a missing one takes its default.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        state = try container.decode(State.self, forKey: .state)
        saveAsFood = try container.decodeIfPresent(Bool.self, forKey: .saveAsFood) ?? false
    }

    /// The text as it is sent, and as a reply is matched against.
    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var estimate: Estimate? {
        if case .filled(let estimate) = state { return estimate }
        return nil
    }
}

/// The Describe tab's lines (spec "Describing"): what the user typed, one food per line, and
/// each line's Estimate once it has one. Every change is a value transition here; the screen
/// owns the timing and the requests. There is always at least one line to type into.
struct DescribeDraft: Equatable, Codable {

    private(set) var lines: [DescribeLine] = [DescribeLine()]

    func line(_ id: DescribeLine.ID) -> DescribeLine? {
        lines.first { $0.id == id }
    }

    private func index(_ id: DescribeLine.ID) -> Int? {
        lines.firstIndex { $0.id == id }
    }

    // MARK: Typing

    /// The user changed a line's text: its Estimate no longer describes it, so it is cleared.
    /// Returns whether anything changed.
    @discardableResult
    mutating func edit(_ id: DescribeLine.ID, text: String) -> Bool {
        guard let index = index(id), lines[index].text != text else { return false }
        let meaningChanged = lines[index].trimmedText != text.trimmingCharacters(in: .whitespacesAndNewlines)
        lines[index].text = text
        if meaningChanged {
            lines[index].state = .typing
        }
        return true
    }

    /// A new empty line straight after `id` (Return), or at the end; its id, to focus.
    @discardableResult
    mutating func insertLine(after id: DescribeLine.ID?) -> DescribeLine.ID {
        let line = DescribeLine()
        let position = id.flatMap(index).map { $0 + 1 } ?? lines.endIndex
        lines.insert(line, at: position)
        return line.id
    }

    /// Removes a line (backspace on an empty line); returns the line before it, to focus. The
    /// last line left is emptied instead, so there is always somewhere to type.
    @discardableResult
    mutating func removeLine(_ id: DescribeLine.ID) -> DescribeLine.ID? {
        guard let index = index(id) else { return nil }
        guard lines.count > 1 else {
            lines[index] = DescribeLine(id: id)
            return id
        }
        lines.remove(at: index)
        return lines[max(0, index - 1)].id
    }

    // MARK: Estimating

    /// Lines with text that have not been sent, or are waiting for a connection.
    var unsent: [DescribeLine.ID] {
        lines.filter { !$0.trimmedText.isEmpty && ($0.state == .typing || $0.state == .waiting) }.map(\.id)
    }

    /// Marks a line as sent and returns the text to send; nil when there is nothing to send
    /// (empty, or already filled for this text).
    mutating func begin(_ id: DescribeLine.ID) -> String? {
        guard let index = index(id), !lines[index].trimmedText.isEmpty else { return nil }
        switch lines[index].state {
        case .typing, .waiting, .failed:
            lines[index].state = .checking
            return lines[index].trimmedText
        case .checking, .filled:
            return nil
        }
    }

    /// A reply for the line as it read when sent. A reply for text that has since changed is
    /// dropped (returns false): the line has already gone back to typing.
    @discardableResult
    mutating func finish(_ id: DescribeLine.ID, sentText: String, result: Result<Estimate, Error>) -> Bool {
        guard let index = index(id), lines[index].trimmedText == sentText, lines[index].state == .checking else { return false }
        switch result {
        case .success(let estimate):
            lines[index].state = estimate.impossibility.map { .failed($0) } ?? .filled(estimate)
        case .failure(let error):
            lines[index].state = Self.state(after: error)
        }
        return true
    }

    /// Where a line ends up after a failed request. Key problems are the whole tab's, shown
    /// once above the lines, so the line itself just waits to be sent again.
    static func state(after error: Error) -> DescribeLine.State {
        switch error {
        case Estimate.ReplyError.notFood:
            return .failed("Not a food Coar knows. Check the spelling, or say more.")
        case Estimate.ReplyError.unreadable:
            return .failed("The reply couldn't be read.")
        default:
            switch OpenRouterError.from(error) {
            case .noKey, .keyRejected, .limitReached: return .typing
            case .offline: return .waiting
            case .failed(let reason): return .failed(reason)
            }
        }
    }

    /// After a relaunch: a line that was checking lost its request with the app, so it is
    /// sent again.
    mutating func resume() {
        for index in lines.indices where lines[index].state == .checking {
            lines[index].state = .typing
        }
    }

    /// Lines waiting for a connection, to send once there is one.
    var waiting: [DescribeLine.ID] {
        lines.filter { $0.state == .waiting }.map(\.id)
    }

    /// Nothing typed: Clear has nothing to do.
    var isEmpty: Bool {
        lines.allSatisfy { $0.trimmedText.isEmpty }
    }

    // MARK: The line page

    /// The line as edited on its page: filled with what the page holds, whatever it was
    /// before. Numbers the user typed are taken as they are (no impossibility check).
    mutating func setEstimate(_ id: DescribeLine.ID, _ estimate: Estimate) {
        guard let index = index(id) else { return }
        lines[index].state = .filled(estimate)
    }

    mutating func setSaveAsFood(_ id: DescribeLine.ID, _ saveAsFood: Bool) {
        guard let index = index(id) else { return }
        lines[index].saveAsFood = saveAsFood
    }

    // MARK: Logging

    /// The lines Log would log, in order.
    var filled: [DescribeLine] {
        lines.filter { $0.estimate != nil }
    }

    /// Everything Log would add, summed.
    var filledTotal: Macros {
        Macros.sum(filled.compactMap { $0.estimate?.macros })
    }

    /// Removes lines once logged; the rest stay, and an empty draft keeps one empty line.
    mutating func remove(_ ids: Set<DescribeLine.ID>) {
        lines.removeAll { ids.contains($0.id) }
        if lines.isEmpty { lines = [DescribeLine()] }
    }
}
