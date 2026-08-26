import Foundation

/// Schnittstelle für den Datenexport, die `UebersichtView` aufruft.
///
/// Die eigentliche Erzeugung von PDF-, CSV- und DATEV-Dateien ist bewusst
/// NICHT Teil dieses Prompts und folgt in Prompt 7. `UebersichtView` ruft
/// bereits jetzt ausschließlich diese drei Funktionen auf, statt eigene
/// Exportlogik zu enthalten – ein künftiger Prompt muss dafür nur die
/// Implementierung dieser Funktionen ersetzen, nicht die aufrufende UI.
enum FahrtenExporter {
    enum ExportFehler: LocalizedError {
        case nochNichtVerfuegbar

        var errorDescription: String? {
            "Der Export folgt in einem späteren Ausbauschritt."
        }
    }

    /// - Returns: Die URL der erzeugten PDF-Datei.
    @discardableResult
    static func exportierePDF(fahrten: [Fahrt], fahrzeuge: [Fahrzeug], jahr: Int) throws -> URL {
        throw ExportFehler.nochNichtVerfuegbar
    }

    /// - Returns: Die URL der erzeugten CSV-Datei.
    @discardableResult
    static func exportiereCSV(fahrten: [Fahrt], fahrzeuge: [Fahrzeug], jahr: Int) throws -> URL {
        throw ExportFehler.nochNichtVerfuegbar
    }

    /// - Returns: Die URL der erzeugten DATEV-Exportdatei.
    @discardableResult
    static func exportiereDATEV(fahrten: [Fahrt], fahrzeuge: [Fahrzeug], jahr: Int) throws -> URL {
        throw ExportFehler.nochNichtVerfuegbar
    }
}
