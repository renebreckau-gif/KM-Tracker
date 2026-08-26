import Foundation
import SwiftData

/// Ein einzelner, unveränderlicher Änderungsnachweis für eine gesperrte Fahrt.
///
/// `AuditEntry` wird ausschließlich APPEND-ONLY verwendet:
/// - Es gibt in dieser App keinen UI-Pfad, der einen bestehenden `AuditEntry`
///   bearbeitet oder löscht. Jede nachträgliche Korrektur einer gesperrten
///   `Fahrt` erzeugt einen NEUEN `AuditEntry` zusätzlich zu den bestehenden.
/// - `alterWert` hält den ursprünglichen, überschriebenen Wert dauerhaft
///   lesbar fest – es gibt keine stille Überschreibung von Historie.
///
/// Teil von `SchemaV1`. Wie bei allen Modellen gilt: strukturelle Änderungen
/// ab V1.1 nur über eine neue Schema-Version mit `MigrationStage`.
@Model
final class AuditEntry {
    @Attribute(.unique) var id: UUID
    var fahrtId: UUID
    var feldName: String
    var alterWert: String
    var neuerWert: String
    var zeitstempel: Date
    var grund: String

    init(
        id: UUID = UUID(),
        fahrtId: UUID,
        feldName: String,
        alterWert: String,
        neuerWert: String,
        zeitstempel: Date = .now,
        grund: String
    ) {
        self.id = id
        self.fahrtId = fahrtId
        self.feldName = feldName
        self.alterWert = alterWert
        self.neuerWert = neuerWert
        self.zeitstempel = zeitstempel
        self.grund = grund
    }
}
