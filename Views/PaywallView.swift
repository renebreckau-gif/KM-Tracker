import SwiftUI

/// Platzhalter-Bezahlschranke für Pro-Funktionen wie den Datenexport.
///
/// Die eigentliche Kauf-/Abo-Anbindung (StoreKit, Preise, Produkte, Restore
/// Purchases) ist bewusst NICHT Teil dieses Prompts und folgt in einem
/// eigenen Ausbauschritt. Dieser Platzhalter stellt sicher, dass
/// `ProManager`-geschützte Aktionen schon jetzt konsistent auf einen
/// kompilierbaren, HIG-konformen Bildschirm verweisen, statt ins Leere zu
/// laufen.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("KilometerLog Pro", systemImage: "lock.fill")
            } description: {
                Text("Der Export als PDF, CSV und DATEV ist Teil von KilometerLog Pro. Die Kauf-Anbindung folgt in einem späteren Ausbauschritt.")
            }
            .navigationTitle("KilometerLog Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .accessibilityLabel("Schließen")
                        .accessibilityHint("Schließt den Hinweis zu KilometerLog Pro, ohne fortzufahren.")
                }
            }
        }
    }
}

#Preview {
    PaywallView()
}
