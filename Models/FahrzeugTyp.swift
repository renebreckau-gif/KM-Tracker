import Foundation

/// Fahrzeugarten, die im Fahrtenbuch unterschieden werden.
///
/// Diese Fälle sind ab V1 festgeschrieben. Neue Fahrzeugarten dürfen nur über
/// eine neue Schema-Version (siehe `KilometerLogSchema.swift`) hinzugefügt
/// werden, niemals durch stillschweigendes Ändern der bestehenden Rohwerte.
enum FahrzeugTyp: String, Codable, CaseIterable, Identifiable {
    case pkw
    case motorrad
    case sonstiges

    var id: String { rawValue }

    /// Anzeigename für Picker, Listen und Belege.
    var anzeigeName: String {
        switch self {
        case .pkw:
            return "Pkw"
        case .motorrad:
            return "Motorrad"
        case .sonstiges:
            return "Sonstiges"
        }
    }
}
