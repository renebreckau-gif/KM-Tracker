import SwiftData
import SwiftUI

/// Formular zum Anlegen oder Bearbeiten eines Fahrzeugs.
///
/// Ein bestehendes Fahrzeug kann nur gelöscht werden, wenn keine Fahrt mehr
/// über `fahrzeugId` darauf verweist – sonst würden diese Fahrten ihren
/// Fahrzeugbezug (und damit den korrekten Kilometersatz sowie die Anzeige
/// in Liste/Übersicht) verlieren. In diesem Fall zeigt die Ansicht eine
/// verständliche Warnung statt der Löschen-Aktion.
struct FahrzeugView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var alleFahrten: [Fahrt]

    /// `nil` bedeutet: neues Fahrzeug anlegen. Ansonsten wird dieses
    /// bestehende Fahrzeug bearbeitet.
    let fahrzeug: Fahrzeug?

    @State private var name: String
    @State private var kennzeichen: String
    @State private var typ: FahrzeugTyp
    @State private var fehlermeldung: String?
    @State private var zeigeLoeschenBestaetigung = false

    @FocusState private var nameFokussiert: Bool

    init(fahrzeug: Fahrzeug? = nil) {
        self.fahrzeug = fahrzeug
        _name = State(initialValue: fahrzeug?.name ?? "")
        _kennzeichen = State(initialValue: fahrzeug?.kennzeichen ?? "")
        _typ = State(initialValue: fahrzeug?.typ ?? .pkw)
    }

    private var zugehoerigeFahrtenAnzahl: Int {
        guard let fahrzeug else { return 0 }
        return alleFahrten.filter { $0.fahrzeugId == fahrzeug.id }.count
    }

    private var istGueltig: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !kennzeichen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Fahrzeug") {
                    TextField("Name", text: $name)
                        .focused($nameFokussiert)
                    TextField("Kennzeichen", text: $kennzeichen)
                        .textInputAutocapitalization(.characters)
                    Picker("Typ", selection: $typ) {
                        ForEach(FahrzeugTyp.allCases) { eintrag in
                            Text(eintrag.anzeigeName).tag(eintrag)
                        }
                    }
                }

                if let fehlermeldung {
                    Section {
                        Text(fehlermeldung)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if fahrzeug != nil {
                    Section {
                        if zugehoerigeFahrtenAnzahl > 0 {
                            Label(
                                "Dieses Fahrzeug ist \(zugehoerigeFahrtenAnzahl) Fahrt\(zugehoerigeFahrtenAnzahl == 1 ? "" : "en") zugeordnet und kann deshalb nicht gelöscht werden, ohne diese Fahrten unbrauchbar zu machen. Ordne die betroffenen Fahrten zuerst einem anderen Fahrzeug zu.",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Löschen nicht möglich: \(zugehoerigeFahrtenAnzahl) Fahrt\(zugehoerigeFahrtenAnzahl == 1 ? "" : "en") zugeordnet.")
                        } else {
                            Button("Fahrzeug löschen", role: .destructive) {
                                zeigeLoeschenBestaetigung = true
                            }
                            .accessibilityLabel("Fahrzeug löschen")
                            .accessibilityHint("Löscht dieses Fahrzeug endgültig. Diesem Fahrzeug sind keine Fahrten zugeordnet.")
                        }
                    }
                }
            }
            .navigationTitle(fahrzeug == nil ? "Fahrzeug hinzufügen" : "Fahrzeug bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .accessibilityLabel("Abbrechen")
                        .accessibilityHint("Verwirft die Eingaben und schließt das Formular.")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                        .disabled(!istGueltig)
                        .accessibilityLabel("Speichern")
                        .accessibilityHint("Speichert das Fahrzeug.")
                }
            }
            .onAppear { nameFokussiert = fahrzeug == nil }
            .confirmationDialog(
                "Fahrzeug wirklich löschen?",
                isPresented: $zeigeLoeschenBestaetigung,
                titleVisibility: .visible
            ) {
                Button("Löschen", role: .destructive) { loeschen() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Diese Aktion kann nicht rückgängig gemacht werden.")
            }
        }
    }

    private func speichern() {
        let getrimmterName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let getrimmtesKennzeichen = kennzeichen.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !getrimmterName.isEmpty, !getrimmtesKennzeichen.isEmpty else {
            fehlermeldung = "Name und Kennzeichen dürfen nicht leer sein."
            return
        }

        if let fahrzeug {
            fahrzeug.name = getrimmterName
            fahrzeug.kennzeichen = getrimmtesKennzeichen
            fahrzeug.typ = typ
        } else {
            let neuesFahrzeug = Fahrzeug(name: getrimmterName, kennzeichen: getrimmtesKennzeichen, typ: typ)
            modelContext.insert(neuesFahrzeug)
        }

        dismiss()
    }

    private func loeschen() {
        guard let fahrzeug, zugehoerigeFahrtenAnzahl == 0 else { return }
        modelContext.delete(fahrzeug)
        dismiss()
    }
}

#Preview {
    FahrzeugView()
        .modelContainer(for: [Fahrzeug.self, Fahrt.self, AuditEntry.self], inMemory: true)
}
