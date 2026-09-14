import SwiftUI

extension View {
    /// A row in a hosted form sheet (Settings, the new-habit sheet): `surface` background,
    /// no separator (DESIGN.md §10). Buttons keep their tint so they read as tappable.
    func formRow() -> some View {
        listRowBackground(Color.surface)
            .listRowSeparator(.hidden)
    }
}
