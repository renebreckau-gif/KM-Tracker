import SwiftData
import SwiftUI

/// Bearbeitung einer bereits gespeicherten (gesperrten) Fahrt.
///
/// Jede Zeile ist einzeln antippbar und öffnet `FeldBearbeitenSheet` für
/// genau dieses eine Feld. Jede dort bestätigte Änderung läuft ausschließlich
/// über `AuditManager.aendereFahrt(...)` – diese Ansicht schreibt niemals
/// selbst in den `modelContext`.
struct FahrtBearbeitenView: View {
    let fahrt: Fahrt

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var fahrzeuge: [Fahrzeug]

    @State private var bearbeitetesFeld: FahrtAenderbaresFeld?

    private var auditManager: AuditManager {
        AuditManager(modelContext: modelContext)
    }

    private var fahrzeugName: String {
        fahrzeuge.first { $0.id == fahrt.fahrzeugId }?.name ?? "Unbekanntes Fahrzeug"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(
                        "Diese Fahrt wurde bereits gespeichert. Änderungen werden protokolliert und sind für das Finanzamt nachvollziehbar.",
                        systemImage: "checkmark.shield.fill"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .accessibilityElement(children: .combine)
                }

                Section("Strecke") {
                    bearbeitbareZeile(.datum, wert: fahrt.startDatum.alsKurzesDatum)
                    if fahrt.endDatum != nil {
                        bearbeitbareZeile(.endDatum, wert: (fahrt.endDatum ?? fahrt.startDatum).alsKurzesDatum)
                    }
                    bearbeitbareZeile(.startAdresse, wert: fahrt.startAdresse)
                    bearbeitbareZeile(.zielAdresse, wert: fahrt.zielAdresse)
                    bearbeitbareZeile(.kmStandStart, wert: "\(fahrt.kmStandStart.alsKilometerWert) km")
                    bearbeitbareZeile(.kmStandEnde, wert: "\(fahrt.kmStandEnde.alsKilometerWert) km")
                    LabeledContent("Gefahrene Kilometer", value: "\(fahrt.km.alsKilometerWert) km")
                    bearbeitbareZeile(.fahrzeug, wert: fahrzeugName)
                }

                Section("Anlass") {
                    bearbeitbareZeile(.zweck, wert: fahrt.zweck.anzeigeName)
                    bearbeitbareZeile(.zweckKonkret, wert: fahrt.zweckKonkret)
                    bearbeitbareZeile(.geschaeftspartner, wert: fahrt.geschaeftspartner.isEmpty ? "–" : fahrt.geschaeftspartner)
                    bearbeitbareZeile(.notizen, wert: (fahrt.notizen?.isEmpty == false ? fahrt.notizen! : "–"))
                }

                Section {
                    NavigationLink("Änderungsverlauf ansehen") {
                        AenderungsverlaufView(fahrt: fahrt)
                    }
                    .accessibilityHint("Zeigt alle bisherigen, protokollierten Änderungen an dieser Fahrt.")
                }
            }
            .navigationTitle("Fahrt bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                        .accessibilityLabel("Fertig")
                        .accessibilityHint("Schließt die Bearbeitung dieser Fahrt.")
                }
            }
            .sheet(item: $bearbeitetesFeld) { feld in
                FeldBearbeitenSheet(fahrt: fahrt, feld: feld, auditManager: auditManager)
            }
        }
    }

    private func bearbeitbareZeile(_ feld: FahrtAenderbaresFeld, wert: String) -> some View {
        Button {
            bearbeitetesFeld = feld
        } label: {
            LabeledContent(feld.rawValue, value: wert)
        }
        .accessibilityLabel("\(feld.rawValue): \(wert)")
        .accessibilityHint("Öffnet die Bearbeitung für „\(feld.rawValue)“ mit Pflichtangabe eines Änderungsgrunds.")
    }
}

