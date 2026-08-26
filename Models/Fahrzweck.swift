import Foundation

/// Zulässige Zwecke einer betrieblichen Fahrt.
///
/// WICHTIG: Es gibt bewusst KEINEN Fall „privat“. KilometerLog ist ein
/// Fahrtenbuch für betrieblich veranlasste Fahrten Selbstständiger; ein
/// privater Zweck darf in keinem Picker, keiner Persistenz und keinem
/// Berechnungsergebnis auftauchen. Da dies eine geschlossene Swift-`enum`
/// ist, kann ein Aufrufer „privat“ weder auswählen noch kompilieren – ein
/// entsprechender Fall existiert im Quelltext schlicht nicht.
///
/// Neue Zwecke dürfen nur über eine neue Schema-Version ergänzt werden.
enum Fahrzweck: String, Codable, CaseIterable, Identifiable {
    case dienstreise
    case kunde
    case buero
    case messe
    case sonstiges

    var id: String { rawValue }

    /// Anzeigename für Picker, Listen und Belege.
    var anzeigeName: String {
        switch self {
        case .dienstreise:
            return "Dienstreise"
        case .kunde:
            return "Kundenbesuch"
        case .buero:
            return "Büro"
        case .messe:
            return "Messe"
        case .sonstiges:
            return "Sonstiges"
        }
    }
}
