import Foundation
import SwiftData

/// Ein Fahrzeug, dem Fahrten zugeordnet werden können.
///
/// Teil von `SchemaV1`. Änderungen an den gespeicherten Feldern ab V1.1
/// dürfen nur über eine neue `VersionedSchema` mit passender
/// `MigrationStage` erfolgen (siehe `KilometerLogMigrationPlan.swift`),
/// damit bestehende Fahrzeug-Datensätze beim App-Update erhalten bleiben.
@Model
final class Fahrzeug {
    @Attribute(.unique) var id: UUID
    var name: String
    var kennzeichen: String
    var typ: FahrzeugTyp
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        kennzeichen: String,
        typ: FahrzeugTyp,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.kennzeichen = kennzeichen
        self.typ = typ
        self.createdAt = createdAt
    }
}
