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
            KilometerLogWurzelAnsicht()
        }
        .modelContainer(modelContainer)
    }
}

/// Vorläufiger Einstiegsbildschirm für dieses Grundgerüst.
///
/// Dieser Prompt liefert bewusst nur Datenmodelle, Persistenz und den
/// Fahrtkostenrechner – die eigentlichen Fach-Screens (Fahrtenliste,
/// Fahrzeugverwaltung, Aufzeichnung, Auswertung) folgen in einem separaten
/// UI-Ausbauschritt. Diese Ansicht ist ein klar gekennzeichneter Platzhalter,
/// kein Feature, und verwendet bereits ausschließlich Standard-Komponenten
/// (`NavigationStack`, `List`) sowie semantische Textstile gemäß den
/// Apple-HIG-Vorgaben.
struct KilometerLogWurzelAnsicht: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Datenmodell, Persistenz und Fahrtkostenrechner sind eingerichtet.")
                        .font(.body)
                    Text(FahrtkostenRechner.pendlerpauschaleHinweis)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("KilometerLog")
                        .font(.headline)
                }
            }
            .navigationTitle("KilometerLog")
            .accessibilityHint("Platzhalter-Startbildschirm, die eigentlichen Fahrtenbuch-Funktionen folgen in einem späteren Ausbauschritt.")
        }
    }
}
