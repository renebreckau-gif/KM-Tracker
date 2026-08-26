import SwiftUI

/// Lokale Datenschutzerklärung, solange in `AppKonfiguration.datenschutzURL`
/// keine extern gehostete Fassung hinterlegt ist.
///
/// PLATZHALTER: Die Kontaktangabe stammt aus `AppKonfiguration.supportEMail`
/// und muss vor einer Veröffentlichung durch die geprüfte, echte Adresse des
/// Anbieters ersetzt werden.
struct DatenschutzView: View {
    var body: some View {
        Form {
            Section("Lokale Datenhaltung") {
                Text("Alle Fahrten, Fahrzeuge und Änderungsverläufe werden ausschließlich lokal auf diesem Gerät gespeichert. Es gibt keine Cloud-Anbindung, keinen Server und keine Synchronisierung durch diese App.")
                    .font(.body)
            }

            Section("Standortdaten") {
                Text("GPS-Standortdaten werden ausschließlich während einer aktiven, von dir gestarteten Aufzeichnung verwendet, um Start, Ziel und Strecke einer Fahrt zu ermitteln. Es findet keine Standortverfolgung außerhalb einer aktiven Aufzeichnung statt, und Rohdaten der Route werden nicht dauerhaft gespeichert.")
                    .font(.body)
            }

            Section("Analytics und Tracking") {
                Text("Diese App verwendet keine Analyse- oder Tracking-Dienste und übermittelt keine Nutzungsdaten an Dritte.")
                    .font(.body)
            }

            Section("Kontakt") {
                Text("Bei Fragen zum Datenschutz erreichst du uns unter \(AppKonfiguration.supportEMail).")
                    .font(.body)
            }
        }
        .navigationTitle("Datenschutz")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DatenschutzView()
    }
}
