import Foundation
import Observation
import SwiftData

/// Fehler, die beim Versuch entstehen können, eine gesperrte Fahrt über
/// `AuditManager` zu ändern. Alle Fälle liefern deutsche, nutzerlesbare
/// Meldungen über `LocalizedError`.
enum AuditManagerFehler: LocalizedError {
    case fehlenderGrund
    case ungueltigerWert(feld: FahrtAenderbaresFeld)
    case fahrzeugNichtGefunden

    var errorDescription: String? {
        switch self {
        case .fehlenderGrund:
            return "Bitte einen Grund für die Änderung angeben."
        case .ungueltigerWert(let feld):
            return "„\(feld.rawValue)“ konnte nicht mit dem angegebenen Wert aktualisiert werden."
        case .fahrzeugNichtGefunden:
            return "Das ausgewählte Fahrzeug wurde nicht gefunden."
        }
    }
}

/// Änderbare Felder einer bereits gespeicherten (gesperrten) Fahrt.
///
/// Der `rawValue` ist zugleich der lesbare `feldName`, der im `AuditEntry`
/// gespeichert und in `AenderungsverlaufView`/`FahrtDetailView` angezeigt
/// wird – Anzeige und Protokollierung verwenden also immer denselben Text.
enum FahrtAenderbaresFeld: String, CaseIterable, Identifiable {
    case datum = "Datum"
    case endDatum = "Enddatum"
    case startAdresse = "Start-Adresse"
    case zielAdresse = "Ziel-Adresse"
    case kmStandStart = "Tachostand bei Fahrtbeginn"
    case kmStandEnde = "Tachostand bei Fahrtende"
    case zweck = "Zweck"
    case zweckKonkret = "Konkreter Zweck"
    case geschaeftspartner = "Geschäftspartner"
    case fahrzeug = "Fahrzeug"
    case notizen = "Notizen"

    var id: String { rawValue }
}

/// Erzwingt den einzigen erlaubten Änderungsweg für bereits gespeicherte
/// (gesperrte) Fahrten: Jede Änderung läuft über `aendereFahrt(...)`, das
/// intern `Fahrt.aendereGesperrtesFeld(...)` aufruft und den zurückgegebenen
/// `AuditEntry` in derselben `ModelContext`-Transaktion wie die
/// Fahrt-Änderung speichert. `FahrtBearbeitenView` ruft ausschließlich diese
/// Methode auf und bearbeitet `Fahrt`-Felder nie direkt über den
/// `modelContext`.
///
/// GoBD-Prinzipien:
/// - **Nachvollziehbarkeit**: Jede Änderung erhält einen Zeitstempel (`Date`)
///   und einen Pflicht-Grund.
/// - **Unveränderbarkeit**: `AuditEntry` wird nur erzeugt, nie nachträglich
///   verändert – diese Klasse bietet dafür bewusst keine Methode an.
/// - **Vollständigkeit**: Für gesperrte Fahrten gibt es keinen anderen Weg,
///   ein Feld zu ändern, ohne dass `aendereFahrt(...)` – und damit
///   `Fahrt.aendereGesperrtesFeld(...)` – durchlaufen wird.
/// - **Prüfbarkeit**: `AenderungsverlaufView` und ein künftiger Export
///   können den vollständigen Verlauf jederzeit vollständig auslesen.
@Observable
final class AuditManager {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Ändert genau ein Feld einer bereits gespeicherten Fahrt.
    ///
    /// `alterWert` und `neuerWert` sind lesbare, im deutschen
    /// Zahlen-/Datumsformat formatierte Strings (siehe `Double.alsKilometerWert`,
    /// `Date.alsKurzesDatum`) – so wie sie auch im Änderungsverlauf angezeigt
    /// werden.
    ///
    /// - Ein leerer `grund` (nach Trim) speichert nichts und wirft
    ///   `AuditManagerFehler.fehlenderGrund`.
    /// - Ist `alterWert == neuerWert`, liegt keine wirkliche Änderung vor:
    ///   Es wird weder ein `AuditEntry` erzeugt noch etwas gespeichert.
    /// - Bei Tachostand-Änderungen (`kmStandStart`/`kmStandEnde`) wird `km`
    ///   neu berechnet und – falls sich dadurch etwas ändert – zusätzlich als
    ///   eigener, weiterer `AuditEntry` „Gefahrene Kilometer“ protokolliert.
    /// - `fahrt.isLocked` bleibt `true`; `fahrt.updatedAt` wird aktualisiert.
    @discardableResult
    func aendereFahrt(
        fahrt: Fahrt,
        feld: FahrtAenderbaresFeld,
        alterWert: String,
        neuerWert: String,
        grund: String
    ) throws -> [AuditEntry] {
        let getrimmterGrund = grund.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !getrimmterGrund.isEmpty else {
            throw AuditManagerFehler.fehlenderGrund
        }
        guard alterWert != neuerWert else {
            return []
        }

        let alterKm = fahrt.km
        let anwenden = try anwendungsFunktion(fuer: feld, neuerWert: neuerWert)

        let eintrag = try fahrt.aendereGesperrtesFeld(
            feldName: feld.rawValue,
            alterWert: alterWert,
            neuerWert: neuerWert,
            grund: getrimmterGrund,
            anwenden: anwenden
        )
        modelContext.insert(eintrag)
        var erzeugteEintraege = [eintrag]

        if feld == .kmStandStart || feld == .kmStandEnde, fahrt.km != alterKm {
            let kmEintrag = AuditEntry(
                fahrtId: fahrt.id,
                feldName: "Gefahrene Kilometer",
                alterWert: alterKm.alsKilometerWert,
                neuerWert: fahrt.km.alsKilometerWert,
                grund: getrimmterGrund
            )
            modelContext.insert(kmEintrag)
            erzeugteEintraege.append(kmEintrag)
        }

        try modelContext.save()
        return erzeugteEintraege
    }

