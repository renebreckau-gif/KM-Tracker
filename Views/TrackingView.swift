import SwiftUI

/// Platzhalter für die automatische GPS-Aufzeichnung einer Fahrt.
///
/// Die eigentliche Aufzeichnung (CoreLocation-Anbindung, Start/Stopp,
/// Berechtigungsabfrage, Verdichtung der GPS-Punkte zu Start-/Zieladresse
/// und Kilometerständen) ist bewusst NICHT Teil dieses UI-Gerüst-Prompts und
/// wird in einem eigenen, dafür vorgesehenen Prompt spezifiziert und
/// umgesetzt. Dieser Platzhalter stellt sicher, dass der
/// „Fahrt starten“-Button aus `FahrtenListView` schon jetzt in ein
/// kompilierbares, HIG-konformes Sheet führt, und hält an der Vorgabe fest,
/// dass GPS ausschließlich während einer aktiven Aufzeichnung verwendet
/// werden darf – hier wird noch keinerlei Standortzugriff angefordert.
struct TrackingView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Automatische Aufzeichnung", systemImage: "location.fill")
            } description: {
                Text("Die automatische GPS-Aufzeichnung folgt in einem späteren Ausbauschritt. Bitte nutze bis dahin „Neue Fahrt“, um eine Fahrt manuell zu erfassen.")
            }
            .navigationTitle("Fahrt starten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .accessibilityLabel("Schließen")
                        .accessibilityHint("Schließt den Platzhalter für die automatische Aufzeichnung.")
                }
            }
        }
    }
}

#Preview {
    TrackingView()
}
