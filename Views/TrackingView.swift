import CoreLocation
import MapKit
import SwiftUI
import UIKit

/// Vollbild-Screen für eine aktive GPS-Aufzeichnung.
///
/// Ablauf: (1) Ohne Vordergrund-Berechtigung wird zunächst eine
/// verständliche Erklärung gezeigt, bevor die Systemabfrage ausgelöst wird.
/// (2) Sobald die Berechtigung vorliegt, startet die Aufzeichnung
/// automatisch. (3) Während der Aufzeichnung kann optional – mit eigener
/// Erklärung – die Hintergrundberechtigung nachgefordert werden, damit die
/// Fahrt bei gesperrtem Bildschirm weiterläuft. (4) Nach „Fahrt beenden“
/// öffnet sich als weiteres Sheet das Bestätigungsformular
/// (`ManuelleFahrtView`) für Pflichtfelder und Tachostände; sobald es
/// geschlossen wird, schließt sich auch dieser Aufzeichnungs-Bildschirm.
struct TrackingView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var permissionCoordinator = LocationPermissionCoordinator()
    @State private var trackingManager = TrackingManager()

    @State private var zeigeHintergrundErklaerung = false
    @State private var zeigeAbbrechenBestaetigung = false
    @State private var ergebnis: TrackingErgebnis?

    var body: some View {
        NavigationStack {
            Group {
                if !permissionCoordinator.hatVordergrundBerechtigung {
                    berechtigungsAnsicht
                } else {
                    aufzeichnungsAnsicht
                }
            }
        }
        .interactiveDismissDisabled(trackingManager.isTracking)
        .onAppear { starteFallsBerechtigt() }
        .onChange(of: permissionCoordinator.status) { _, _ in starteFallsBerechtigt() }
        // Eigenes Sheet statt Einbettung in dieselbe NavigationStack: Da
        // `ManuelleFahrtView` bereits ihre eigene `NavigationStack` mitbringt
        // (für den Fall der eigenständigen Nutzung aus `FahrtenListView`),
        // würde eine Einbettung hier zu einer verschachtelten
        // NavigationStack führen. `onDisappear` schließt zusätzlich diesen
        // Aufzeichnungs-Bildschirm, sobald die Bestätigung – ob gespeichert
        // oder abgebrochen – geschlossen wird.
        .sheet(item: $ergebnis) { ergebnis in
            ManuelleFahrtView(vorbefuellung: ergebnis)
                .onDisappear { dismiss() }
        }
    }

    private func starteFallsBerechtigt() {
        guard ergebnis == nil, !trackingManager.isTracking else { return }
        if permissionCoordinator.hatVordergrundBerechtigung {
            trackingManager.startTracking()
        }
    }

    // MARK: - Berechtigungs-Erklärung

    private var berechtigungsAnsicht: some View {
        ContentUnavailableView {
            Label("Standortzugriff erforderlich", systemImage: "location.fill")
        } description: {
            Text(LocationPermissionCoordinator.vordergrundErklaerung)
        } actions: {
            if permissionCoordinator.istEndgueltigAbgelehnt {
                Button("Einstellungen öffnen") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Einstellungen öffnen")
                .accessibilityHint("Öffnet die Systemeinstellungen, um KilometerLog den Standortzugriff zu erlauben.")
            } else {
                Button("Standortzugriff erlauben") {
                    permissionCoordinator.fordereVordergrundBerechtigungAn()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Standortzugriff erlauben")
                .accessibilityHint("Fragt die Berechtigung an, deinen Standort während einer Fahrt zu verwenden.")
            }
        }
        .navigationTitle("Fahrt starten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
                    .accessibilityLabel("Abbrechen")
                    .accessibilityHint("Schließt den Bildschirm, ohne eine Fahrt aufzuzeichnen.")
            }
        }
    }

    // MARK: - Aktive Aufzeichnung

    private var aufzeichnungsAnsicht: some View {
        VStack(spacing: 20) {
            if !permissionCoordinator.hatHintergrundBerechtigung {
                hintergrundHinweis
            }

            VStack(spacing: 4) {
                Text("\(trackingManager.aktuelleKm.alsKilometerWert) km")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Text("aufgezeichnete Strecke")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(trackingManager.aktuelleKm.alsKilometerWert) Kilometer aufgezeichnet")

            signalAnzeige

            if trackingManager.vorschauPunkte.count > 1 {
                KartenVorschau(punkte: trackingManager.vorschauPunkte)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Start")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(trackingManager.startAdresse ?? "Wird ermittelt …")
                    .font(.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .accessibilityElement(children: .combine)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    ergebnis = trackingManager.stopTracking()
                } label: {
                    Text("Fahrt beenden")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel("Fahrt beenden")
                .accessibilityHint("Beendet die Aufzeichnung und öffnet die Bestätigung der Kilometerstände.")

                Button(role: .destructive) {
                    zeigeAbbrechenBestaetigung = true
                } label: {
                    Text("Abbrechen")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityLabel("Abbrechen")
                .accessibilityHint("Verwirft die laufende Aufzeichnung, ohne eine Fahrt zu speichern.")
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top)
        .navigationTitle("Fahrt läuft")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Aufzeichnung wirklich abbrechen?",
            isPresented: $zeigeAbbrechenBestaetigung,
            titleVisibility: .visible
        ) {
            Button("Aufzeichnung verwerfen", role: .destructive) {
                trackingManager.stopTracking()
                dismiss()
            }
            Button("Weiter aufzeichnen", role: .cancel) {}
        } message: {
            Text("Die bisher aufgezeichnete Strecke von \(trackingManager.aktuelleKm.alsKilometerWert) km geht dabei verloren.")
        }
        .sheet(isPresented: $zeigeHintergrundErklaerung) {
            hintergrundErklaerungsSheet
        }
    }

    private var signalAnzeige: some View {
        Label(trackingManager.signalStatus.anzeigeName, systemImage: signalSymbol)
            .font(.subheadline)
            .foregroundStyle(signalFarbe)
    }

    private var signalSymbol: String {
        switch trackingManager.signalStatus {
        case .suche: return "location.circle"
        case .gut: return "location.fill"
        case .schwach: return "location.slash"
        case .verloren: return "exclamationmark.triangle.fill"
        }
    }

    private var signalFarbe: Color {
        switch trackingManager.signalStatus {
        case .suche: return .secondary
        case .gut: return .green
        case .schwach: return .orange
        case .verloren: return .red
        }
    }

    private var hintergrundHinweis: some View {
        Button {
            zeigeHintergrundErklaerung = true
        } label: {
            Label("Nur im Vordergrund aktiv – zum Erweitern tippen", systemImage: "info.circle")
                .font(.footnote)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.orange)
        .accessibilityLabel("Hinweis: Aufzeichnung nur im Vordergrund aktiv")
        .accessibilityHint("Öffnet Informationen zur Hintergrundaufzeichnung bei gesperrtem Bildschirm.")
    }

    private var hintergrundErklaerungsSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(LocationPermissionCoordinator.hintergrundErklaerung)
                    .font(.body)
                Button("Immer erlauben") {
                    permissionCoordinator.fordereHintergrundBerechtigungAn()
                    zeigeHintergrundErklaerung = false
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Hintergrundaufzeichnung immer erlauben")
                .accessibilityHint("Öffnet die Systemabfrage für die Berechtigung „Immer“.")
                Spacer()
            }
            .padding()
            .navigationTitle("Hintergrundaufzeichnung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { zeigeHintergrundErklaerung = false }
                        .accessibilityLabel("Schließen")
                }
            }
        }
    }
}

/// Zeigt die bisherige Strecke der aktiven Session als flüchtige Polyline.
/// Die Punkte kommen direkt aus `TrackingManager.vorschauPunkte` (In-Memory)
/// und werden nirgends gespeichert oder aus dieser Ansicht heraus exportiert.
private struct KartenVorschau: View {
    let punkte: [CLLocation]

    var body: some View {
        Map {
            MapPolyline(coordinates: punkte.map(\.coordinate))
                .stroke(.blue, lineWidth: 4)
        }
    }
}

#Preview {
    TrackingView()
}
