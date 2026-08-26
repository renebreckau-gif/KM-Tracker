import SwiftUI

/// Kurzer Leitfaden, was ein ordnungsgemäßes elektronisches Fahrtenbuch laut
/// gängiger Praxis auszeichnet und wie KilometerLog dabei unterstützt.
struct LeitfadenView: View {
    var body: some View {
        Form {
            Section("Was ein Fahrtenbuch ordnungsgemäß macht") {
                Text("Ein Fahrtenbuch gilt in der Praxis dann als ordnungsgemäß, wenn es lückenlos, zeitnah und nachträglich nicht mehr unbemerkt veränderbar geführt wird.")
                    .font(.body)
            }

            Section("Lückenlos") {
                Text("Erfasse jede betriebliche Fahrt einzeln – mit Datum, vollständiger Start- und Zieladresse, den Kilometerständen zu Beginn und Ende sowie dem Anlass der Fahrt.")
                    .font(.body)
            }

            Section("Zeitnah") {
                Text("Trage Fahrten möglichst direkt nach der Fahrt ein, entweder manuell über „Neue Fahrt“ oder per automatischer Aufzeichnung.")
                    .font(.body)
            }

            Section("Nachträglich nicht veränderbar") {
                Text("Sobald eine Fahrt gespeichert ist, sperrt KilometerLog sie automatisch. Jede spätere Korrektur wird zusammen mit dem ursprünglichen Wert und einer Begründung im Änderungsverlauf der Fahrt festgehalten, statt den alten Wert zu überschreiben.")
                    .font(.body)
            }

            Section("Konkreter Anlass") {
                Text("Beschreibe den Anlass so konkret wie möglich, z. B. „Projektbesprechung Meyer GmbH“ statt nur „Termin“, und trage bei Kunden- oder Messebesuchen den Namen des Geschäftspartners ein.")
                    .font(.body)
            }
        }
        .navigationTitle("Fahrtenbuch-Leitfaden")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LeitfadenView()
    }
}
