import Observation

/// Pro-geschützte Funktionsbereiche von KilometerLog.
///
/// Aktuell schalten alle Fälle einheitlich mit `isPro` frei (ein einziger
/// Pro-Tarif) – die Aufteilung in einzelne Fälle hält die Gating-Stellen im
/// Code (`isFeatureAvailable(_:)`-Aufrufe) trotzdem sprechend und macht
/// jede einzelne Stelle unabhängig erweiterbar, falls Funktionen künftig
/// unterschiedlich gestaffelt werden sollen.
enum ProFeature: CaseIterable {
    case unbegrenzteFahrten
    case pdfExport
    case csvExport
    case datevExport
    case jahresuebersicht
    case mehrereFahrzeuge
    case aenderungsverlauf

    var anzeigeName: String {
        switch self {
        case .unbegrenzteFahrten: return "Unbegrenzte Fahrten"
        case .pdfExport: return "PDF-Export"
        case .csvExport: return "CSV-Export"
        case .datevExport: return "DATEV-Export"
        case .jahresuebersicht: return "Jahresübersicht"
        case .mehrereFahrzeuge: return "Mehrere Fahrzeuge"
        case .aenderungsverlauf: return "Änderungsverlauf"
        }
    }
}

/// Zentrale Instanz für Pro-Status und Feature-Freischaltung.
///
/// Hält intern einen `StoreManager` (StoreKit 2) und leitet `isPro` direkt
/// von dessen verifizierten Berechtigungen ab – es gibt keinen eigenen,
/// separat zu pflegenden Zustand, der aus dem Takt geraten könnte.
///
/// Bekannte Einschränkung dieses Stands: Jede Ansicht, die `ProManager`
/// benötigt, erzeugt aktuell ihre eigene Instanz (siehe `UebersichtView`,
/// `FahrtenListView`, `EinstellungenView`), statt eine einzige, app-weit
/// über `.environment(_:)` geteilte Instanz zu verwenden. Da `isPro`
/// letztlich aus StoreKits eigenem, systemweitem Berechtigungsspeicher
/// (`Transaction.currentEntitlements`) stammt, bleiben mehrere Instanzen
/// dennoch „eventually consistent“: Jede Instanz zeigt nach ihrem eigenen
/// `aktualisiereStatus()`-Aufruf (siehe `.task` in den drei Ansichten) den
/// korrekten, aktuellen Stand. Ein sofortiges Update ACROSS offener
/// Bildschirme direkt nach einem Kauf ist damit nicht garantiert – eine
/// einzelne geteilte Instanz wäre der sauberere nächste Ausbauschritt.
///
/// Als `@MainActor` markiert, weil `storeManager` (`StoreManager`) selbst
/// `@MainActor`-isoliert ist – ohne diese Annotation wäre der lesende
/// Zugriff auf `storeManager.istPro` in `isPro` ein Kompilierfehler.
@MainActor
@Observable
final class ProManager {
    let storeManager: StoreManager

    /// Bis zu dieser Anzahl Fahrten pro Kalendermonat bleibt die App auch
    /// ohne Pro uneingeschränkt nutzbar. Bestehende Fahrten werden bei
    /// Erreichen des Limits nie gelöscht oder gesperrt – lediglich das
    /// Anlegen einer weiteren Fahrt im selben Monat verlangt Pro.
    static let freiesLimitFahrtenProMonat = 10

    init(storeManager: StoreManager = StoreManager()) {
        self.storeManager = storeManager
    }

    var isPro: Bool {
        storeManager.istPro
    }

    /// Erneut mit StoreKit abgleichen. Aufgerufen z. B. in `.task` beim
    /// Erscheinen einer Ansicht, damit ein an anderer Stelle abgeschlossener
    /// Kauf zeitnah sichtbar wird (siehe Hinweis zur Mehrfachinstanz oben).
    func aktualisiereStatus() async {
        _ = await storeManager.checkEntitlements()
    }

    func isFeatureAvailable(_ feature: ProFeature) -> Bool {
        isPro
    }

    /// `true`, solange noch keine weitere Fahrt im aktuellen Kalendermonat
    /// das Free-Limit überschreiten würde, oder wenn `.unbegrenzteFahrten`
    /// freigeschaltet ist.
    func darfWeitereFahrtAnlegen(fahrtenDiesenMonat: Int) -> Bool {
        isFeatureAvailable(.unbegrenzteFahrten) || fahrtenDiesenMonat < Self.freiesLimitFahrtenProMonat
    }
}
