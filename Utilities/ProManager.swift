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
/// In einer echten Umsetzung würde eine einzelne, geteilte Instanz app-weit
/// über `.environment(_:)` injiziert statt pro View neu erzeugt zu werden.
@Observable
final class ProManager {
    /// PLATZHALTER – durch den echten Kauf-/Abo-Status ersetzen.
    var istPro: Bool = false

    func pruefeExportBerechtigung() -> Bool {
        istPro
    }
}
