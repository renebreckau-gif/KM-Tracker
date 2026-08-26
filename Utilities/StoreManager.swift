import Observation
import StoreKit

/// Produkt-IDs der beiden Pro-Abos.
///
/// PLATZHALTER: Diese IDs müssen exakt den in App Store Connect angelegten
/// In-App-Purchases entsprechen (bzw. den Einträgen im StoreKit
/// Configuration File während der Entwicklung/Tests), bevor die App
/// eingereicht wird.
enum StoreProduktID: String, CaseIterable {
    case monat = "com.kilometerlog.pro.monat"
    case jahr = "com.kilometerlog.pro.jahr"
}

/// Deutsche, konkrete Fehlermeldungen für den gesamten Kauf-Flow.
enum StoreFehler: LocalizedError {
    case nichtVerifiziert
    case unbekanntesProdukt
    case abgebrochen
    case ausstehend
    case unbekannt(String)

    var errorDescription: String? {
        switch self {
        case .nichtVerifiziert:
            return "Der Kauf konnte nicht verifiziert werden und wurde deshalb nicht freigeschaltet."
        case .unbekanntesProdukt:
            return "Dieses Produkt ist aktuell nicht verfügbar. Bitte die Internetverbindung prüfen."
        case .abgebrochen:
            return "Der Kauf wurde abgebrochen."
        case .ausstehend:
            return "Der Kauf wartet auf eine Freigabe (z. B. durch Bildschirmzeit-Einschränkungen der Familienfreigabe) und ist noch nicht abgeschlossen."
        case .unbekannt(let beschreibung):
            return "Der Kauf ist fehlgeschlagen: \(beschreibung)"
        }
    }
}

/// Dünner StoreKit-2-Wrapper: lädt Produkte, führt Käufe durch, prüft
/// Berechtigungen und hört auf Transaktionsaktualisierungen.
///
/// Kennt selbst keine Feature-Freischaltungen – das entscheidet
/// ausschließlich `ProManager`, der eine Instanz dieser Klasse verwendet.
///
/// Privacy-first: keinerlei eigene Analytics oder Drittanbieter-SDKs. Die
/// gesamte Kaufabwicklung läuft ausschließlich über Apples StoreKit;
/// KilometerLog sieht dabei keine Zahlungsdaten.
///
/// Als `@MainActor` markiert, da alle hier gehaltenen Eigenschaften direkt
/// von SwiftUI beobachtet werden und Product-/Transaction-Verarbeitung
/// unproblematisch auf dem Hauptthread laufen kann; der
/// Transaktions-Listener läuft dadurch nicht „hart“ abgekoppelt, sondern
/// als langlebiger, den App-Hauptkontext erbender Hintergrund-Task, der in
/// `deinit` zuverlässig abgebrochen wird.
@MainActor
@Observable
final class StoreManager {
    private(set) var produkte: [Product] = []
    private(set) var istPro = false
    private(set) var ladeFehler: String?

    private var transaktionsBeobachter: Task<Void, Never>?

    init() {
        transaktionsBeobachter = listenForTransactions()
        Task { [weak self] in
            await self?.ladeProdukte()
            _ = await self?.checkEntitlements()
        }
    }

    deinit {
        transaktionsBeobachter?.cancel()
    }

    // MARK: - Produkte

    /// Lädt die Produktdaten (Preise, lokale Währung) von StoreKit. Schlägt
    /// dies fehl (z. B. offline), bleibt `produkte` leer und `ladeFehler`
    /// erklärt die Ursache – die UI zeigt dann einen klar gekennzeichneten
    /// Beispielpreis statt eines Absturzes.
    func ladeProdukte() async {
        do {
            produkte = try await Product.products(for: StoreProduktID.allCases.map(\.rawValue))
                .sorted { $0.price < $1.price }
            ladeFehler = nil
        } catch {
            ladeFehler = "Preise konnten nicht geladen werden. Bitte die Internetverbindung prüfen."
        }
    }

    func produkt(fuer id: StoreProduktID) -> Product? {
        produkte.first { $0.id == id.rawValue }
    }

    // MARK: - Kauf

    @discardableResult
    func purchase(_ productID: StoreProduktID) async throws -> Transaction? {
        guard let produkt = produkt(fuer: productID) else {
            throw StoreFehler.unbekanntesProdukt
        }

        let ergebnis: Product.PurchaseResult
        do {
            ergebnis = try await produkt.purchase()
        } catch {
            throw StoreFehler.unbekannt(error.localizedDescription)
        }

        switch ergebnis {
        case .success(let verifikation):
            let transaktion = try pruefeVerifikation(verifikation)
            await transaktion.finish()
            _ = await checkEntitlements()
            return transaktion
        case .userCancelled:
            throw StoreFehler.abgebrochen
        case .pending:
            throw StoreFehler.ausstehend
        @unknown default:
            return nil
        }
    }

    // MARK: - Berechtigungen

    /// Prüft alle aktuellen Berechtigungen (`Transaction.currentEntitlements`)
    /// und setzt `istPro`, wenn eines der beiden Abo-Produkte verifiziert,
    /// aktiv und nicht widerrufen ist. Unverifizierte Transaktionen werden
    /// übersprungen und schalten NICHTS frei.
    @discardableResult
    func checkEntitlements() async -> Bool {
        var gefunden = false
        for await ergebnis in Transaction.currentEntitlements {
            guard let transaktion = try? pruefeVerifikation(ergebnis) else { continue }
            if StoreProduktID(rawValue: transaktion.productID) != nil, transaktion.revocationDate == nil {
                gefunden = true
            }
        }
        istPro = gefunden
        return gefunden
    }

    /// „Käufe wiederherstellen“: `AppStore.sync()` aktualisiert die lokalen
    /// Transaktionsdaten mit dem App-Store-Konto; anschließend werten wir
    /// sie über `checkEntitlements()` erneut aus.
    @discardableResult
    func wiederherstellen() async throws -> Bool {
        try await AppStore.sync()
        return await checkEntitlements()
    }

    // MARK: - Transaktions-Listener

    /// Läuft als langlebiger Hintergrund-Task für die Lebensdauer dieser
    /// Instanz und reagiert auf Kauf-/Erneuerungs-/Rückerstattungs-
    /// Ereignisse, die nicht über den direkten `purchase(_:)`-Aufruf
    /// hereinkommen (z. B. ein Familienfreigabe-Kauf auf einem anderen
    /// Gerät, eine automatische Verlängerung oder eine Rückerstattung).
    /// Wird in `deinit` zuverlässig abgebrochen, damit kein Task nach dem
    /// Ende dieser Instanz weiterläuft.
    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await ergebnis in Transaction.updates {
                guard let self else { return }
                if let transaktion = try? self.pruefeVerifikation(ergebnis) {
                    await transaktion.finish()
                }
                _ = await self.checkEntitlements()
            }
        }
    }

    private func pruefeVerifikation(_ ergebnis: VerificationResult<Transaction>) throws -> Transaction {
        switch ergebnis {
        case .unverified:
            throw StoreFehler.nichtVerifiziert
        case .verified(let transaktion):
            return transaktion
        }
    }
}
