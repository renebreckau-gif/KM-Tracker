import Foundation

/// Berechnet Fahrtkosten nach den pauschalen Kilometersätzen für
/// Betriebsausgaben (nicht zu verwechseln mit der Pendlerpauschale/
/// Entfernungspauschale der privaten Steuererklärung).
///
/// Es gibt bewusst KEINE kumulierte Jahresschwelle und KEINE Zwei-Satz-Logik
/// nach bereits gefahrenen Jahreskilometern: Beide Sätze gelten linear und
/// ohne Kilometergrenze, exakt wie im deutschen Reisekostenrecht für
/// Betriebsausgaben.
enum FahrtkostenRechner {
    /// Pkw: 0,30 €/km, ohne Kilometergrenze.
    static let pkwSatzProKm: Double = 0.30

    /// Motorrad/Motorroller: 0,20 €/km, ohne Kilometergrenze.
    static let motorradSatzProKm: Double = 0.20

    /// Liefert den anzuwendenden Kilometersatz für einen Fahrzeugtyp.
    ///
    /// `sonstiges` verwendet als klar dokumentierten Fallback den Pkw-Satz,
    /// da es für sonstige Fahrzeuge keinen eigenen gesetzlichen Kilometersatz
    /// gibt.
    static func satzProKm(fuer fahrzeugTyp: FahrzeugTyp) -> Double {
        switch fahrzeugTyp {
        case .pkw:
            return pkwSatzProKm
        case .motorrad:
            return motorradSatzProKm
        case .sonstiges:
            return pkwSatzProKm
        }
    }

    /// Berechnet den Erstattungsbetrag für eine gegebene Kilometerzahl.
    /// Linear, ohne Kilometergrenze und ohne Rabatt-/Schwellenlogik.
    static func berechne(km: Double, fahrzeugTyp: FahrzeugTyp) -> Double {
        km * satzProKm(fuer: fahrzeugTyp)
    }

    /// Summiert Kilometer und Erstattungsbetrag über alle übergebenen
    /// Fahrten, jeweils mit dem Satz des tatsächlich genutzten Fahrzeugs.
    /// Fahrten, deren `fahrzeugId` auf kein übergebenes Fahrzeug verweist,
    /// werden übersprungen.
    static func berechneJahressumme(
        fahrten: [Fahrt],
        fahrzeuge: [Fahrzeug]
    ) -> (km: Double, betrag: Double) {
        let fahrzeugeNachId = Dictionary(uniqueKeysWithValues: fahrzeuge.map { ($0.id, $0) })

        var gesamtKm: Double = 0
        var gesamtBetrag: Double = 0

        for fahrt in fahrten {
            guard let fahrzeug = fahrzeugeNachId[fahrt.fahrzeugId] else { continue }
            gesamtKm += fahrt.km
            gesamtBetrag += berechne(km: fahrt.km, fahrzeugTyp: fahrzeug.typ)
        }

        return (km: gesamtKm, betrag: gesamtBetrag)
    }

    /// Hinweistext für die UI. Die Pendlerpauschale wird von dieser App
    /// bewusst nicht berechnet, da sie ausschließlich in der privaten
    /// Steuererklärung anzugeben ist und nichts mit den hier erfassten
    /// betrieblichen Fahrten zu tun hat.
    static let pendlerpauschaleHinweis =
        "Pendlerpauschale separat in der Steuererklärung angeben, nicht über diese App."
}