/// Bearbeitet genau EIN Feld einer gesperrten Fahrt und verlangt dafür immer
/// einen Änderungsgrund. „Speichern“ bleibt deaktiviert, solange der Grund
/// leer ist. Die eigentliche Änderung läuft ausschließlich über
/// `AuditManager.aendereFahrt(...)`.
private struct FeldBearbeitenSheet: View {
    let fahrt: Fahrt
    let feld: FahrtAenderbaresFeld
    let auditManager: AuditManager

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Fahrzeug.name) private var fahrzeuge: [Fahrzeug]

    @State private var textWert: String
    @State private var datumWert: Date
    @State private var zweckWert: Fahrzweck
    @State private var fahrzeugIdWert: UUID?
    @State private var grund = ""
    @State private var fehlermeldung: String?

    init(fahrt: Fahrt, feld: FahrtAenderbaresFeld, auditManager: AuditManager) {
        self.fahrt = fahrt
        self.feld = feld
        self.auditManager = auditManager

        switch feld {
        case .startAdresse:
            _textWert = State(initialValue: fahrt.startAdresse)
        case .zielAdresse:
            _textWert = State(initialValue: fahrt.zielAdresse)
        case .kmStandStart:
            _textWert = State(initialValue: fahrt.kmStandStart.alsKilometerWert)
        case .kmStandEnde:
            _textWert = State(initialValue: fahrt.kmStandEnde.alsKilometerWert)
        case .zweckKonkret:
            _textWert = State(initialValue: fahrt.zweckKonkret)
        case .geschaeftspartner:
            _textWert = State(initialValue: fahrt.geschaeftspartner)
        case .notizen:
            _textWert = State(initialValue: fahrt.notizen ?? "")
        case .datum, .endDatum, .zweck, .fahrzeug:
            _textWert = State(initialValue: "")
        }

        _datumWert = State(initialValue: feld == .endDatum ? (fahrt.endDatum ?? fahrt.startDatum) : fahrt.startDatum)
        _zweckWert = State(initialValue: fahrt.zweck)
        _fahrzeugIdWert = State(initialValue: fahrt.fahrzeugId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(feld.rawValue) {
                    feldEditor
                }

                Section("Grund der Änderung") {
                    TextField("Grund der Änderung eingeben", text: $grund, axis: .vertical)
                        .accessibilityLabel("Grund der Änderung")
                        .accessibilityHint("Pflichtangabe. Ohne Grund kann diese Änderung nicht gespeichert werden.")
                }

                if let fehlermeldung {
                    Section {
                        Text(fehlermeldung)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(feld.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .accessibilityLabel("Abbrechen")
                        .accessibilityHint("Verwirft diese Änderung.")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                        .disabled(grund.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Speichern")
                        .accessibilityHint("Speichert die Änderung zusammen mit dem angegebenen Grund im Änderungsverlauf.")
                }
            }
        }
    }

    @ViewBuilder
    private var feldEditor: some View {
        switch feld {
        case .datum, .endDatum:
            DatePicker(feld.rawValue, selection: $datumWert, displayedComponents: .date)
        case .startAdresse:
            TextField(feld.rawValue, text: $textWert, prompt: Text("Straße, Postleitzahl, Ort"))
        case .zielAdresse:
            TextField(feld.rawValue, text: $textWert, prompt: Text("Straße, Postleitzahl, Ort"))
        case .kmStandStart, .kmStandEnde:
            TextField(feld.rawValue, text: $textWert)
                .keyboardType(.decimalPad)
        case .zweckKonkret:
            TextField(feld.rawValue, text: $textWert)
        case .geschaeftspartner:
            TextField(feld.rawValue, text: $textWert)
        case .notizen:
            TextField(feld.rawValue, text: $textWert, axis: .vertical)
        case .zweck:
            Picker(feld.rawValue, selection: $zweckWert) {
                ForEach(Fahrzweck.allCases) { eintrag in
                    Text(eintrag.anzeigeName).tag(eintrag)
                }
            }
        case .fahrzeug:
            Picker(feld.rawValue, selection: $fahrzeugIdWert) {
                ForEach(fahrzeuge) { fahrzeug in
                    Text(fahrzeug.name).tag(Optional(fahrzeug.id))
                }
            }
        }
    }

    private func speichern() {
        do {
            switch feld {
            case .datum:
                try commit(alt: fahrt.startDatum.alsKurzesDatum, neu: datumWert.alsKurzesDatum)
            case .endDatum:
                try commit(alt: (fahrt.endDatum ?? fahrt.startDatum).alsKurzesDatum, neu: datumWert.alsKurzesDatum)
            case .startAdresse:
                try pflichtfeld(textWert) { try commit(alt: fahrt.startAdresse, neu: $0) }
            case .zielAdresse:
                try pflichtfeld(textWert) { try commit(alt: fahrt.zielAdresse, neu: $0) }
            case .kmStandStart:
                try kmAendern(neuerText: textWert, istStart: true)
            case .kmStandEnde:
                try kmAendern(neuerText: textWert, istStart: false)
            case .zweck:
                try commit(alt: fahrt.zweck.anzeigeName, neu: zweckWert.anzeigeName)
            case .zweckKonkret:
                try pflichtfeld(textWert) { try commit(alt: fahrt.zweckKonkret, neu: $0) }
            case .geschaeftspartner:
                try commit(alt: fahrt.geschaeftspartner, neu: textWert.trimmingCharacters(in: .whitespacesAndNewlines))
            case .notizen:
                try commit(alt: fahrt.notizen ?? "", neu: textWert)
            case .fahrzeug:
                guard let neuesFahrzeug = fahrzeuge.first(where: { $0.id == fahrzeugIdWert }) else {
                    throw FeldFehler("Bitte ein Fahrzeug auswählen.")
                }
                let alterName = fahrzeuge.first(where: { $0.id == fahrt.fahrzeugId })?.name ?? "Unbekanntes Fahrzeug"
                try commit(alt: alterName, neu: neuesFahrzeug.name)
            }
            dismiss()
        } catch {
            fehlermeldung = error.localizedDescription
        }
    }

    private func pflichtfeld(_ wert: String, _ aktion: (String) throws -> Void) throws {
        let getrimmt = wert.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !getrimmt.isEmpty else {
            throw FeldFehler("Dieses Feld darf nicht leer sein.")
        }
        try aktion(getrimmt)
    }

    private func kmAendern(neuerText: String, istStart: Bool) throws {
        guard let neuerWert = FahrtValidierung.geparsterKilometerstand(neuerText) else {
            throw FeldFehler("Bitte einen gültigen Kilometerstand angeben.")
        }
        let andererWert = istStart ? fahrt.kmStandEnde : fahrt.kmStandStart
        let bleibtGueltig = istStart ? (andererWert > neuerWert) : (neuerWert > andererWert)
        guard bleibtGueltig else {
            throw FeldFehler("Der Tachostand bei Fahrtende muss größer sein als bei Fahrtbeginn.")
        }
        let alterWert = istStart ? fahrt.kmStandStart : fahrt.kmStandEnde
        try commit(alt: alterWert.alsKilometerWert, neu: neuerWert.alsKilometerWert)
    }

    private func commit(alt: String, neu: String) throws {
        try auditManager.aendereFahrt(fahrt: fahrt, feld: feld, alterWert: alt, neuerWert: neu, grund: grund)
    }
}

/// Kleiner, lokaler Fehlertyp für Eingabeprobleme innerhalb von
/// `FeldBearbeitenSheet`, bevor überhaupt `AuditManager` aufgerufen wird.
private struct FeldFehler: LocalizedError {
    let nachricht: String
    init(_ nachricht: String) { self.nachricht = nachricht }
    var errorDescription: String? { nachricht }
}

#Preview {
    FahrtBearbeitenView(
        fahrt: try! Fahrt(
            startDatum: .now,
            endDatum: .now,
            startAdresse: "Musterstraße 1, 12345 Musterstadt",
            zielAdresse: "Beispielweg 2, 54321 Beispielstadt",
            kmStandStart: 1000,
            kmStandEnde: 1050,
            zweck: .kunde,
            zweckKonkret: "Projektbesprechung Musterfirma",
            geschaeftspartner: "Musterfirma GmbH",
            fahrzeugId: UUID()
        )
    )
    .modelContainer(for: [Fahrzeug.self, Fahrt.self, AuditEntry.self], inMemory: true)
}
