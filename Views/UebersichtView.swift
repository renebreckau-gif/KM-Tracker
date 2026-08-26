import SwiftUI
import SwiftData

/// Kennzahlen-Übersicht: Jahres- und Monatswerte sowie der Einstieg in den
/// späteren Datenexport (Prompt 7).
struct UebersichtView: View {
    @Query private var fahrten: [Fahrt]
    @Query private var fahrzeuge: [Fahrzeug]

    @State private var zeigeExportHinweis = false

    private var jahresFahrten: [Fahrt] {
        let jahr = Calendar.current.component(.year, from: .now)
        return fahrten.filter { Calendar.current.component(.year, from: $0.startDatum) == jahr }
    }

    private var monatsFahrten: [Fahrt] {
        let jetzt = Date.now
        let kalender = Calendar.current
        return fahrten.filter {
            kalender.isDate($0.startDatum, equalTo: jetzt, toGranularity: .month)
                && kalender.isDate($0.startDatum, equalTo: jetzt, toGranularity: .year)
        }
    }

    private var jahresSumme: (km: Double, betrag: Double) {
        FahrtkostenRechner.berechneJahressumme(fahrten: jahresFahrten, fahrzeuge: fahrzeuge)
    }

    private var monatsSumme: (km: Double, betrag: Double) {
        FahrtkostenRechner.berechneJahressumme(fahrten: monatsFahrten, fahrzeuge: fahrzeuge)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Entspricht den Anforderungen an ein ordnungsgemäßes elektronisches Fahrtenbuch")
                        .font(.headline)
                    Text("Dies ist ein sachliches Merkmal der Erfassung (lückenlos, zeitnah, unveränderbar nach Speichern) und keine Garantie der steuerlichen Anerkennung im Einzelfall.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    NavigationLink("Rechtlicher Hinweis") {
                        RechtlicherHinweisView()
                    }
                    .font(.footnote)
                }
                .padding(.vertical, 4)
            }

            Section("Aktuelles Jahr") {
                LabeledContent("Jahreskilometer", value: "\(jahresSumme.km.alsKilometerWert) km")
                LabeledContent("Jahresbetrag", value: jahresSumme.betrag.alsEuroBetrag)
                LabeledContent("Anzahl Fahrten", value: "\(jahresFahrten.count)")
            }

            Section("Aktueller Monat") {
                LabeledContent("Kilometer", value: "\(monatsSumme.km.alsKilometerWert) km")
                LabeledContent("Betrag", value: monatsSumme.betrag.alsEuroBetrag)
                LabeledContent("Anzahl Fahrten", value: "\(monatsFahrten.count)")
            }

            Section("Export") {
                Button {
                    zeigeExportHinweis = true
                } label: {
                    Label("Als CSV exportieren", systemImage: "doc.text")
                }
                .accessibilityLabel("Als CSV exportieren")
                .accessibilityHint("Exportiert alle Fahrten als CSV-Datei.")

                Button {
                    zeigeExportHinweis = true
                } label: {
                    Label("Als PDF exportieren", systemImage: "doc.richtext")
                }
                .accessibilityLabel("Als PDF exportieren")
                .accessibilityHint("Exportiert alle Fahrten als PDF-Dokument.")
            }

            Section {
                Text(FahrtkostenRechner.pendlerpauschaleHinweis)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Übersicht")
        .alert("Export folgt in Kürze", isPresented: $zeigeExportHinweis) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Der Datenexport wird in einem späteren Ausbauschritt mit dieser Schaltfläche verbunden.")
        }
    }
}

#Preview {
    NavigationStack {
        UebersichtView()
    }
    .modelContainer(for: [Fahrzeug.self, Fahrt.self, AuditEntry.self], inMemory: true)
}
