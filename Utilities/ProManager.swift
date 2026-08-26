import Observation

/// Minimaler Platzhalter für die künftige Pro-/Abo-Verwaltung.
///
/// PLATZHALTER: `istPro` ist aktuell fest auf `false` gesetzt. Die eigentliche
/// Kauf-/Abo-Logik (StoreKit, Produkt-IDs, Restore Purchases, Serverseitige
/// Prüfung) ist bewusst NICHT Teil dieses Prompts und folgt in einem eigenen
/// Ausbauschritt. Bis dahin verweist jede Pro-geschützte Aktion konsequent
/// auf den ebenfalls vorläufigen `PaywallView`-Bildschirm, statt heimlich
/// alles freizuschalten.
///
/// Produktentscheidung für diesen Stand: PDF- und CSV-Export sind Teil der
/// steuerlichen Grundpflicht (ordnungsgemäßes Fahrtenbuch) und bleiben
/// deshalb frei nutzbar. Nur der DATEV-Export – eine Kanzlei-/Buchhaltungs-
/// Zusatzfunktion – ist gemäß Aufgabenstellung Pro-geschützt.
///
/// In einer echten Umsetzung würde eine einzelne, geteilte Instanz app-weit
/// über `.environment(_:)` injiziert statt pro View neu erzeugt zu werden.
@Observable
final class ProManager {
    /// PLATZHALTER – durch den echten Kauf-/Abo-Status ersetzen.
    var istPro: Bool = false

    /// Gilt aktuell ausschließlich für den DATEV-Export.
    func pruefeDATEVBerechtigung() -> Bool {
        istPro
    }
}
