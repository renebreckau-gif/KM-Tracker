import StoreKit
import SwiftUI

/// Sheet mit den Pro-Funktionen von KilometerLog sowie Jahres- und
/// Monatsabo.
///
/// Erhält `proManager` von der aufrufenden Ansicht, statt eine eigene
/// Instanz zu erzeugen: Ein hier abgeschlossener Kauf aktualisiert damit
/// sofort genau den `StoreManager`, den der Bildschirm, von dem aus dieses
/// Sheet geöffnet wurde, ebenfalls beobachtet.
struct PaywallView: View {
    let proManager: ProManager

    @Environment(\.dismiss) private var dismiss
    @State private var laeuftAktion = false
    @State private var fehlermeldung: String?
    @State private var zeigeFehler = false
    @State private var zeigeWiederhergestellt = false

    private var storeManager: StoreManager { proManager.storeManager }

    private let vorteile = [
        "Unbegrenzte Fahrten",
        "PDF-Export",
        "CSV-Export",
        "DATEV-Export",
        "Jahresübersicht",
        "Mehrere Fahrzeuge",
        "Änderungsverlauf"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Entspricht den Anforderungen an ein ordnungsgemäßes elektronisches Fahrtenbuch")
                            .font(.headline)
                        Text("Hilfsmittel, keine Steuerberatung; vollständige und korrekte Einträge bleiben deine Verantwortung.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Mit Pro erhältst du") {
                    ForEach(vorteile, id: \.self) { vorteil in
                        Label(vorteil, systemImage: "checkmark.circle.fill")
                            .accessibilityLabel(vorteil)
                    }
                }

                Section {
                    if let jahr = storeManager.produkt(fuer: .jahr) {
                        kaufZeile(titel: "Jahresabo", preis: jahr.displayPrice, id: .jahr)
                    } else {
                        kaufZeile(titel: "Jahresabo", preis: "24,99 €/Jahr (Beispiel)", id: .jahr)
                    }

                    if let monat = storeManager.produkt(fuer: .monat) {
                        kaufZeile(titel: "Monatsabo", preis: monat.displayPrice, id: .monat)
                    } else {
                        kaufZeile(titel: "Monatsabo", preis: "2,99 €/Monat (Beispiel)", id: .monat)
                    }

                    if let ladeFehler = storeManager.ladeFehler {
                        Text(ladeFehler)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Preise inklusive Mehrwertsteuer, abhängig von Land und Währung deines App-Store-Kontos. Abos verlängern sich automatisch und sind jederzeit in den Einstellungen des App Stores kündbar. Ohne geladene Preise (z. B. offline) zeigt diese Liste ausschließlich Beispielwerte, keine verbindlichen Preise.")
                }

                Section {
                    Button {
                        Task { await wiederherstellen() }
                    } label: {
                        Label("Käufe wiederherstellen", systemImage: "arrow.clockwise")
                    }
                    .accessibilityLabel("Käufe wiederherstellen")
                    .accessibilityHint("Prüft erneut, ob für diesen Apple-Account bereits ein Pro-Abo besteht.")

                    NavigationLink("Datenschutz") {
                        DatenschutzView()
                    }
                    NavigationLink("Rechtlicher Hinweis") {
                        RechtlicherHinweisView()
                    }
                }

                if let fehlermeldung {
                    Section {
                        Text(fehlermeldung)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("KilometerLog Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .accessibilityLabel("Schließen")
                        .accessibilityHint("Schließt KilometerLog Pro, ohne einen Kauf abzuschließen.")
                }
            }
            .disabled(laeuftAktion)
            .overlay {
                if laeuftAktion {
                    ProgressView("Wird verarbeitet …")
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .task {
                await storeManager.ladeProdukte()
            }
            .alert("Käufe wiederhergestellt", isPresented: $zeigeWiederhergestellt) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(proManager.isPro
                    ? "KilometerLog Pro ist jetzt für diesen Apple-Account freigeschaltet."
                    : "Für diesen Apple-Account wurde kein bestehendes Pro-Abo gefunden.")
            }
            .alert("Kauf nicht möglich", isPresented: $zeigeFehler) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(fehlermeldung ?? "")
            }
        }
    }

    @ViewBuilder
    private func kaufZeile(titel: String, preis: String, id: StoreProduktID) -> some View {
        Button {
            Task { await kaufen(id) }
        } label: {
            HStack {
                Text(titel)
                Spacer()
                Text(preis)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("\(titel), \(preis)")
        .accessibilityHint("Startet den Kauf über den App Store.")
    }

    @MainActor
    private func kaufen(_ id: StoreProduktID) async {
        laeuftAktion = true
        defer { laeuftAktion = false }
        fehlermeldung = nil

        do {
            if try await storeManager.purchase(id) != nil {
                dismiss()
            }
        } catch let fehler as StoreFehler {
            fehlermeldung = fehler.errorDescription
            zeigeFehler = true
        } catch {
            fehlermeldung = "Der Kauf ist fehlgeschlagen: \(error.localizedDescription)"
            zeigeFehler = true
        }
    }

    @MainActor
    private func wiederherstellen() async {
        laeuftAktion = true
        defer { laeuftAktion = false }
        fehlermeldung = nil

        do {
            _ = try await storeManager.wiederherstellen()
            zeigeWiederhergestellt = true
        } catch {
            fehlermeldung = "Käufe konnten nicht wiederhergestellt werden. Bitte die Internetverbindung prüfen: \(error.localizedDescription)"
            zeigeFehler = true
        }
    }
}

#Preview {
    PaywallView(proManager: ProManager())
}
