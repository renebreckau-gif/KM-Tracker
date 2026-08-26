import Charts
import SwiftData
import SwiftUI

/// Kennzahlen-Übersicht: Kopfbereich mit rechtlichem Einordnungshinweis,
/// Jahres- und Monatswerte, Aufschlüsselung nach Zweck/Fahrzeug, ein
/// Balkendiagramm der letzten sechs Monate sowie der (noch als Platzhalter
/// verdrahtete) Datenexport.
///
/// Alle Beträge werden ausschließlich über `StatistikBerechnung` ermittelt,
/// die ihrerseits ausschließlich `FahrtkostenRechner.berechne(...)`
/// verwendet – diese Ansicht kennt selbst keine Kilometersätze.
struct UebersichtView: View {
    @Query private var fahrten: [Fahrt]
    @Query(sort: \Fahrzeug.name) private var fahrzeuge: [Fahrzeug]

    @State private var ausgewaehltesJahr = Calendar.current.component(.year, from: .now)
    @State private var proManager = ProManager()
    @State private var zeigePaywall = false
    @State private var zeigeExportFehler = false
    @State private var exportFehlerText = ""

    private enum ExportFormat {
        case pdf, csv, datev
    }

    private var verfuegbareJahre: [Int] {
        let jahreMitFahrten = Set(fahrten.map { Calendar.current.component(.year, from: $0.startDatum) })
        let aktuellesJahr = Calendar.current.component(.year, from: .now)
        return Array(jahreMitFahrten.union([aktuellesJahr])).sorted(by: >)
    }

    private var jahresFahrten: [Fahrt] {
        fahrten.filter { Calendar.current.component(.year, from: $0.startDatum) == ausgewaehltesJahr }
    }

    private var jahresWert: StatistikWert {
        StatistikBerechnung.wert(fuer: jahresFahrten, fahrzeuge: fahrzeuge)
    }

    private var monatsWert: StatistikWert {
        StatistikBerechnung.monatsWert(fahrten: fahrten, fahrzeuge: fahrzeuge)
    }

    private var nachZweck: [ZweckStatistik] {
        StatistikBerechnung.nachZweck(fahrten: jahresFahrten, fahrzeuge: fahrzeuge)
    }

    private var nachFahrzeug: [FahrzeugStatistik] {
        StatistikBerechnung.nachFahrzeug(fahrten: jahresFahrten, fahrzeuge: fahrzeuge)
    }

    private var sechsMonate: [MonatsKilometer] {
        StatistikBerechnung.letzteSechsMonate(fahrten: fahrten)
    }

