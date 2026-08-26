import SwiftData
import SwiftUI

/// Vollständiger, read-only Änderungsverlauf einer Fahrt in chronologischer
/// Reihenfolge (älteste Änderung zuerst).
///
/// Es gibt bewusst keinen Bearbeiten- oder Löschen-Button: `AuditEntry` ist
/// append-only, jeder Eintrag bleibt exakt so lesbar, wie er entstanden ist.
struct AenderungsverlaufView: View {
    @Query private var verlauf: [AuditEntry]

    init(fahrt: Fahrt) {
        let fahrtId = fahrt.id
        _verlauf = Query(
            filter: #Predicate<AuditEntry> { $0.fahrtId == fahrtId },
            sort: [SortDescriptor(\AuditEntry.zeitstempel, order: .forward)]
        )
    }

    var body: some View {
        Group {
            if verlauf.isEmpty {
                ContentUnavailableView(
                    "Noch keine Änderungen protokolliert",
                    systemImage: "clock.badge.checkmark",
                    description: Text("Diese Fahrt wurde seit dem Speichern nicht verändert.")
                )
            } else {
                List(verlauf) { eintrag in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(eintrag.zeitstempel.alsKurzesDatum)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(eintrag.feldName)
                            .font(.headline)
                        Text("„\(eintrag.alterWert)“ → „\(eintrag.neuerWert)“")
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Grund: \(eintrag.grund)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Originalwert bleibt nachvollziehbar")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(eintrag.zusammenfassung). Originalwert bleibt nachvollziehbar.")
                }
                .accessibilityHint("Liste aller protokollierten Änderungen dieser Fahrt, chronologisch von der ältesten zur neuesten.")
            }
        }
        .navigationTitle("Änderungsverlauf")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AenderungsverlaufView(
            fahrt: try! Fahrt(
                startDatum: .now,
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
    }
    .modelContainer(for: [Fahrzeug.self, Fahrt.self, AuditEntry.self], inMemory: true)
}
