import SwiftUI

/// Platzhalter für die Bearbeitung einer bereits gespeicherten (gesperrten)
/// Fahrt über den Audit-Prozess.
///
/// Der eigentliche Korrektur-Fluss (Änderungsgrund erfassen, `AuditEntry`
/// erzeugen – siehe `Fahrt.aendereGesperrtesFeld(...)` in `Models/Fahrt.swift`)
/// ist bewusst NICHT Teil dieses Prompts und folgt in Prompt 5. Dieser
/// Platzhalter stellt sicher, dass „Fahrt bearbeiten“ aus `FahrtDetailView`
/// bereits jetzt in einen kompilierbaren, HIG-konformen Bildschirm führt.
struct FahrtBearbeitenView: View {
    let fahrt: Fahrt

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Bearbeitung folgt", systemImage: "pencil.and.list.clipboard")
            } description: {
                Text("Die nachträgliche Bearbeitung gespeicherter Fahrten über den Audit-Prozess folgt in einem späteren Ausbauschritt. Jede Änderung wird dann zusammen mit dem ursprünglichen Wert und einer Begründung im Änderungsverlauf dieser Fahrt festgehalten.")
            }
            .navigationTitle("Fahrt bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .accessibilityLabel("Schließen")
                        .accessibilityHint("Schließt den Platzhalter für die Fahrt-Bearbeitung.")
                }
            }
        }
    }
}

#Preview {
    FahrtBearbeitenView(
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