    /// Baut die konkrete Mutationsfunktion für `Fahrt.aendereGesperrtesFeld(...)`.
    /// Zentralisiert an dieser einen Stelle, welcher Feldname welche
    /// (typisierte) Eigenschaft von `Fahrt` betrifft und wie `neuerWert`
    /// dafür geparst wird.
    private func anwendungsFunktion(
        fuer feld: FahrtAenderbaresFeld,
        neuerWert: String
    ) throws -> (Fahrt) -> Void {
        switch feld {
        case .datum:
            guard let datum = Self.datumsFormatierer.date(from: neuerWert) else {
                throw AuditManagerFehler.ungueltigerWert(feld: feld)
            }
            return { $0.startDatum = datum }

        case .endDatum:
            guard let datum = Self.datumsFormatierer.date(from: neuerWert) else {
                throw AuditManagerFehler.ungueltigerWert(feld: feld)
            }
            return { $0.endDatum = datum }

        case .startAdresse:
            return { $0.startAdresse = neuerWert }

        case .zielAdresse:
            return { $0.zielAdresse = neuerWert }

        case .kmStandStart:
            guard let wert = FahrtValidierung.geparsterKilometerstand(neuerWert) else {
                throw AuditManagerFehler.ungueltigerWert(feld: feld)
            }
            return { fahrt in
                fahrt.kmStandStart = wert
                fahrt.kmNeuBerechnen()
            }

        case .kmStandEnde:
            guard let wert = FahrtValidierung.geparsterKilometerstand(neuerWert) else {
                throw AuditManagerFehler.ungueltigerWert(feld: feld)
            }
            return { fahrt in
                fahrt.kmStandEnde = wert
                fahrt.kmNeuBerechnen()
            }

        case .zweck:
            guard let wert = Fahrzweck.allCases.first(where: { $0.anzeigeName == neuerWert }) else {
                throw AuditManagerFehler.ungueltigerWert(feld: feld)
            }
            return { $0.zweck = wert }

        case .zweckKonkret:
            return { $0.zweckKonkret = neuerWert }

        case .geschaeftspartner:
            return { $0.geschaeftspartner = neuerWert }

        case .fahrzeug:
            let deskriptor = FetchDescriptor<Fahrzeug>(predicate: #Predicate { $0.name == neuerWert })
            guard let fahrzeug = try? modelContext.fetch(deskriptor).first else {
                throw AuditManagerFehler.fahrzeugNichtGefunden
            }
            let fahrzeugId = fahrzeug.id
            return { $0.fahrzeugId = fahrzeugId }

        case .notizen:
            return { $0.notizen = neuerWert.isEmpty ? nil : neuerWert }
        }
    }

    /// Deutsches, tolerantes Kurzdatum (dd.MM.yyyy), passend zu `Date.alsKurzesDatum`.
    private static let datumsFormatierer: DateFormatter = {
        let formatierer = DateFormatter()
        formatierer.locale = Locale(identifier: "de_DE")
        formatierer.dateFormat = "dd.MM.yyyy"
        formatierer.isLenient = true
        return formatierer
    }()
}
