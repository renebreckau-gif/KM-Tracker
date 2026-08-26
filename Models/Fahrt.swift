import Foundation
import SwiftData

/// Validierungsfehler rund um eine `Fahrt`. Alle Fälle liefern deutsche,
/// nutzerlesbare Meldungen über `LocalizedError`.
enum FahrtValidierungsFehler: LocalizedError {
    case ungueltigeKilometerstaende
    case leereAdresse
    case fehlenderZweckKonkret
    case fehlenderGeschaeftspartner
    case fahrtGesperrt
    case fehlenderAenderungsgrund

    var errorDescription: String? {
        switch self {
        case .ungueltigeKilometerstaende:
            return "Der End-Kilometerstand muss größer als der Start-Kilometerstand sein."
        case .leereAdresse:
            return "Start- und Zieladresse müssen vollständig ausgefüllt sein (Straße, PLZ, Ort)."
        case .fehlenderZweckKonkret:
            return "Bitte einen konkreten Fahrtzweck angeben, z. B. „Projektbesprechung Meyer GmbH“."
        case .fehlenderGeschaeftspartner:
            return "Bitte den besuchten Kunden oder Geschäftspartner angeben."
        case .fahrtGesperrt:
            return "Diese Fahrt ist gespeichert und gesperrt. Änderungen sind nur über den Audit-Prozess möglich."
        case .fehlenderAenderungsgrund:
            return "Für eine Änderung an einer gesperrten Fahrt muss ein Grund angegeben werden."
        }
    }
}

/// Eine einzelne, betrieblich veranlasste Fahrt.
///
/// Design-Entscheidungen (siehe Aufgabenstellung):
/// - Es gibt bewusst KEINE dauerhaft gespeicherte GPS-Route in diesem Modell.
///   GPS-Punkte einer aktiven Aufzeichnung leben ausschließlich im
///   Arbeitsspeicher der laufenden Aufzeichnungs-Session und werden beim
///   Abschluss der Fahrt auf `startAdresse`, `zielAdresse`,
///   `kmStandStart` und `kmStandEnde` verdichtet, nicht als Route persistiert.
/// - `km` ist niemals frei editierbar, sondern immer exakt
///   `kmStandEnde - kmStandStart`. Der Setter ist deshalb `private`; die
///   einzigen Wege, `km` zu verändern, sind der validierende Initializer und
///   `aktualisiere(...)`, die beide `km` selbst neu berechnen.
/// - Nach erfolgreichem Speichern (`sperren()`) ist `isLocked == true`.
///   `aktualisiere(...)` verweigert danach jede Änderung. Der einzige
///   verbleibende Änderungsweg ist `aendereGesperrtesFeld(...)`, der
///   ausschließlich für die Nutzung durch einen künftigen `AuditManager`
///   vorgesehen ist und für jede Änderung zwingend einen `AuditEntry`
///   zurückgibt, den der Aufrufer persistieren muss.
///
/// Teil von `SchemaV1`. Strukturelle Änderungen ab V1.1 (neue Pflichtfelder,
/// Typwechsel, Entfernen von Feldern) nur über eine neue Schema-Version mit
/// passender `MigrationStage` – siehe `KilometerLogMigrationPlan.swift`.
@Model
final class Fahrt {
    @Attribute(.unique) var id: UUID

    var startDatum: Date
    var endDatum: Date?

    /// Vollständige Adresse (Straße, PLZ, Ort) – nicht nur ein Ortsname.
    var startAdresse: String
    /// Vollständige Adresse (Straße, PLZ, Ort) – nicht nur ein Ortsname.
    var zielAdresse: String

    var kmStandStart: Double
    var kmStandEnde: Double

    /// Immer `kmStandEnde - kmStandStart`. Niemals unabhängig davon editierbar.
    private(set) var km: Double

    var zweck: Fahrzweck
    /// Konkrete Beschreibung des Anlasses, z. B. „Materialabholung für Auftrag 42“.
    /// Ein reiner Platzhalter wie „Termin“ genügt der Validierung nicht.
    var zweckKonkret: String
    /// Name des besuchten Kunden/Geschäftspartners. Darf nur bei `zweck == .buero` leer sein.
    var geschaeftspartner: String

    var fahrzeugId: UUID

