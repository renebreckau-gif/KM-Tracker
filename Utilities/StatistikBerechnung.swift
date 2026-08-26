import Foundation

/// Aggregierte Kennzahlen für einen Zeitraum oder eine Gruppe von Fahrten.
/// Beträge werden ausschließlich über `FahrtkostenRechner` ermittelt, nie
/// eigenständig neu berechnet oder dupliziert.
struct StatistikWert {
    var km: Double = 0
    var betrag: Double = 0
    var anzahlFahrten: Int = 0
}

/// Eine Zeile der Aufschlüsselung „Nach Zweck“. Da `Fahrzweck` eine
/// geschlossene, erschöpfend behandelte Aufzählung ist, kann für diese
/// Aufschlüsselung kein „nicht zugeordneter“ Fall entstehen.
struct ZweckStatistik: Identifiable {
    let zweck: Fahrzweck
    let wert: StatistikWert
    var id: Fahrzweck { zweck }
}

/// Eine Zeile der Aufschlüsselung „Nach Fahrzeug“. `fahrzeug == nil`
/// bedeutet: Die betroffenen Fahrten verweisen auf eine `fahrzeugId`, zu der
/// aktuell kein Fahrzeug mehr existiert (z. B. bei älteren, migrierten
/// Datenbeständen). Solche Fahrten werden NICHT stillschweigend einem
/// bestehenden Fahrzeug zugeschlagen, sondern sichtbar als „Nicht
/// zugeordnet“ ausgewiesen.
struct FahrzeugStatistik: Identifiable {
    let fahrzeug: Fahrzeug?
    let wert: StatistikWert
    var id: UUID { fahrzeug?.id ?? StatistikBerechnung.nichtZugeordnetKennung }
}

/// Gefahrene Kilometer eines einzelnen Kalendermonats, für das
/// Balkendiagramm der letzten sechs Monate.
struct MonatsKilometer: Identifiable {
    let monatsStart: Date
    let km: Double
    var id: Date { monatsStart }
}

/// Reine Aggregationslogik für `UebersichtView`. Verwendet für jede
/// Betragsberechnung ausschließlich `FahrtkostenRechner.berechne(...)` –
/// diese Datei kennt selbst keine Kilometersätze.
enum StatistikBerechnung {
    /// Stabile, nur innerhalb einer App-Session verwendete Ersatzkennung für
    /// Fahrten ohne auflösbares Fahrzeug. Wird nirgends persistiert.
    static let nichtZugeordnetKennung = UUID()

    /// Kennzahlen für exakt die übergebenen Fahrten, jeweils mit dem Satz
    /// des tatsächlich genutzten Fahrzeugtyps.
    static func wert(fuer fahrten: [Fahrt], fahrzeuge: [Fahrzeug]) -> StatistikWert {
        let fahrzeugeNachId = Dictionary(uniqueKeysWithValues: fahrzeuge.map { ($0.id, $0) })
        var ergebnis = StatistikWert()
        for fahrt in fahrten {
            let typ = fahrzeugeNachId[fahrt.fahrzeugId]?.typ ?? .sonstiges
            ergebnis.km += fahrt.km
            ergebnis.betrag += FahrtkostenRechner.berechne(km: fahrt.km, fahrzeugTyp: typ)
            ergebnis.anzahlFahrten += 1
        }
        return ergebnis
    }

    /// Kennzahlen für den Kalendermonat von `bezugsdatum` (Standard: heute),
    /// unabhängig vom in der Übersicht ausgewählten Steuerjahr.
    static func monatsWert(
        fahrten: [Fahrt],
        fahrzeuge: [Fahrzeug],
        bezugsdatum: Date = .now,
        kalender: Calendar = .current
    ) -> StatistikWert {
        let monatsFahrten = fahrten.filter {
            kalender.isDate($0.startDatum, equalTo: bezugsdatum, toGranularity: .month)
                && kalender.isDate($0.startDatum, equalTo: bezugsdatum, toGranularity: .year)
        }
        return wert(fuer: monatsFahrten, fahrzeuge: fahrzeuge)
    }

    /// Aufschlüsselung „Nach Zweck“: immer alle fünf Kategorien in fester
    /// Reihenfolge, auch mit dem Wert 0 – für eine vollständige, schnell
    /// erfassbare Übersicht.
    static func nachZweck(fahrten: [Fahrt], fahrzeuge: [Fahrzeug]) -> [ZweckStatistik] {
        Fahrzweck.allCases.map { zweck in
            let passende = fahrten.filter { $0.zweck == zweck }
            return ZweckStatistik(zweck: zweck, wert: wert(fuer: passende, fahrzeuge: fahrzeuge))
        }
    }

    /// Aufschlüsselung „Nach Fahrzeug“, alphabetisch sortiert. Nur
    /// tatsächlich genutzte Fahrzeuge erscheinen; nicht auflösbare
    /// `fahrzeugId`s werden als eine gemeinsame „Nicht zugeordnet“-Zeile
    /// zusammengefasst statt verworfen oder falsch zugeordnet.
    static func nachFahrzeug(fahrten: [Fahrt], fahrzeuge: [Fahrzeug]) -> [FahrzeugStatistik] {
        let fahrzeugeNachId = Dictionary(uniqueKeysWithValues: fahrzeuge.map { ($0.id, $0) })
        let gruppiert = Dictionary(grouping: fahrten, by: \.fahrzeugId)

        return gruppiert
            .map { fahrzeugId, fahrtenFuerFahrzeug in
                FahrzeugStatistik(
                    fahrzeug: fahrzeugeNachId[fahrzeugId],
                    wert: wert(fuer: fahrtenFuerFahrzeug, fahrzeuge: fahrzeuge)
                )
            }
            .sorted { erste, zweite in
                (erste.fahrzeug?.name ?? "Nicht zugeordnet") < (zweite.fahrzeug?.name ?? "Nicht zugeordnet")
            }
    }

    /// Gefahrene Kilometer je Monat für die letzten sechs Kalendermonate
    /// (einschließlich des aktuellen), älteste zuerst – unabhängig vom in
    /// der Übersicht ausgewählten Steuerjahr, da dies ein rollierendes
    /// Zeitfenster ist, das einen Jahreswechsel überspannen kann.
    static func letzteSechsMonate(
        fahrten: [Fahrt],
        bezugsdatum: Date = .now,
        kalender: Calendar = .current
    ) -> [MonatsKilometer] {
        (0..<6).reversed().compactMap { monateZurueck -> MonatsKilometer? in
            guard let monatsDatum = kalender.date(byAdding: .month, value: -monateZurueck, to: bezugsdatum),
                  let monatsStart = kalender.date(from: kalender.dateComponents([.year, .month], from: monatsDatum))
            else { return nil }

            let kmImMonat = fahrten
                .filter {
                    kalender.isDate($0.startDatum, equalTo: monatsDatum, toGranularity: .month)
                        && kalender.isDate($0.startDatum, equalTo: monatsDatum, toGranularity: .year)
                }
                .reduce(0) { $0 + $1.km }

            return MonatsKilometer(monatsStart: monatsStart, km: kmImMonat)
        }
    }
}
