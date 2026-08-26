import Foundation

/// Erzeugt den CSV-Export eines Steuerjahres.
///
/// Verwendet bewusst Semikolon (`;`) als Spaltentrennzeichen: Da alle
/// Zahlenwerte im geforderten deutschen Format mit Komma als
/// Dezimaltrennzeichen ausgegeben werden, würde ein Komma als
/// Spaltentrennzeichen jede Zahlenspalte beim Öffnen in Excel & Co.
/// zerreißen. Semikolon ist die in Deutschland übliche, kollisionsfreie
/// Konvention für genau diesen Fall und wird von deutschsprachigen
/// Tabellenkalkulationen automatisch korrekt erkannt.
///
/// Exportiert werden ausschließlich die in `Fahrt` gespeicherten,
/// verdichteten Werte – es gibt keine GPS-Punkte oder eine dauerhaft
/// gespeicherte Route, die exportiert werden könnten (siehe `Models/Fahrt.swift`).
enum CSVExporter {
    private static let spaltentrenner = ";"
    private static let zeilenumbruch = "\r\n"

    private static let spalten = [
        "Datum", "Datum (ISO 8601)", "Start-Adresse", "Ziel-Adresse",
        "Tachostand Start", "Tachostand Ende", "Kilometer", "Betrag (€)",
        "Zweck", "konkreter Zweck", "Geschäftspartner", "Fahrzeug", "Notizen",
        "Erstellt am", "Geändert am", "Änderungsanzahl"
    ]

    /// Erzeugt den vollständigen CSV-Inhalt für ein Steuerjahr als UTF-8
    /// (mit BOM) kodierte `Data` mit CRLF-Zeilenumbrüchen.
    ///
    /// `auditEntries` ist optional (Standard: leer): Wird sie mitgegeben
    /// (siehe `FahrtExporter`/`MonatsBackupManager`), enthält die Spalte
    /// „Änderungsanzahl“ die tatsächliche Anzahl protokollierter Änderungen
    /// je Fahrt; ohne sie steht dort „0“.
    static func generiereCSV(
        fahrten: [Fahrt],
        fahrzeuge: [Fahrzeug],
        jahr: Int,
        auditEntries: [AuditEntry] = []
    ) -> Data {
        let fahrzeugeNachId = Dictionary(uniqueKeysWithValues: fahrzeuge.map { ($0.id, $0) })
        let aenderungsanzahlNachFahrtId = Dictionary(grouping: auditEntries, by: \.fahrtId)
            .mapValues(\.count)

        let jahresFahrten = fahrten
            .filter { Calendar.current.component(.year, from: $0.startDatum) == jahr }
            .sorted { $0.startDatum < $1.startDatum }

        var zeilen = [spalten.map(escape).joined(separator: spaltentrenner)]

        for fahrt in jahresFahrten {
            let fahrzeug = fahrzeugeNachId[fahrt.fahrzeugId]
            let betrag = FahrtkostenRechner.berechne(km: fahrt.km, fahrzeugTyp: fahrzeug?.typ ?? .sonstiges)
            let aenderungsanzahl = aenderungsanzahlNachFahrtId[fahrt.id] ?? 0

            let felder = [
                ExportFormatierung.deutschesDatum.string(from: fahrt.startDatum),
                ExportFormatierung.iso8601.string(from: fahrt.startDatum),
                fahrt.startAdresse,
                fahrt.zielAdresse,
                ExportFormatierung.zahl(fahrt.kmStandStart),
                ExportFormatierung.zahl(fahrt.kmStandEnde),
                ExportFormatierung.zahl(fahrt.km),
                ExportFormatierung.zahl(betrag),
                fahrt.zweck.anzeigeName,
                fahrt.zweckKonkret,
                fahrt.geschaeftspartner,
                fahrzeug?.name ?? "Nicht zugeordnet",
                fahrt.notizen ?? "",
                ExportFormatierung.deutschesDatumMitUhrzeit.string(from: fahrt.createdAt),
                ExportFormatierung.deutschesDatumMitUhrzeit.string(from: fahrt.updatedAt),
                String(aenderungsanzahl)
            ]

            zeilen.append(felder.map(escape).joined(separator: spaltentrenner))
        }

        let inhalt = zeilen.joined(separator: zeilenumbruch) + zeilenumbruch
        var daten = Data([0xEF, 0xBB, 0xBF]) // UTF-8 BOM, für langfristige, werkzeugübergreifende Lesbarkeit.
        daten.append(inhalt.data(using: .utf8) ?? Data())
        return daten
    }

    /// Setzt ein Feld nur dann in Anführungszeichen, wenn es den
    /// Spaltentrenner, Anführungszeichen oder einen Zeilenumbruch enthält;
    /// enthaltene Anführungszeichen werden verdoppelt (RFC-4180-Konvention).
    private static func escape(_ feld: String) -> String {
        let benoetigtAnfuehrungszeichen = feld.contains(spaltentrenner)
            || feld.contains("\"")
            || feld.contains("\n")
            || feld.contains("\r")
        guard benoetigtAnfuehrungszeichen else { return feld }
        return "\"" + feld.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
