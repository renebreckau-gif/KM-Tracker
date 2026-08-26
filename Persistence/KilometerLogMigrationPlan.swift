import Foundation
import SwiftData

/// Migrationsplan für den lokalen SwiftData-Store von KilometerLog.
///
/// Aktuell existiert nur `SchemaV1`, daher ist `stages` leer – es gibt noch
/// nichts zu migrieren. Diese Datei ist trotzdem ab Tag 1 vorhanden, damit
/// `KilometerLogApp.swift` den `ModelContainer` von Anfang an über
/// `Schema(versionedSchema:)` + `migrationPlan:` erzeugt. Dadurch verwendet
/// SwiftData für jede künftige Schema-Änderung zwingend eine hier definierte
/// `MigrationStage`, statt heimlich eine automatische, nicht versionierte
/// Migration durchzuführen, die Daten verlieren könnte.
///
/// **Wenn eine neue Version (z. B. `SchemaV1_1`) hinzukommt, gilt:**
///
/// 1. **Rein additive Felder** (ein neues, optionales `var feld: T? = nil`
///    oder ein neues Feld mit sinnvollem, deterministischem Default-Wert)
///    werden per Lightweight-Migration übernommen. SwiftData befüllt
///    bestehende Zeilen dabei automatisch und deterministisch mit `nil`
///    bzw. dem angegebenen Default – kein bestehender Wert wird verändert:
///
///    ```swift
///    // Beispiel, sobald SchemaV1_1 existiert:
///    MigrationStage.lightweight(
///        fromVersion: SchemaV1.self,
///        toVersion: SchemaV1_1.self
///    )
///    ```
///
/// 2. **Alles andere** (neue Pflichtfelder ohne generischen Default,
///    Typwechsel, Aufsplitten/Zusammenführen von Feldern, Entfernen von
///    Feldern mit noch benötigten Daten) erfordert eine `custom`-Stufe, die
///    alte Werte explizit und nachvollziehbar in die neue Struktur überführt,
///    BEVOR das alte Feld verschwindet:
///
///    ```swift
///    // Beispiel, sobald eine strukturelle Änderung ansteht:
///    MigrationStage.custom(
///        fromVersion: SchemaV1.self,
///        toVersion: SchemaV1_1.self,
///        willMigrate: { context in
///            // Alte Werte lesen und ggf. in ein Zwischenformat sichern,
///            // BEVOR SwiftData das Ziel-Schema anwendet.
///        },
///        didMigrate: { context in
///            // Neue Felder aus den gesicherten Alt-Werten befüllen und
///            // context.save() aufrufen. Alte Datensätze dürfen dabei
///            // niemals verloren gehen oder still überschrieben werden.
///        }
///    )
///    ```
///
/// Neue Versionen werden immer als zusätzliche Stufe ANGEHÄNGT, niemals
/// durch Ersetzen oder Löschen einer bestehenden Stufe.
enum KilometerLogMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
