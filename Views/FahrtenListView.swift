import SwiftUI
import SwiftData

/// Zeigt alle erfassten Fahrten, neueste zuerst. Bietet den Einstieg in die
/// manuelle Erfassung („Neue Fahrt“) und die automatische Aufzeichnung
/// („Fahrt starten“).
struct FahrtenListView: View {
    @Query(sort: \Fahrt.startDatum, order: .reverse) private var fahrten: [Fahrt]
    @Query private var fahrzeuge: [Fahrzeug]

    @State private var suchtext = ""
    @State private var zeigeNeueFahrt = false
    @State private var zeigeAufzeichnung = false
    @State private var proManager = ProManager()
    @State private var zeigePaywall = false

    private var fahrzeugeNachId: [UUID: Fahrzeug] {
        Dictionary(uniqueKeysWithValues: fahrzeuge.map { ($0.id, $0) })
    }

    /// Grundlage für das Free-Limit „bis 10 Fahrten pro Monat“ – bestehende
    /// Fahrten werden dabei nie gelöscht oder unsichtbar gemacht, nur das
    /// Anlegen einer weiteren Fahrt im selben Kalendermonat verlangt Pro.
    private var fahrtenDiesenMonat: Int {
        let jetzt = Date.now
        let kalender = Calendar.current
        return fahrten.filter {
            kalender.isDate($0.startDatum, equalTo: jetzt, toGranularity: .month)
                && kalender.isDate($0.startDatum, equalTo: jetzt, toGranularity: .year)
        }.count
    }

    private var gefilterteFahrten: [Fahrt] {
        guard !suchtext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fahrten
        }
        let suche = suchtext.localizedLowercase
        return fahrten.filter { fahrt in
            fahrt.startAdresse.localizedLowercase.contains(suche)
                || fahrt.zielAdresse.localizedLowercase.contains(suche)
                || fahrt.zweckKonkret.localizedLowercase.contains(suche)
                || fahrt.geschaeftspartner.localizedLowercase.contains(suche)
        }
    }

    var body: some View {
        Group {
            if fahrten.isEmpty {
                FahrtenEmptyStateView()
            } else if gefilterteFahrten.isEmpty {
                ContentUnavailableView.search(text: suchtext)
            } else {
                List {
                    ForEach(gefilterteFahrten) { fahrt in
                        NavigationLink {
                            FahrtDetailView(fahrt: fahrt)
                        } label: {
                            FahrtZeile(fahrt: fahrt, fahrzeug: fahrzeugeNachId[fahrt.fahrzeugId])
                        }
                    }
                }
                .accessibilityHint("Liste aller erfassten Fahrten, neueste zuerst. Zum Öffnen der Details antippen.")
            }
        }
        .navigationTitle("Fahrten")
        .searchable(text: $suchtext, prompt: "Fahrten suchen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    neueFahrtAnfordern()
                } label: {
                    Label("Neue Fahrt", systemImage: "plus")
                }
                .accessibilityLabel("Neue Fahrt")
                .accessibilityHint("Öffnet ein Formular, um eine Fahrt manuell zu erfassen.")
            }
        }
        .safeAreaInset(edge: .top) {
            if !proManager.isFeatureAvailable(.unbegrenzteFahrten) && fahrtenDiesenMonat >= ProManager.freiesLimitFahrtenProMonat {
                Button {
                    zeigePaywall = true
                } label: {
                    Label("Mit Pro unbegrenzt dokumentieren", systemImage: "star.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding([.horizontal, .top])
                .accessibilityLabel("Mit Pro unbegrenzt dokumentieren")
                .accessibilityHint("Das monatliche Free-Limit von \(ProManager.freiesLimitFahrtenProMonat) Fahrten ist erreicht. Öffnet KilometerLog Pro, um es aufzuheben.")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                aufzeichnungAnfordern()
            } label: {
                Label("Fahrt starten", systemImage: "location.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .accessibilityLabel("Fahrt starten")
            .accessibilityHint("Startet die automatische Aufzeichnung einer neuen Fahrt.")
        }
        .sheet(isPresented: $zeigeNeueFahrt) {
            ManuelleFahrtView()
        }
        .sheet(isPresented: $zeigeAufzeichnung) {
            TrackingView()
        }
        .sheet(isPresented: $zeigePaywall) {
            PaywallView(proManager: proManager)
        }
        .task {
            await proManager.aktualisiereStatus()
        }
    }

    /// Öffnet „Neue Fahrt“ nur, wenn das Free-Limit noch nicht erreicht ist
    /// oder Pro aktiv ist – andernfalls die Paywall statt des Formulars.
    /// Bestehende Fahrten sind davon nie betroffen.
    private func neueFahrtAnfordern() {
        if proManager.darfWeitereFahrtAnlegen(fahrtenDiesenMonat: fahrtenDiesenMonat) {
            zeigeNeueFahrt = true
        } else {
            zeigePaywall = true
        }
    }

    /// Dieselbe Free-Limit-Prüfung wie bei „Neue Fahrt“: Eine per GPS
    /// aufgezeichnete Fahrt mündet ebenfalls in einer neuen, gespeicherten
    /// Fahrt und zählt daher genauso gegen das monatliche Limit.
    private func aufzeichnungAnfordern() {
        if proManager.darfWeitereFahrtAnlegen(fahrtenDiesenMonat: fahrtenDiesenMonat) {
            zeigeAufzeichnung = true
        } else {
            zeigePaywall = true
        }
    }
}

/// Eine Zeile der Fahrtenliste mit Datum, Strecke, Kilometern, berechnetem
/// Erstattungsbetrag, Zweck und Geschäftspartner. Zeigt niemals „privat“,
/// da `Fahrzweck` keinen solchen Fall kennt.
private struct FahrtZeile: View {
    let fahrt: Fahrt
    let fahrzeug: Fahrzeug?

    private var betrag: Double {
        FahrtkostenRechner.berechne(km: fahrt.km, fahrzeugTyp: fahrzeug?.typ ?? .sonstiges)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(fahrt.startDatum.alsKurzesDatum)
                    .font(.headline)
                Spacer()
                Text(betrag.alsEuroBetrag)
                    .font(.headline)
            }

            Text("\(fahrt.startAdresse) → \(fahrt.zielAdresse)")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Text("\(fahrt.km.alsKilometerWert) km")
                Text("·")
                Text(fahrt.zweck.anzeigeName)
                if !fahrt.geschaeftspartner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("·")
                    Text(fahrt.geschaeftspartner)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Öffnet die Details dieser Fahrt.")
    }
}

#Preview {
    NavigationStack {
        FahrtenListView()
    }
    .modelContainer(for: [Fahrzeug.self, Fahrt.self, AuditEntry.self], inMemory: true)
}
