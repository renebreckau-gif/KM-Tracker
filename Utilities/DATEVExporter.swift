import Foundation

/// Konfigurierbares Zielformat für den DATEV-Export.
///
/// WICHTIG: Dies ist bewusst KEIN Ausgabeformat, das automatisch mit jeder
/// DATEV-Software oder jedem Kontenrahmen kompatibel ist. DATEV pflegt
/// mehrere, versionsabhängige, lizenzpflichtige Formatspezifikationen (z. B.
/// „Bewegungsdaten“, „Rechnungswesen ASCII“), die hier nicht nachgebildet
/// werden. Stattdessen liefert `DATEVExporter` ein klar gekennzeichnetes,
/// KilometerLog-eigenes Zwischenformat, dessen Spalten vor dem Import mit
/// dem Steuerberater bzw. der tatsächlich genutzten DATEV-Anbindung
/// abgeglichen werden müssen. `formatKennung`/`formatVersion` machen genau
/// das im Exportkopf transparent, statt eine universelle Kompatibilität zu
/// behaupten.
struct DATEVFormatKonfiguration {
    /// PLATZHALTER – an das tatsächlich genutzte Zielformat anpassen.
    var formatKennung = "KilometerLog-Fahrtkosten"
    var formatVersion = "1.0"
    var spaltentrenner = ";"
    /// PLATZHALTER – von Steuerberater/Kanzlei vorgegeben, falls benötigt.
    var beraterNummer: String?
    /// PLATZHALTER – von Steuerberater/Kanzlei vorgegeben, falls benötigt.
    var mandantenNummer: String?
}

enum DATEVExportFehler: LocalizedError {
    case unzulaessigeZeichen(feld: String)
    case pflichtfeldFehlt(feld: String, datum: String)

    var errorDescription: String? {
        switch self {
        case .unzulaessigeZeichen(let feld):
            return "Das Feld „\(feld)“ enthält Zeichen (z. B. einen Zeilenumbruch), die im DATEV-Zielformat nicht zulässig sind."
        case .pflichtfeldFehlt(let feld, let datum):
            return "Für die Fahrt vom \(datum) fehlt das für den DATEV-Export erforderliche Feld „\(feld)“."
        }
    }
}

/// Separater Exporter für ein DATEV-orientiertes Zwischenformat.
///
/// Der DATEV-Export ist ein Pro-Feature: Die Berechtigungsprüfung
/// (`ProManager.isFeatureAvailable(.datevExport)`) erfolgt bewusst VOR dem
/// Aufruf dieser Funktion in `UebersichtView`, nicht hier – so bleibt der
/// Exporter selbst unabhängig testbar und die Berechtigungslogik an einer
/// einzigen Stelle.
enum DATEVExporter {
    /// Im gewählten Zielformat unzulässig, da es keine mehrzeiligen Felder
    /// vorsieht.
    private static let unzulaessigeZeichen: CharacterSet = .newlines

    static func generiereDATEV(
        fahrten: [Fahrt],
        fahrzeuge: [Fahrzeug],
        jahr: Int,
        konfiguration: DATEVFormatKonfiguration = DATEVFormatKonfiguration()
    ) throws -> Data {
        let fahrzeugeNachId = Dictionary(uniqueKeysWithValues: fahrzeuge.map { ($0.id, $0) })
        let jahresFahrten = fahrten
            .filter { Calendar.current.component(.year, from: $0.startDatum) == jahr }
            .sorted { $0.startDatum < $1.startDatum }

        var zeilen: [String] = []

        // Exportkopf: Format und Version klar kennzeichnen, statt
        // stillschweigend universelle DATEV-Kompatibilität zu unterstellen.
        zeilen.append([
            "Format", konfiguration.formatKennung,
            "Version", konfiguration.formatVersion,
            "Berater", konfiguration.beraterNummer ?? "",
            "Mandant", konfiguration.mandantenNummer ?? "",
            "Jahr", String(jahr)
        ].joined(separator: konfiguration.spaltentrenner))

        let spalten = ["Belegdatum", "Kilometer", "Betrag", "Buchungstext", "Fahrzeug"]
        zeilen.append(spalten.joined(separator: konfiguration.spaltentrenner))

        for fahrt in jahresFahrten {
            let fahrzeug = fahrzeugeNachId[fahrt.fahrzeugId]
            let betrag = FahrtkostenRechner.berechne(km: fahrt.km, fahrzeugTyp: fahrzeug?.typ ?? .sonstiges)

            let datumText = ExportFormatierung.deutschesDatum.string(from: fahrt.startDatum)
            guard !fahrt.zweckKonkret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DATEVExportFehler.pflichtfeldFehlt(feld: "konkreter Zweck", datum: datumText)
            }

            let buchungstext = "\(fahrt.zweck.anzeigeName): \(fahrt.zweckKonkret)"
            let fahrzeugName = fahrzeug?.name ?? "Nicht zugeordnet"

            for (feldName, wert) in [("Buchungstext", buchungstext), ("Fahrzeug", fahrzeugName)] {
                guard wert.rangeOfCharacter(from: unzulaessigeZeichen) == nil else {
                    throw DATEVExportFehler.unzulaessigeZeichen(feld: feldName)
                }
            }

            let felder = [
                datumText,
                ExportFormatierung.zahl(fahrt.km),
                ExportFormatierung.zahl(betrag),
                buchungstext.replacingOccurrences(of: konfiguration.spaltentrenner, with: "/"),
                fahrzeugName.replacingOccurrences(of: konfiguration.spaltentrenner, with: "/")
            ]
            zeilen.append(felder.joined(separator: konfiguration.spaltentrenner))
        }

        let inhalt = zeilen.joined(separator: "\r\n") + "\r\n"
        return inhalt.data(using: .utf8) ?? Data()
    }
}
