import SwiftUI
import SwiftData

/// Formular zur manuellen Erfassung einer bereits abgeschlossenen Fahrt.
///
/// `km` wird ausschließlich aus `kmStandEnde - kmStandStart` berechnet und
/// nur zur Anzeige eingeblendet – es gibt kein eigenes Eingabefeld dafür.
/// Nach erfolgreichem Speichern wird die Fahrt sofort über `sperren()`
/// gesperrt, wie von `Fahrt` vorgeschrieben.
struct ManuelleFahrtView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Fahrzeug.name) private var fahrzeuge: [Fahrzeug]

    @State private var fahrzeugId: UUID?
    @State private var startDatum = Date.now
    @State private var endDatum = Date.now
    @State private var startAdresse = ""
    @State private var zielAdresse = ""
    @State private var kmStandStartText = ""
    @State private var kmStandEndeText = ""
    @State private var zweck: Fahrzweck = .kunde
    @State private var zweckKonkret = ""
    @State private var geschaeftspartner = ""
    @State private var notizen = ""
    @State private var fehlermeldung: String?

    /// Wandelt eine Kilometerstand-Eingabe in eine `Double` um. Akzeptiert
    /// sowohl Punkt als auch deutsches Komma als Dezimaltrennzeichen.
    private func geparsterKilometerstand(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    private var berechneteKm: Double? {
        guard
            let kmStandStart = geparsterKilometerstand(kmStandStartText),
            let kmStandEnde = geparsterKilometerstand(kmStandEndeText),
            kmStandEnde > kmStandStart
        else { return nil }
        return kmStandEnde - kmStandStart
    }

    var body: some View {
        NavigationStack {
            Form {
                if fahrzeuge.isEmpty {
                    Section {
                        Text("Bitte lege zuerst in den Einstellungen ein Fahrzeug an, bevor du eine Fahrt erfassen kannst.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Fahrzeug") {
                        Picker("Fahrzeug", selection: $fahrzeugId) {
                            Text("Bitte wählen").tag(UUID?.none)
                            ForEach(fahrzeuge) { fahrzeug in
                                Text(fahrzeug.name).tag(Optional(fahrzeug.id))
                            }
                        }
                    }

                    Section("Zeitraum") {
                        DatePicker("Start", selection: $startDatum)
                        DatePicker("Ende", selection: $endDatum)
                    }

                    Section("Strecke") {
                        TextField("Startadresse (Straße, PLZ, Ort)", text: $startAdresse)
                        TextField("Zieladresse (Straße, PLZ, Ort)", text: $zielAdresse)
                        TextField("Kilometerstand Start", text: $kmStandStartText)
                            .keyboardType(.decimalPad)
                        TextField("Kilometerstand Ende", text: $kmStandEndeText)
                            .keyboardType(.decimalPad)
                        if let berechneteKm {
                            LabeledContent("Gefahrene Strecke", value: "\(berechneteKm.alsKilometerWert) km")
                        }
                    }

                    Section("Anlass") {
                        Picker("Zweck", selection: $zweck) {
                            ForEach(Fahrzweck.allCases) { zweck in
                                Text(zweck.anzeigeName).tag(zweck)
                            }
                        }
                        TextField("Konkreter Anlass, z. B. „Projektbesprechung Meyer GmbH“", text: $zweckKonkret)
                        TextField(
                            zweck == .buero ? "Geschäftspartner (optional bei Büro)" : "Geschäftspartner",
                            text: $geschaeftspartner
                        )
                        TextField("Notizen (optional)", text: $notizen, axis: .vertical)
                    }

                    if let fehlermeldung {
                        Section {
                            Text(fehlermeldung)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Neue Fahrt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .accessibilityLabel("Abbrechen")
                        .accessibilityHint("Verwirft die Eingaben und schließt das Formular.")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                        .disabled(fahrzeuge.isEmpty)
                        .accessibilityLabel("Speichern")
                        .accessibilityHint("Speichert die Fahrt und sperrt sie anschließend gegen Änderungen.")
                }
            }
        }
    }

    private func speichern() {
        guard let fahrzeugId else {
            fehlermeldung = "Bitte ein Fahrzeug auswählen."
            return
        }
        guard
            let kmStandStart = geparsterKilometerstand(kmStandStartText),
            let kmStandEnde = geparsterKilometerstand(kmStandEndeText)
        else {
            fehlermeldung = "Bitte Start- und End-Kilometerstand als Zahl angeben."
            return
        }

        do {
            let fahrt = try Fahrt(
                startDatum: startDatum,
                endDatum: endDatum,
                startAdresse: startAdresse,
                zielAdresse: zielAdresse,
                kmStandStart: kmStandStart,
                kmStandEnde: kmStandEnde,
                zweck: zweck,
                zweckKonkret: zweckKonkret,
                geschaeftspartner: geschaeftspartner,
                fahrzeugId: fahrzeugId,
                notizen: notizen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notizen,
                isManual: true
            )
            modelContext.insert(fahrt)
            fahrt.sperren()
            try modelContext.save()
            dismiss()
        } catch {
            fehlermeldung = error.localizedDescription
        }
    }
}

#Preview {
    ManuelleFahrtView()
        .modelContainer(for: [Fahrzeug.self, Fahrt.self, AuditEntry.self], inMemory: true)
}
