import os

extension Logger {
    /// A logger in the app's one subsystem.
    init(category: String) {
        self.init(subsystem: "com.johnnguyen.coar", category: category)
    }
}
