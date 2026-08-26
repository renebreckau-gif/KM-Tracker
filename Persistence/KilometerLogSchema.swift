import Foundation
import SwiftData

/// Version 1 des KilometerLog-Datenmodells.
///
/// **Verbindliche Regel ab V1.1:** Sobald diese App veröffentlicht wurde,
/// dürfen `Fahrzeug`, `Fahrt` und `AuditEntry` NICHT mehr direkt verändert
/// werden (neue Felder, geänderte Typen, entfernte Felder, geänderte
/// Optionalität). Jede solche Änderung erfordert stattdessen:
///
/// 1. Eine neue `VersionedSchema`, z. B. `enum SchemaV1_1: VersionedSchema`
///    mit eigenen, für diese Version gültigen Modell-Typen
///    (`versionIdentifier = Schema.Version(1, 1, 0)`).
/// 2. Einen Eintrag in `KilometerLogMigrationPlan.schemas`.
/// 3. Eine passende `MigrationStage` in `KilometerLogMigrationPlan.stages`
///    (lightweight für rein additive, optionale Felder; custom für alles
///    andere – siehe `KilometerLogMigrationPlan.swift` für Details).
///
/// So bleiben bestehende Datensätze beim App-Update immer erhalten und
/// werden nie stillschweigend überschrieben oder verworfen.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Fahrzeug.self, Fahrt.self, AuditEntry.self]
    }
}

/// Zeigt immer auf die aktuell von der App verwendete Schema-Version.
/// Wird eine neue Version eingeführt, wird ausschließlich dieser Alias
/// umgehängt – `KilometerLogApp.swift` und `KilometerLogMigrationPlan.swift`
/// müssen dafür nicht angepasst werden.
typealias AktuellesSchema = SchemaV1
