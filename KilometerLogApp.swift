import SwiftUI
import SwiftData

/// KilometerLog – lokales elektronisches Fahrtenbuch für deutsche
/// Selbstständige. Alle Daten bleiben ausschließlich auf dem Gerät; es gibt
/// keinen Cloud- oder Serverzwang, keine Analytics und kein Tracking.
@main
struct KilometerLogApp: App {
    private let modelContainer: ModelContainer

    init() {
        let schema = Schema(versionedSchema: AktuellesSchema.self)
        let konfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            modelContainer = try ModelContainer(
                for: schema,
                migrationPlan: KilometerLogMigrationPlan.self,
                configurations: [konfiguration]
            )
        } catch {
            fatalError("SwiftData-ModelContainer konnte nicht erstellt werden: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - Gemeinsame Formatierungshilfen

/// Die App zeigt Beträge und Daten unabhängig von der Geräte-Sprache
/// einheitlich im deutschen Format an (Komma als Dezimaltrennzeichen,
/// „€“-Suffix, deutsche Datumsreihenfolge).
extension Locale {
    static let deutsch = Locale(identifier: "de_DE")
}

extension Double {
    /// Formatiert einen Betrag als deutschen Euro-Betrag, z. B. „30,00 €“.
    var alsEuroBetrag: String {
        formatted(.currency(code: "EUR").locale(.deutsch))
    }

    /// Formatiert einen Kilometerwert mit zwei Nachkommastellen, z. B. „12,30“.
    var alsKilometerWert: String {
        formatted(.number.locale(.deutsch).precision(.fractionLength(2)))
    }
}

extension Date {
    /// Kurzes deutsches Datum, z. B. „26.08.2026“.
    var alsKurzesDatum: String {
        formatted(.dateTime.day().month().year().locale(.deutsch))
    }
}
