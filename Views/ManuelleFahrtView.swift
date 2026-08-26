import SwiftData
import SwiftUI

/// Standard-Sheet zur manuellen Erfassung einer Fahrt – entweder komplett
/// von Hand, oder als Bestätigung nach einer beendeten GPS-Aufzeichnung
/// (`vorbefuellung`, siehe `Utilities/TrackingManager.swift`).
///
/// „Gefahrene Kilometer“ wird ausschließlich aus `kmStandEnde - kmStandStart`
/// berechnet und nur zur Anzeige eingeblendet – es gibt kein eigenes
/// Eingabefeld dafür. Auch nach einer GPS-Aufzeichnung bleiben die
/// Tachostände Pflicht: GPS liefert nur eine Streckenschätzung
/// (`vorbefuellung.distanzKm`) als Kontext, nie den amtlichen Tachostand
/// selbst. Es wird keine GPS-Route in SwiftData geschrieben – `Fahrt` kennt
/// nur die hier eingegebenen, verdichteten Werte. Nach erfolgreichem
/// Speichern wird die Fahrt sofort über `sperren()` gesperrt und ist danach
/// nicht mehr unprotokolliert editierbar.
struct ManuelleFahrtView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Fahrzeug.name) private var fahrzeuge: [Fahrzeug]

    /// `nil` bei rein manueller Erfassung. Andernfalls das Ergebnis einer
    /// gerade beendeten `TrackingManager`-Aufzeichnung, das Datum und
    /// Adressen vorbefüllt und die Streckenschätzung als Hinweis anzeigt.
    let vorbefuellung: TrackingErgebnis?

    @State private var fahrzeugId: UUID?
    @State private var datum: Date
    @State private var startAdresse: String
    @State private var zielAdresse: String
    @State private var kmStandStartText = ""
    @State private var kmStandEndeText = ""
    @State private var zweck: Fahrzweck = .kunde
    @State private var zweckKonkret = ""
    @State private var geschaeftspartner = ""
    @State private var notizen: String
    @State private var inlineFehler: FahrtFormFehler?
    @State private var zeigeSpeichernFehlgeschlagen = false
    @State private var speichernFehlerText = ""

    @FocusState private var fokussiertesFeld: FahrtFormFeld?

    init(vorbefuellung: TrackingErgebnis? = nil) {
        self.vorbefuellung = vorbefuellung
        _datum = State(initialValue: vorbefuellung?.startZeitpunkt ?? .now)
        _startAdresse = State(initialValue: vorbefuellung?.startAdresse ?? "")
        _zielAdresse = State(initialValue: vorbefuellung?.zielAdresse ?? "")
        if vorbefuellung?.gpsSignalGingVerloren == true {
            _notizen = State(initialValue: "GPS-Signal während der Aufzeichnung zeitweise verloren; Kilometerstände nach Fahrtende manuell bestätigt.")
        } else {
            _notizen = State(initialValue: "")
        }
    }

    private var berechneteKm: Double? {
        guard
            let kmStandStart = FahrtValidierung.geparsterKilometerstand(kmStandStartText),
            let kmStandEnde = FahrtValidierung.geparsterKilometerstand(kmStandEndeText),
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
                    Section {
                        DatePicker("Datum der Fahrt", selection: $datum, displayedComponents: .date)
                        Picker("Fahrzeug", selection: $fahrzeugId) {
                            Text("Bitte wählen").tag(UUID?.none)
                            ForEach(fahrzeuge) { fahrzeug in
                                Text(fahrzeug.name).tag(Optional(fahrzeug.id))
                            }
                        }
                        .focused($fokussiertesFeld, equals: .fahrzeug)
                        .accessibilityHint("Wählt das für diese Fahrt genutzte Fahrzeug aus.")
                    }

                    Section("Strecke") {
                        if let vorbefuellung {
                            Text("GPS hat ca. \(vorbefuellung.distanzKm.alsKilometerWert) km gemessen. Bitte trage die tatsächlichen Tachostände ein.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        TextField("Start-Adresse", text: $startAdresse, prompt: Text("Straße, Postleitzahl, Ort"))
                            .focused($fokussiertesFeld, equals: .startAdresse)
                        TextField("Ziel-Adresse", text: $zielAdresse, prompt: Text("Straße, Postleitzahl, Ort"))
                            .focused($fokussiertesFeld, equals: .zielAdresse)
                        TextField("Tachostand bei Fahrtbeginn", text: $kmStandStartText)
                            .keyboardType(.decimalPad)
                            .focused($fokussiertesFeld, equals: .kmStandStart)
                            .onChange(of: kmStandStartText) { _, neuerWert in
                                guard let vorbefuellung, kmStandEndeText.isEmpty,
                                      let kmStandStart = FahrtValidierung.geparsterKilometerstand(neuerWert) else { return }
                                kmStandEndeText = (kmStandStart + vorbefuellung.distanzKm).alsKilometerWert
                            }
                        TextField("Tachostand bei Fahrtende", text: $kmStandEndeText)
                            .keyboardType(.decimalPad)
                            .focused($fokussiertesFeld, equals: .kmStandEnde)
                        if let berechneteKm {
                            LabeledContent("Gefahrene Kilometer", value: "\(berechneteKm.alsKilometerWert) km")
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

                    Section("Zweck") {
                        Picker("Zweck", selection: $zweck) {
                            ForEach(Fahrzweck.allCases) { eintrag in
                                Text(eintrag.anzeigeName).tag(eintrag)
                            }
                        }
                        TextField("Konkreter Zweck", text: $zweckKonkret, prompt: Text("z. B. „Projektbesprechung Meyer GmbH“"))
                            .focused($fokussiertesFeld, equals: .zweckKonkret)
                        TextField(
                            "Geschäftspartner",
                            text: $geschaeftspartner,
                            prompt: Text(zweck == .buero ? "optional bei Zweck „Büro“" : "erforderlich")
                        )
                        .focused($fokussiertesFeld, equals: .geschaeftspartner)
                        TextField("Notizen", text: $notizen, axis: .vertical)
                    }

                    if let inlineFehler {
                        Section {
                            Text(inlineFehler.meldung)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .accessibilityLabel("Fehler: \(inlineFehler.meldung)")
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
            .alert("Speichern nicht möglich", isPresented: $zeigeSpeichernFehlgeschlagen) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(speichernFehlerText)
            }
        }
    }

    private func speichern() {
        let eingabe = FahrtFormEingabe(
            fahrzeugId: fahrzeugId,
            startAdresse: startAdresse,
            zielAdresse: zielAdresse,
            kmStandStartText: kmStandStartText,
            kmStandEndeText: kmStandEndeText,
            zweck: zweck,
            zweckKonkret: zweckKonkret,
            geschaeftspartner: geschaeftspartner
        )

        switch FahrtValidierung.pruefe(eingabe) {
        case .failure(let fehler):
            inlineFehler = fehler
            fokussiertesFeld = fehler.feld
        case .success(let gueltig):
            inlineFehler = nil
            speichereFahrt(mit: gueltig)
        }
    }

    private func speichereFahrt(mit gueltig: FahrtFormGueltigeEingabe) {
        do {
            let fahrt = try Fahrt(
                startDatum: datum,
                endDatum: datum,
                startAdresse: startAdresse,
                zielAdresse: zielAdresse,
                kmStandStart: gueltig.kmStandStart,
                kmStandEnde: gueltig.kmStandEnde,
                zweck: zweck,
                zweckKonkret: zweckKonkret,
                geschaeftspartner: geschaeftspartner,
                fahrzeugId: gueltig.fahrzeugId,
                notizen: notizen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notizen,
                isManual: true
            )
            modelContext.insert(fahrt)
            fahrt.sperren()
            try modelContext.save()
            dismiss()
        } catch {
            speichernFehlerText = error.localizedDescription
            zeigeSpeichernFehlgeschlagen = true
        }
    }
}

#Preview {
    ManuelleFahrtView()
        .modelContainer(for: [Fahrzeug.self, Fahrt.self, AuditEntry.self], inMemory: true)
}
