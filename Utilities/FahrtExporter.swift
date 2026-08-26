import Foundation

/// Fehler beim Erzeugen oder Schreiben einer Exportdatei.
enum FahrtExportFehler: LocalizedError {
    case keineFahrten
    case schreibenFehlgeschlagen

    var errorDescription: String? {
        switch self {
        case .keineFahrten:
            return "Für das ausgewählte Jahr gibt es keine Fahrten zu exportieren."
        case .schreibenFehlgeschlagen:
            return "Die Exportdatei konnte nicht geschrieben werden."
        }
    }
}

/// Einstiegspunkt, den `UebersichtView` für den Datenexport aufruft.
///
/// Enthält bewusst KEINE eigene Formatierungs- oder Aggregationslogik:
/// PDF-, CSV- und DATEV-Erzeugung leben ausschließlich in `PDFExporter`,
/// `CSVExporter` und `DATEVExporter`. Diese Datei prüft nur, ob überhaupt
/// Fahrten vorhanden sind, ruft den passenden Exporter auf und schreibt das
/// Ergebnis in eine temporäre Datei mit sprechendem, deutschem Dateinamen,
/// die anschließend über `ShareSheet` angeboten werden kann.
enum FahrtExporter {
    @discardableResult
    static func exportierePDF(
        fahrten: [Fahrt],
        fahrzeuge: [Fahrzeug],
        auditEntries: [AuditEntry],
        jahr: Int
    ) throws -> URL {
        guard !fahrten.isEmpty else { throw FahrtExportFehler.keineFahrten }
        let daten = PDFExporter.generierePDF(fahrten: fahrten, fahrzeuge: fahrzeuge, auditEntries: auditEntries, jahr: jahr)
        return try schreibeDatei(daten: daten, dateiname: "KilometerLog_Fahrtenbuch_\(jahr).pdf")
    }

    @discardableResult
    static func exportiereCSV(
        fahrten: [Fahrt],
        fahrzeuge: [Fahrzeug],
        auditEntries: [AuditEntry],
        jahr: Int
    ) throws -> URL {
        guard !fahrten.isEmpty else { throw FahrtExportFehler.keineFahrten }
        let daten = CSVExporter.generiereCSV(fahrten: fahrten, fahrzeuge: fahrzeuge, jahr: jahr, auditEntries: auditEntries)
        return try schreibeDatei(daten: daten, dateiname: "KilometerLog_Fahrtenbuch_\(jahr).csv")
    }

    @discardableResult
    static func exportiereDATEV(
        fahrten: [Fahrt],
        fahrzeuge: [Fahrzeug],
        jahr: Int
    ) throws -> URL {
        guard !fahrten.isEmpty else { throw FahrtExportFehler.keineFahrten }
        let daten = try DATEVExporter.generiereDATEV(fahrten: fahrten, fahrzeuge: fahrzeuge, jahr: jahr)
        return try schreibeDatei(daten: daten, dateiname: "KilometerLog_DATEV_\(jahr).csv")
    }

    private static func schreibeDatei(daten: Data, dateiname: String) throws -> URL {
        let ziel = FileManager.default.temporaryDirectory.appendingPathComponent(dateiname)
        do {
            try daten.write(to: ziel, options: .atomic)
            return ziel
        } catch {
            throw FahrtExportFehler.schreibenFehlgeschlagen
        }
    }
}

/// Geteilte, rein technische Zahlen-/Datumsformatierung für maschinenlesbare
/// Exporte (CSV, DATEV). Bewusst getrennt von `Double.alsEuroBetrag`/
/// `alsKilometerWert` (Utilities/FahrtkostenRechner.swift-Nachbarschaft):
/// Diese UI-Formate enthalten Gruppierungspunkte und ein „€“-Zeichen, was in
/// einer für Buchhaltungssoftware bestimmten Datenspalte unerwünscht ist.
/// PDFExporter verwendet dagegen bewusst die UI-Formate, da das PDF ein für
/// Menschen gedachtes Dokument ist.
enum ExportFormatierung {
    static func zahl(_ wert: Double) -> String {
        zahlenFormat.string(from: NSNumber(value: wert)) ?? String(format: "%.2f", wert).replacingOccurrences(of: ".", with: ",")
    }

    static let deutschesDatum: DateFormatter = {
        let formatierer = DateFormatter()
        formatierer.locale = Locale(identifier: "de_DE")
        formatierer.dateFormat = "dd.MM.yyyy"
        return formatierer
    }()

    static let deutschesDatumMitUhrzeit: DateFormatter = {
        let formatierer = DateFormatter()
        formatierer.locale = Locale(identifier: "de_DE")
        formatierer.dateFormat = "dd.MM.yyyy HH:mm"
        return formatierer
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatierer = ISO8601DateFormatter()
        formatierer.formatOptions = [.withInternetDateTime]
        return formatierer
    }()

    /// Deutsches Zahlenformat ohne Tausendertrennzeichen (Kollisionsgefahr
    /// mit dem CSV-Spaltentrenner bzw. Verwirrung mit dem Dezimalkomma),
    /// mit Komma als Dezimaltrennzeichen und exakt zwei Nachkommastellen.
    private static let zahlenFormat: NumberFormatter = {
        let formatierer = NumberFormatter()
        formatierer.locale = Locale(identifier: "de_DE")
        formatierer.numberStyle = .decimal
        formatierer.usesGroupingSeparator = false
        formatierer.minimumFractionDigits = 2
        formatierer.maximumFractionDigits = 2
        formatierer.decimalSeparator = ","
        return formatierer
    }()
}
