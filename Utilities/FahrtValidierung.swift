import Foundation

/// Felder des manuellen Fahrt-Formulars (`ManuelleFahrtView`), die bei einem
/// Validierungsfehler per `@FocusState` fokussiert werden können.
enum FahrtFormFeld: Hashable {
    case fahrzeug
    case startAdresse
    case zielAdresse
    case kmStandStart
    case kmStandEnde
    case zweckKonkret
    case geschaeftspartner
}

/// Deutsche, konkrete Fehlermeldung zusammen mit dem Feld, das anschließend
/// fokussiert werden soll.
struct FahrtFormFehler {
    let feld: FahrtFormFeld
    let meldung: String
}

/// Rohe Formular-Eingaben (noch als Text/Enum), bevor sie in die von
/// `Fahrt.init` erwarteten Typen überführt werden.
struct FahrtFormEingabe {
    var fahrzeugId: UUID?
    var startAdresse: String
    var zielAdresse: String
    var kmStandStartText: String
    var kmStandEndeText: String
    var zweck: Fahrzweck
    var zweckKonkret: String
    var geschaeftspartner: String
}

/// Ergebnis einer erfolgreichen Prüfung: bereits geparste, unmittelbar für
/// `Fahrt.init` nutzbare Werte.
struct FahrtFormGueltigeEingabe {
    let fahrzeugId: UUID
    let kmStandStart: Double
    let kmStandEnde: Double
    let km: Double
}

/// UI-nahe Validierung des manuellen Fahrt-Formulars.
///
/// Prüft Feld für Feld in fester Reihenfolge und bricht beim ersten Fehler
/// ab, damit `ManuelleFahrtView` genau EIN Feld fokussieren kann, statt
/// mehrere Meldungen gleichzeitig zu zeigen. Dies ist eine zusätzliche,
/// formularspezifische Prüfschicht VOR `Fahrt.init`/`Fahrt.validiere(...)`
/// (siehe `Models/Fahrt.swift`): Das Modell bleibt die letzte, nicht
/// verhandelbare Instanz und validiert unabhängig davon erneut – diese Prüfung
/// hier existiert ausschließlich, um dem Nutzer eine konkrete, auf ein Feld
/// bezogene Fehlermeldung mit Fokuswechsel zu zeigen.
enum FahrtValidierung {
    /// Eine einzelne Fahrt, die rechnerisch länger wäre als dieser Wert
    /// (in km), ist mit hoher Wahrscheinlichkeit ein Tippfehler bei den
    /// Tachoständen (z. B. eine zusätzliche Null) und wird abgelehnt, statt
    /// unkommentiert übernommen zu werden.
    static let maximalPlausibleStreckeKm: Double = 2000

    static func pruefe(_ eingabe: FahrtFormEingabe) -> Result<FahrtFormGueltigeEingabe, FahrtFormFehler> {
        guard let fahrzeugId = eingabe.fahrzeugId else {
            return .failure(FahrtFormFehler(feld: .fahrzeug, meldung: "Bitte ein Fahrzeug auswählen."))
        }

        let startAdresse = eingabe.startAdresse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !startAdresse.isEmpty else {
            return .failure(FahrtFormFehler(
                feld: .startAdresse,
                meldung: "Bitte die Start-Adresse mit Straße, Postleitzahl und Ort angeben."
            ))
        }

        let zielAdresse = eingabe.zielAdresse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !zielAdresse.isEmpty else {
            return .failure(FahrtFormFehler(
                feld: .zielAdresse,
                meldung: "Bitte die Ziel-Adresse mit Straße, Postleitzahl und Ort angeben."
            ))
        }

        guard let kmStandStart = geparsterKilometerstand(eingabe.kmStandStartText) else {
            return .failure(FahrtFormFehler(
                feld: .kmStandStart,
                meldung: "Bitte den Tachostand bei Fahrtbeginn als Zahl angeben."
            ))
        }

        guard let kmStandEnde = geparsterKilometerstand(eingabe.kmStandEndeText) else {
            return .failure(FahrtFormFehler(
                feld: .kmStandEnde,
                meldung: "Bitte den Tachostand bei Fahrtende als Zahl angeben."
            ))
        }

        guard kmStandEnde > kmStandStart else {
            return .failure(FahrtFormFehler(
                feld: .kmStandEnde,
                meldung: "Der Tachostand bei Fahrtende muss größer sein als bei Fahrtbeginn – ein gleicher oder rückwärtslaufender Tachostand ist nicht möglich."
            ))
        }

        let km = kmStandEnde - kmStandStart
        guard km > 0 else {
            return .failure(FahrtFormFehler(
                feld: .kmStandEnde,
                meldung: "Die gefahrenen Kilometer müssen größer als 0 sein."
            ))
        }
        guard km <= maximalPlausibleStreckeKm else {
            return .failure(FahrtFormFehler(
                feld: .kmStandEnde,
                meldung: "Diese Strecke wäre über \(Int(maximalPlausibleStreckeKm)) km lang. Bitte die Tachostände auf einen Tippfehler prüfen."
            ))
        }

        let zweckKonkret = eingabe.zweckKonkret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard zweckKonkret.count >= 5, !istZuAllgemein(zweckKonkret) else {
            return .failure(FahrtFormFehler(
                feld: .zweckKonkret,
                meldung: "Bitte den Zweck konkret beschreiben, z. B. „Projektbesprechung Meyer GmbH“ statt nur „Termin“."
            ))
        }

        if eingabe.zweck != .buero {
            let geschaeftspartner = eingabe.geschaeftspartner.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !geschaeftspartner.isEmpty else {
                return .failure(FahrtFormFehler(
                    feld: .geschaeftspartner,
                    meldung: "Bitte den Namen des Kunden oder Geschäftspartners angeben. Nur beim Zweck „Büro“ ist dieses Feld optional."
                ))
            }
        }

        return .success(FahrtFormGueltigeEingabe(
            fahrzeugId: fahrzeugId,
            kmStandStart: kmStandStart,
            kmStandEnde: kmStandEnde,
            km: km
        ))
    }

    /// Wandelt eine Kilometerstand-Eingabe in eine `Double` um. Akzeptiert
    /// sowohl Punkt als auch deutsches Komma als Dezimaltrennzeichen und
    /// verwirft nicht-endliche oder negative Werte als unplausibel.
    static func geparsterKilometerstand(_ text: String) -> Double? {
        let bereinigt = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let wert = Double(bereinigt), wert.isFinite, wert >= 0 else { return nil }
        return wert
    }

    /// Erkennt reine Platzhaltertexte wie „Termin“ oder „Fahrt“, die keine
    /// konkrete Beschreibung des Anlasses sind.
    private static func istZuAllgemein(_ text: String) -> Bool {
        let zuAllgemein: Set<String> = ["termin", "fahrt", "geschäftlich", "dienstlich", "meeting", "besuch"]
        return zuAllgemein.contains(text.lowercased())
    }
}
