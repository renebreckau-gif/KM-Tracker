import SwiftUI

/// Kompakte, schnell erfassbare Kennzahlen-Kachel, z. B. für Jahres- oder
/// Monatswerte in `UebersichtView`. Verwendet ausschließlich semantische,
/// adaptive Farben (`.secondary`, `.quaternary`) statt fester
/// Color.black/white-Flächen oder manueller Blur-/Material-Effekte.
struct StatistikKarte: View {
    let titel: String
    let wert: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(titel, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(wert)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titel): \(wert)")
    }
}

#Preview {
    HStack(spacing: 12) {
        StatistikKarte(titel: "Kilometer", wert: "1.234,50 km", systemImage: "road.lanes")
        StatistikKarte(titel: "Betrag", wert: "370,35 €", systemImage: "eurosign.circle")
        StatistikKarte(titel: "Fahrten", wert: "42", systemImage: "number")
    }
    .padding()
}