    var body: some View {
        Form {
            headerSection
            jahresSection
            monatsSection
            nachZweckSection
            nachFahrzeugSection
            diagrammSection
            exportSection
            hinweisSection
        }
        .navigationTitle("Übersicht")
        .sheet(isPresented: $zeigePaywall) {
            PaywallView()
        }
        .alert("Export nicht möglich", isPresented: $zeigeExportFehler) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportFehlerText)
        }
    }

    // MARK: - Kopfbereich

    /// Wird unabhängig vom Datenbestand immer angezeigt – auch bei leerer
    /// Fahrtenliste – und verspricht bewusst keine Anerkennung durch das
    /// Finanzamt, sondern beschreibt nur die Arbeitsweise der App.
    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Entspricht den Anforderungen an ein ordnungsgemäßes elektronisches Fahrtenbuch")
                    .font(.headline)
                Text("Die App ist ein Hilfsmittel und ersetzt keine Steuerberatung.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                NavigationLink("Rechtlichen Hinweis lesen") {
                    RechtlicherHinweisView()
                }
                .font(.footnote)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Jahreswerte

    private var jahresSection: some View {
        Section("Steuerjahr") {
            Picker("Jahr", selection: $ausgewaehltesJahr) {
                ForEach(verfuegbareJahre, id: \.self) { jahr in
                    Text(String(jahr)).tag(jahr)
                }
            }
            .accessibilityHint("Wählt das Jahr, für das Kennzahlen und Aufschlüsselungen angezeigt werden.")

            HStack(spacing: 12) {
                StatistikKarte(titel: "Kilometer", wert: "\(jahresWert.km.alsKilometerWert) km", systemImage: "road.lanes")
                StatistikKarte(titel: "Betrag", wert: jahresWert.betrag.alsEuroBetrag, systemImage: "eurosign.circle")
                StatistikKarte(titel: "Fahrten", wert: "\(jahresWert.anzahlFahrten)", systemImage: "number")
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Monatswerte

    /// Bezieht sich immer auf den aktuellen Kalendermonat, unabhängig vom
    /// oben ausgewählten Steuerjahr.
    private var monatsSection: some View {
        Section("Aktueller Monat") {
            HStack(spacing: 12) {
                StatistikKarte(titel: "Kilometer", wert: "\(monatsWert.km.alsKilometerWert) km", systemImage: "road.lanes")
                StatistikKarte(titel: "Betrag", wert: monatsWert.betrag.alsEuroBetrag, systemImage: "eurosign.circle")
                StatistikKarte(titel: "Fahrten", wert: "\(monatsWert.anzahlFahrten)", systemImage: "number")
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Aufschlüsselung nach Zweck

    private var nachZweckSection: some View {
        Section("Nach Zweck") {
            ForEach(nachZweck) { eintrag in
                HStack {
                    Label(eintrag.zweck.anzeigeName, systemImage: eintrag.zweck.systemImage)
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(eintrag.wert.km.alsKilometerWert) km")
                        Text(eintrag.wert.betrag.alsEuroBetrag)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(eintrag.zweck.anzeigeName): \(eintrag.wert.km.alsKilometerWert) Kilometer, \(eintrag.wert.betrag.alsEuroBetrag)")
            }
        }
    }

    // MARK: - Aufschlüsselung nach Fahrzeug

    private var nachFahrzeugSection: some View {
        Section("Nach Fahrzeug") {
            if nachFahrzeug.isEmpty {
                Text("Keine Fahrten im ausgewählten Jahr.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(nachFahrzeug) { eintrag in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(eintrag.fahrzeug?.name ?? "Nicht zugeordnet")
                                .font(.body)
                            Text(eintrag.fahrzeug?.typ.anzeigeName ?? "Fahrzeug nicht mehr vorhanden")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(eintrag.wert.km.alsKilometerWert) km")
                            Text(eintrag.wert.betrag.alsEuroBetrag)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(eintrag.fahrzeug?.name ?? "Nicht zugeordnet"): \(eintrag.wert.km.alsKilometerWert) Kilometer, \(eintrag.wert.betrag.alsEuroBetrag)")
                }
            }
        }
    }

    // MARK: - Diagramm

    /// Rollierendes Sechs-Monats-Fenster, unabhängig vom oben ausgewählten
    /// Steuerjahr, da es einen Jahreswechsel überspannen kann. Steht in
    /// einer eigenen Section und ergänzt die Zahlen oben, ersetzt sie aber
    /// nicht.
    private var diagrammSection: some View {
        Section("Verlauf der letzten 6 Monate") {
            Chart(sechsMonate) { eintrag in
                BarMark(
                    x: .value("Monat", eintrag.monatsStart, unit: .month),
                    y: .value("Kilometer", eintrag.km)
                )
                .foregroundStyle(.blue)
                .accessibilityLabel(monatsName(eintrag.monatsStart))
                .accessibilityValue("\(Int(eintrag.km.rounded())) Kilometer")
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).locale(.deutsch))
                    AxisGridLine()
                }
            }
            .frame(height: 200)
            .accessibilityHint("Balkendiagramm der gefahrenen Kilometer je Monat für die letzten sechs Monate.")
        }
    }

    private func monatsName(_ datum: Date) -> String {
        datum.formatted(.dateTime.month(.wide).locale(.deutsch))
    }

    // MARK: - Export

    private var exportSection: some View {
        Section("Exportieren") {
            Button {
                exportStarten(.pdf)
            } label: {
                Label("PDF exportieren", systemImage: "doc.richtext")
            }
            .accessibilityLabel("PDF exportieren")
            .accessibilityHint("Exportiert die Fahrten des ausgewählten Jahres als PDF-Dokument.")

            Button {
                exportStarten(.csv)
            } label: {
                Label("CSV exportieren", systemImage: "doc.text")
            }
            .accessibilityLabel("CSV exportieren")
            .accessibilityHint("Exportiert die Fahrten des ausgewählten Jahres als CSV-Datei.")

            Button {
                exportStarten(.datev)
            } label: {
                Label("DATEV exportieren", systemImage: "doc.badge.gearshape")
            }
            .accessibilityLabel("DATEV exportieren")
            .accessibilityHint("Exportiert die Fahrten des ausgewählten Jahres im DATEV-Format.")
        }
    }

    /// Prüft zuerst über `ProManager`, ob der Export freigeschaltet ist, und
    /// zeigt andernfalls `PaywallView`. Die eigentliche Erzeugung der Datei
    /// läuft ausschließlich über `FahrtenExporter` – hier findet keine
    /// eigene Exportlogik statt.
    private func exportStarten(_ format: ExportFormat) {
        guard proManager.pruefeExportBerechtigung() else {
            zeigePaywall = true
            return
        }
        do {
            switch format {
            case .pdf:
                try FahrtenExporter.exportierePDF(fahrten: jahresFahrten, fahrzeuge: fahrzeuge, jahr: ausgewaehltesJahr)
            case .csv:
                try FahrtenExporter.exportiereCSV(fahrten: jahresFahrten, fahrzeuge: fahrzeuge, jahr: ausgewaehltesJahr)
            case .datev:
                try FahrtenExporter.exportiereDATEV(fahrten: jahresFahrten, fahrzeuge: fahrzeuge, jahr: ausgewaehltesJahr)
            }
        } catch {
            exportFehlerText = error.localizedDescription
            zeigeExportFehler = true
        }
    }

    // MARK: - Sonstige Hinweise

    private var hinweisSection: some View {
        Section {
            Text(FahrtkostenRechner.pendlerpauschaleHinweis)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        UebersichtView()
    }
    .modelContainer(for: [Fahrzeug.self, Fahrt.self, AuditEntry.self], inMemory: true)
}
