import SwiftUI
import SwiftData

/// Formular zur Erfassung einer Fahrt – entweder komplett manuell, oder als
/// Bestätigung nach einer beendeten GPS-Aufzeichnung (`vorbefuellung`).
///
/// `km` wird ausschließlich aus `kmStandEnde - kmStandStart` berechnet und
/// nur zur Anzeige eingeblendet – es gibt kein eigenes Eingabefeld dafür.
/// Auch nach einer GPS-Aufzeichnung sind die Tachostände Pflicht: GPS liefert
/// nur eine Streckenschätzung (`vorbefuellung.distanzKm`) als Kontext, nie
/// den amtlichen Tachostand selbst. Nach erfolgreichem Speichern wird die
/// Fahrt sofort über `sperren()` gesperrt, wie von `Fahrt` vorgeschrieben.
struct ManuelleFahrtView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Fahrzeug.name) private var fahrzeuge: [Fahrzeug]

    /// `nil` bei rein manueller Erfassung. Andernfalls das Ergebnis einer
    /// gerade beendeten `TrackingManager`-Aufzeichnung, das Zeitraum und
    /// Adressen vorbefüllt und die Streckenschätzung als Hinweis anzeigt.
    let vorbefuellung: TrackingErgebnis?

    @State private var fahrzeugId: UUID?
    @State private var startDatum: Date
    @State private var endDatum: Date
    @State private var startAdresse: String
    @State private var zielAdresse: String
    @State private var kmStandStartText = ""
    @State private var kmStandEndeText = ""
    @State private var zweck: Fahrzweck = .kunde
    @State private var zweckKonkret = ""
    @State private var geschaeftspartner = ""
    @State private var notizen: String
    @State private var fehlermeldung: String?

    init(vorbefuellung: TrackingErgebnis? = nil) {
        self.vorbefuellung = vorbefuellung
        _startDatum = State(initialValue: vorbefuellung?.startZeitpunkt ?? .now)
        _endDatum = State(initialValue: vorbefuellung?.endZeitpunkt ?? .now)
        _startAdresse = State(initialValue: vorbefuellung?.startAdresse ?? "")
        _zielAdresse = State(initialValue: vorbefuellung?.zielAdresse ?? "")
        if vorbefuellung?.gpsSignalGingVerloren == true {
            _notizen = State(initialValue: "GPS-Signal während der Aufzeichnung zeitweise verloren; Kilometerstände nach Fahrtende manuell bestätigt.")
        } else {
            _notizen = State(initialValue: "")
        }
    }

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
                        if let vorbefuellung {
                            Text("GPS hat ca. \(vorbefuellung.distanzKm.alsKilometerWert) km gemessen. Bitte trage die tatsächlichen Tachostände ein.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        TextField("Startadresse (Straße, PLZ, Ort)", text: $startAdresse)
                        TextField("Zieladresse (Straße, PLZ, Ort)", text: $zielAdresse)
                        TextField("Kilometerstand Start", text: $kmStandStartText)
                            .keyboardType(.decimalPad)
                            .onChange(of: kmStandStartText) { _, neuerWert in
                                guard let vorbefuellung, kmStandEndeText.isEmpty,
                                      let kmStandStart = geparsterKilometerstand(neuerWert) else { return }
                                kmStandEndeText = (kmStandStart + vorbefuellung.distanzKm).alsKilometerWert
                            }
                        TextField("Kilometerstand Ende", text: $kmStandEndeText)
                            .keyboardType(.decimalPad)
                        if let berechneteKm {
                            LabeledContent("Gefahrene Strecke", value: "\(berechneteKm.alsKilometerWert) km")
                        }
                    }

                    if vorbefuellung?.gpsSignalGingVerloren == true {
                        Section {
                            Label(
                                "Das GPS-Signal wurde während der Aufzeichnung zeitweise verloren. Bitte die Kilometerstände sorgfältig prüfen – ein entsprechender Hinweis wurde bereits in die Notizen übernommen.",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.footnote)
                            .foregroundStyle(.orange)
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
            .navigationTitle(vorbefuellung == nil ? "Neue Fahrt" : "Fahrt bestätigen")
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
                isManual: vorbefuellung == nil
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
