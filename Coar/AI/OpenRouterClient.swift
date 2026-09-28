import Foundation

/// What went wrong talking to OpenRouter, in the terms a screen shows (DESIGN.md: errors are
/// stated, never swallowed).
enum OpenRouterError: Error, Equatable {
    /// No key is saved in Settings.
    case noKey
    /// OpenRouter refused the key (HTTP 401): mistyped, revoked, or deleted.
    case keyRejected
    /// The key's spending limit, or the account's credit, is used up (HTTP 402).
    case limitReached
    /// The request never reached OpenRouter; worth sending again once there is a network.
    case offline
    /// Anything else, with a short reason for the log and the screen.
    case failed(String)

    /// The error for a reply that was not a success; nil for a 2xx.
    static func from(status: Int, body: Data) -> OpenRouterError? {
        guard !(200..<300).contains(status) else { return nil }
        let message = (try? JSONDecoder().decode(ErrorReply.self, from: body))?.error.message
        switch status {
        case 401: return .keyRejected
        case 402: return .limitReached
        case 403 where message?.localizedCaseInsensitiveContains("limit") == true: return .limitReached
        default: return .failed(message.map { "OpenRouter: \($0)" } ?? "OpenRouter replied \(status)")
        }
    }

    /// The error for a request that failed before any reply.
    static func from(_ error: Error) -> OpenRouterError {
        if let error = error as? OpenRouterError { return error }
        guard let error = error as? URLError else { return .failed(error.localizedDescription) }
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff,
             .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return .offline
        case .timedOut:
            return .failed("OpenRouter took too long to reply")
        default:
            return .failed(error.localizedDescription)
        }
    }

    private struct ErrorReply: Decodable {
        struct Body: Decodable { let message: String }
        let error: Body
    }
}

/// A key's spending as OpenRouter reports it (`GET /api/v1/key`), for Settings.
struct OpenRouterKeyStatus: Equatable {

    enum Reset: String {
        case daily, weekly, monthly
    }

    /// Dollars spent over the key's whole life.
    let usage: Double
    /// The spending cap, in dollars; nil when the key has none.
    let limit: Double?
    /// What is left of the cap in the current reset window.
    let limitRemaining: Double?
    /// How often the cap starts over; nil when it never does.
    let reset: Reset?

    init(usage: Double, limit: Double?, limitRemaining: Double?, reset: Reset?) {
        self.usage = usage
        self.limit = limit
        self.limitRemaining = limitRemaining
        self.reset = reset
    }

    init(json data: Data) throws {
        struct Reply: Decodable {
            struct Key: Decodable {
                let usage: Double
                let limit: Double?
                let limit_remaining: Double?
                let limit_reset: String?
            }
            let data: Key
        }
        let key = try JSONDecoder().decode(Reply.self, from: data).data
        self.init(usage: key.usage, limit: key.limit, limitRemaining: key.limit_remaining, reset: key.limit_reset.flatMap(Reset.init(rawValue:)))
    }

    /// "$0.14 of $2 this week", "$0.14 of $2", or "$3.10 spent, no limit".
    var spendText: String {
        guard let limit else { return "\(Self.dollars(usage)) spent, no limit" }
        let spent = limitRemaining.map { max(0, limit - $0) } ?? usage
        let window: String
        switch reset {
        case .daily: window = " today"
        case .weekly: window = " this week"
        case .monthly: window = " this month"
        case nil: window = ""
        }
        return "\(Self.dollars(spent)) of \(Self.dollars(limit))\(window)"
    }

    /// Whole dollars without cents ("$2"), a trace as "under $0.01", otherwise cents.
    static func dollars(_ amount: Double) -> String {
        if amount > 0, amount < 0.005 { return "under $0.01" }
        if amount == amount.rounded() { return "$\(Int(amount))" }
        return String(format: "$%.2f", amount)
    }
}

/// The one way Coar talks to OpenRouter (ADR 0007): the base URL and the key's source live
/// here, so moving the key to a server before release changes this type and nothing else.
final class OpenRouterClient {

    /// Sends a request and returns the body and response; `URLSession` in the app, a stub in tests.
    typealias Transport = (URLRequest) async throws -> (Data, URLResponse)

    let keys: APIKeyStore
    private let baseURL: URL
    private let transport: Transport

    init(
        keys: APIKeyStore,
        baseURL: URL = URL(string: "https://openrouter.ai/api/v1/")!,
        transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }
    ) {
        self.keys = keys
        self.baseURL = baseURL
        self.transport = transport
    }

    /// The spending of `key`, or of the saved key when nil. Checking a key before saving it
    /// passes it here directly.
    func keyStatus(of key: String? = nil) async throws -> OpenRouterKeyStatus {
        var request = try authorised(URLRequest(url: baseURL.appending(path: "key")), key: key)
        request.timeoutInterval = 15
        let data = try await send(request)
        do {
            return try OpenRouterKeyStatus(json: data)
        } catch {
            throw OpenRouterError.failed("OpenRouter sent a reply Coar couldn't read")
        }
    }

    /// The request with the key's bearer header; throws `.noKey` when there is none.
    func authorised(_ request: URLRequest, key: String? = nil) throws -> URLRequest {
        guard let key = key ?? keys.read(), !key.isEmpty else { throw OpenRouterError.noKey }
        var request = request
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("Coar", forHTTPHeaderField: "X-Title")
        return request
    }

    /// The body of a successful reply; every failure arrives as an `OpenRouterError`.
    func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport(request)
        } catch {
            throw OpenRouterError.from(error)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if let error = OpenRouterError.from(status: status, body: data) { throw error }
        return data
    }
}

extension OpenRouterError {
    /// One sentence for the screen: what happened and, where there is one, what to do.
    var message: String {
        switch self {
        case .noKey: return "Add your OpenRouter key in Settings."
        case .keyRejected: return "OpenRouter rejected the key. Check it was copied whole, or make a new one at openrouter.ai."
        case .limitReached: return "The key's spending limit is reached. Raise it at openrouter.ai, or wait for it to reset."
        case .offline: return "No connection."
        case .failed(let reason): return reason
        }
    }
}
