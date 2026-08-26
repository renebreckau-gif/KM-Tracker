import SwiftUI
import SwiftData

/// Detailansicht einer einzelnen Fahrt. Macht sichtbar, ob die Fahrt
/// gesperrt ist, und zeigt den vollständigen, unveränderlichen
/// Änderungsverlauf (`AuditEntry`) dieser Fahrt.
struct FahrtDetailView: View {
    let fahrt: Fahrt

    @Query private var fahrzeuge: [Fahrzeug]
    @Query private var verlauf: [AuditEntry]

    init(fahrt: Fahrt) {
        self.fahrt = fahrt
        let fahrtId = fahrt.id
        _verlauf = Query(
            filter: #Predicate<AuditEntry> { $0.fahrtId == fahrtId },
            sort: [SortDescriptor(\AuditEntry.zeitstempel, order: .reverse)]
        )
    }

    private var fahrzeug: Fahrzeug? {
        fahrzeuge.first { $0.id == fahrt.fahrzeugId }
    }

    private var betrag: Double {
        FahrtkostenRechner.berechne(km: fahrt.km, fahrzeugTyp: fahrzeug?.typ ?? .sonstiges)
    }

    var body: some View {
        Form {
            Section("Status") {
                Label(
                    fahrt.isLocked ? "Gespeichert und geschützt" : "Noch nicht gesperrt",
                    systemImage: fahrt.isLocked ? "lock.fill" : "lock.open.fill"
                )
                .foregroundStyle(fahrt.isLocked ? .secondary : .orange)
                if fahrt.isLocked {
                    Text("Änderungen an dieser Fahrt sind nur noch über den Audit-Prozess möglich, damit die Historie lückenlos nachvollziehbar bleibt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    NavigationLink("Fahrt bearbeiten") {
                        FahrtBearbeitenView(fahrt: fahrt)
                    }
                    .accessibilityHint("Öffnet die Bearbeitung dieser Fahrt über den Audit-Prozess.")
                }
            }

            Section("Strecke") {
                LabeledContent("Datum", value: fahrt.startDatum.alsKurzesDatum)
                if let endDatum = fahrt.endDatum, !Calendar.current.isDate(endDatum, inSameDayAs: fahrt.startDatum) {
                    LabeledContent("Ende", value: endDatum.alsKurzesDatum)
                }
                LabeledContent("Start-Adresse", value: fahrt.startAdresse)
                LabeledContent("Ziel-Adresse", value: fahrt.zielAdresse)
                LabeledContent("Tachostand bei Fahrtbeginn", value: "\(fahrt.kmStandStart.alsKilometerWert) km")
                LabeledContent("Tachostand bei Fahrtende", value: "\(fahrt.kmStandEnde.alsKilometerWert) km")
                LabeledContent("Gefahrene Kilometer", value: "\(fahrt.km.alsKilometerWert) km")
                LabeledContent("Erstattungsbetrag", value: betrag.alsEuroBetrag)
            }

            Section("Anlass") {
                LabeledContent("Zweck", value: fahrt.zweck.anzeigeName)
                LabeledContent("Konkreter Zweck", value: fahrt.zweckKonkret)
                if !fahrt.geschaeftspartner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LabeledContent("Geschäftspartner", value: fahrt.geschaeftspartner)
                }
                if let notizen = fahrt.notizen, !notizen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LabeledContent("Notizen", value: notizen)
                }
            }

            Section("Änderungsverlauf") {
                if verlauf.isEmpty {
                    Text("Keine nachträglichen Änderungen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(verlauf) { eintrag in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(eintrag.feldName)
                                .font(.subheadline)
                            Text("„\(eintrag.alterWert)“ → „\(eintrag.neuerWert)“")
                                .font(.body)
                            Text(eintrag.grund)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(eintrag.zeitstempel.alsKurzesDatum)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .navigationTitle("Fahrt")
        .navigationBarTitleDisplayMode(.inline)
    }
}
