import SwiftUI
import SwiftData

/// Feste, projektweite Konfigurationswerte für die Einstellungen-Ansicht.
///
/// PLATZHALTER: `supportEMail` und `datenschutzURL` sind Beispielwerte und
/// müssen vor einer Veröffentlichung durch die echten, geprüften Werte des
/// Anbieters ersetzt werden. Ist `datenschutzURL` `nil` (Standard), verlinkt
/// „Datenschutz“ auf die lokale `DatenschutzView`; ist eine URL gesetzt, wird
/// stattdessen diese externe Seite geöffnet.
enum AppKonfiguration {
    /// PLATZHALTER – durch die echte Support-Adresse ersetzen.
    static let supportEMail = "support@beispiel-firma.de"

    /// PLATZHALTER – bei Bedarf durch eine echte, gehostete Datenschutzerklärung ersetzen.
    static let datenschutzURL: URL? = nil

    static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let build {
            return "\(version) (\(build))"
        }
        return version
    }
}

/// Einstellungen: Fahrzeugverwaltung, Kilometersätze (read-only), Hilfe-Links
/// und Angaben über die App.
struct EinstellungenView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Fahrzeug.name) private var fahrzeuge: [Fahrzeug]

    @State private var neuesFahrzeug: Bool = false
    @State private var zuBearbeitendesFahrzeug: Fahrzeug?
    @State private var proManager = ProManager()
    @State private var zeigePaywall = false

    var body: some View {
        Form {
            Section("Fahrzeuge") {
                if fahrzeuge.isEmpty {
                    Text("Noch kein Fahrzeug angelegt.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                ForEach(fahrzeuge) { fahrzeug in
                    Button {
                        zuBearbeitendesFahrzeug = fahrzeug
                    } label: {
                        VStack(alignment: .leading) {
                            Text(fahrzeug.name)
                                .font(.body)
                            Text("\(fahrzeug.kennzeichen) · \(fahrzeug.typ.anzeigeName)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("\(fahrzeug.name) bearbeiten")
                    .accessibilityHint("Öffnet die Bearbeitung für dieses Fahrzeug.")
                }

                Button {
                    fahrzeugHinzufuegenAnfordern()
                } label: {
                    Label("Fahrzeug hinzufügen", systemImage: "plus")
                }
                .accessibilityLabel("Fahrzeug hinzufügen")
                .accessibilityHint(
                    proManager.isFeatureAvailable(.mehrereFahrzeuge) || fahrzeuge.isEmpty
                        ? "Öffnet ein Formular, um ein neues Fahrzeug anzulegen."
                        : "Öffnet KilometerLog Pro. Ohne Pro ist nur ein Fahrzeug nutzbar."
                )

                if !proManager.isFeatureAvailable(.mehrereFahrzeuge) && !fahrzeuge.isEmpty {
                    Text("Weitere Fahrzeuge sind Teil von KilometerLog Pro.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Pkw", value: "\(FahrtkostenRechner.pkwSatzProKm.alsEuroBetrag)/km")
                LabeledContent("Motorrad", value: "\(FahrtkostenRechner.motorradSatzProKm.alsEuroBetrag)/km")
            }

            Section("Hilfe") {
                NavigationLink("Fahrtenbuch-Leitfaden") {
                    LeitfadenView()
                }
                NavigationLink("Rechtlicher Hinweis") {
                    RechtlicherHinweisView()
                }
            }

            Section("Über die App") {
                if let datenschutzURL = AppKonfiguration.datenschutzURL {
                    Link("Datenschutz", destination: datenschutzURL)
                } else {
                    NavigationLink("Datenschutz") {
                        DatenschutzView()
                    }
                }

                LabeledContent("Version", value: AppKonfiguration.appVersion)

                if let mailURL = URL(string: "mailto:\(AppKonfiguration.supportEMail)") {
                    Link(destination: mailURL) {
                        LabeledContent("Support", value: AppKonfiguration.supportEMail)
                    }
                    .accessibilityLabel("Support kontaktieren")
                    .accessibilityHint("Öffnet die Mail-App, um eine Nachricht an den Support zu schreiben.")
                } else {
                    LabeledContent("Support", value: AppKonfiguration.supportEMail)
                }
            }
        }
        .navigationTitle("Einstellungen")
        .sheet(isPresented: $neuesFahrzeug) {
            FahrzeugView(fahrzeug: nil)
        }
        .sheet(item: $zuBearbeitendesFahrzeug) { fahrzeug in
            FahrzeugView(fahrzeug: fahrzeug)
        }
        .sheet(isPresented: $zeigePaywall) {
            PaywallView(proManager: proManager)
        }
        .task {
            await proManager.aktualisiereStatus()
        }
    }

    /// Ohne Pro bleibt es bei genau einem Fahrzeug (Feature
    /// `.mehrereFahrzeuge`); bestehende Fahrzeuge bleiben davon unberührt –
    /// nur das Anlegen eines weiteren verlangt Pro.
    private func fahrzeugHinzufuegenAnfordern() {
        if proManager.isFeatureAvailable(.mehrereFahrzeuge) || fahrzeuge.isEmpty {
            neuesFahrzeug = true
        } else {
            zeigePaywall = true
        }
    }
}

#Preview {
    NavigationStack {
        EinstellungenView()
    }
    .modelContainer(for: [Fahrzeug.self, Fahrt.self, AuditEntry.self], inMemory: true)
}