    var notizen: String?
    var isManual: Bool
    private(set) var isLocked: Bool

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        startDatum: Date,
        endDatum: Date? = nil,
        startAdresse: String,
        zielAdresse: String,
        kmStandStart: Double,
        kmStandEnde: Double,
        zweck: Fahrzweck,
        zweckKonkret: String,
        geschaeftspartner: String,
        fahrzeugId: UUID,
        notizen: String? = nil,
        isManual: Bool = true,
        createdAt: Date = .now
    ) throws {
        try Fahrt.validiere(
            startAdresse: startAdresse,
            zielAdresse: zielAdresse,
            kmStandStart: kmStandStart,
            kmStandEnde: kmStandEnde,
            zweck: zweck,
            zweckKonkret: zweckKonkret,
            geschaeftspartner: geschaeftspartner
        )

        self.id = id
        self.startDatum = startDatum
        self.endDatum = endDatum
        self.startAdresse = startAdresse
        self.zielAdresse = zielAdresse
        self.kmStandStart = kmStandStart
        self.kmStandEnde = kmStandEnde
        self.km = kmStandEnde - kmStandStart
        self.zweck = zweck
        self.zweckKonkret = zweckKonkret
        self.geschaeftspartner = geschaeftspartner
        self.fahrzeugId = fahrzeugId
        self.notizen = notizen
        self.isManual = isManual
        self.isLocked = false
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    /// Zentrale Validierung, die sowohl vom Initializer als auch von
    /// `aktualisiere(...)` verwendet wird, damit beide Wege exakt dieselben
    /// Regeln durchsetzen.
    static func validiere(
        startAdresse: String,
        zielAdresse: String,
        kmStandStart: Double,
        kmStandEnde: Double,
        zweck: Fahrzweck,
        zweckKonkret: String,
        geschaeftspartner: String
    ) throws {
        guard !startAdresse.istLeerNachTrim, !zielAdresse.istLeerNachTrim else {
            throw FahrtValidierungsFehler.leereAdresse
        }
        guard kmStandEnde > kmStandStart else {
            throw FahrtValidierungsFehler.ungueltigeKilometerstaende
        }
        guard !zweckKonkret.istLeerNachTrim else {
            throw FahrtValidierungsFehler.fehlenderZweckKonkret
        }
        if zweck != .buero {
            guard !geschaeftspartner.istLeerNachTrim else {
                throw FahrtValidierungsFehler.fehlenderGeschaeftspartner
            }
        }
    }

    /// Aktualisiert eine noch nicht gesperrte Fahrt (`isLocked == false`).
    /// `km` wird dabei immer neu aus `kmStandEnde - kmStandStart` berechnet.
    /// Wirft `FahrtValidierungsFehler.fahrtGesperrt`, sobald die Fahrt
    /// bereits gesperrt ist – ab dann ist nur noch `aendereGesperrtesFeld(...)`
    /// erlaubt.
    func aktualisiere(
        startDatum: Date,
        endDatum: Date?,
        startAdresse: String,
        zielAdresse: String,
        kmStandStart: Double,
        kmStandEnde: Double,
        zweck: Fahrzweck,
        zweckKonkret: String,
        geschaeftspartner: String,
        notizen: String?
    ) throws {
        guard !isLocked else {
            throw FahrtValidierungsFehler.fahrtGesperrt
        }

        try Fahrt.validiere(
            startAdresse: startAdresse,
            zielAdresse: zielAdresse,
            kmStandStart: kmStandStart,
            kmStandEnde: kmStandEnde,
            zweck: zweck,
            zweckKonkret: zweckKonkret,
            geschaeftspartner: geschaeftspartner
        )

        self.startDatum = startDatum
        self.endDatum = endDatum
        self.startAdresse = startAdresse
        self.zielAdresse = zielAdresse
        self.kmStandStart = kmStandStart
        self.kmStandEnde = kmStandEnde
        self.km = kmStandEnde - kmStandStart
        self.zweck = zweck
        self.zweckKonkret = zweckKonkret
        self.geschaeftspartner = geschaeftspartner
        self.notizen = notizen
        self.updatedAt = .now
    }

    /// Wird von der App genau einmal aufgerufen, nachdem eine Fahrt
    /// erfolgreich in den `ModelContext` gespeichert wurde. Danach verweigert
    /// `aktualisiere(...)` jede weitere Änderung.
    func sperren() {
        isLocked = true
    }

    /// Einziger erlaubter Änderungsweg für eine bereits gesperrte Fahrt.
    ///
    /// Dieser Methode ist ausschließlich für die Nutzung durch einen
    /// künftigen `AuditManager` vorgesehen (folgt in einem späteren
    /// Ausbauschritt dieser App) und darf nicht aus der normalen
    /// Bearbeitungs-UI heraus aufgerufen werden. Sie erzwingt einen nicht
    /// leeren `grund` und gibt zwingend einen `AuditEntry` zurück, der den
    /// alten und neuen Wert dokumentiert; der Aufrufer ist dafür
    /// verantwortlich, diesen `AuditEntry` append-only zu speichern.
    @discardableResult
    func aendereGesperrtesFeld(
        feldName: String,
        alterWert: String,
        neuerWert: String,
        grund: String,
        anwenden: (Fahrt) -> Void
    ) throws -> AuditEntry {
        guard isLocked else {
            throw FahrtValidierungsFehler.fahrtGesperrt
        }
        let getrimmterGrund = grund.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !getrimmterGrund.isEmpty else {
            throw FahrtValidierungsFehler.fehlenderAenderungsgrund
        }

        anwenden(self)
        updatedAt = .now

        return AuditEntry(
            fahrtId: id,
            feldName: feldName,
            alterWert: alterWert,
            neuerWert: neuerWert,
            grund: getrimmterGrund
        )
    }
}

private extension String {
    var istLeerNachTrim: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
