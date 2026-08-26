import SwiftUI

/// Rechtlicher Hinweis: KilometerLog unterstützt bei der Führung eines
/// Fahrtenbuchs, ersetzt aber keine steuerliche Beratung und garantiert
/// keine Anerkennung durch Finanzamt oder Betriebsprüfung.
struct RechtlicherHinweisView: View {
    var body: some View {
        Form {
            Section {
                Text("KilometerLog unterstützt dich dabei, betriebliche Fahrten lückenlos, zeitnah und unveränderbar zu dokumentieren.")
                    .font(.body)
            }

            Section("Keine Garantie der steuerlichen Anerkennung") {
                Text("Ob ein Fahrtenbuch im Einzelfall als ordnungsgemäß anerkannt wird, entscheidet ausschließlich das zuständige Finanzamt bzw. eine Betriebsprüfung anhand der jeweils gültigen Vorgaben. Die Nutzung dieser App stellt keine Zusicherung einer solchen Anerkennung dar.")
                    .font(.body)
            }

            Section("Keine Steuerberatung") {
                Text("Diese App ersetzt keine individuelle steuerliche Beratung. Wende dich bei Unsicherheiten an eine Steuerberaterin oder einen Steuerberater.")
                    .font(.body)
            }

            Section("Pendlerpauschale") {
                Text(FahrtkostenRechner.pendlerpauschaleHinweis)
                    .font(.body)
            }
        }
        .navigationTitle("Rechtlicher Hinweis")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        RechtlicherHinweisView()
    }
}
