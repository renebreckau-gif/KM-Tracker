import SwiftUI

/// Leerer Zustand der Fahrtenliste, wenn noch keine einzige Fahrt erfasst
/// wurde (unabhängig von einer aktiven Suche – dafür verwendet
/// `FahrtenListView` das eingebaute `ContentUnavailableView.search`).
struct FahrtenEmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Noch keine Fahrten", systemImage: "car.fill")
        } description: {
            Text("Erfasse deine erste Fahrt manuell über „Neue Fahrt“ oder starte oben die Aufzeichnung mit „Fahrt starten“.")
        }
    }
}

#Preview {
    FahrtenEmptyStateView()
}
