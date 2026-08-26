import Charts
import SwiftData
import SwiftUI

/// Kennzahlen-Übersicht: Kopfbereich mit rechtlichem Einordnungshinweis,
/// Jahres- und Monatswerte, Aufschlüsselung nach Zweck/Fahrzeug, ein
/// Balkendiagramm der letzten sechs Monate, der PDF-/CSV-/DATEV-Export
/// sowie der Status des automatischen monatlichen Backups.
///
/// Alle Beträge werden ausschließlich über `StatistikBerechnung` ermittelt,
/// die ihrerseits ausschließlich `FahrtkostenRechner.berechne(...)`
/// verwendet – diese Ansicht kennt selbst keine Kilometersätze. Die
/// eigentliche Dateierzeugung läuft ausschließlich über `FahrtExporter`
/// und dessen `CSVExporter`/`PDFExporter`/`DATEVExporter` – diese Ansicht
/// enthält keine eigene Exportlogik.
struct UebersichtView: View {
    @Query private var fahrten: [Fahrt]
    @Query(sort: \Fahrzeug.name) private var fahrzeuge: [Fahrzeug]
    @Query private var auditEntries: [AuditEntry]

    @State private var ausgewaehltesJahr = Calendar.current.component(.year, from: .now)
    @State private var proManager = ProManager()
    @State private var monatsBackupManager = MonatsBackupManager()
    @State private var zeigePaywall = false
    @State private var zeigeExportFehler = false
    @State private var exportFehlerText = ""
    @State private var exportDatei: ExportDatei?
    @State private var backupDatei: ExportDatei?

    private enum ExportFormat {
        case pdf, csv, datev
    }

    /// Kleiner Wrapper, damit `URL` für `sheet(item:)` `Identifiable` ist.
    private struct ExportDatei: Identifiable {
        let url: URL
        var id: URL { url }
    }

    private var jahresAuditEntries: [AuditEntry] {
        let ids = Set(jahresFahrten.map(\.id))
        return auditEntries.filter { ids.contains($0.fahrtId) }
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
            backupSection
            hinweisSection
        }
        .navigationTitle("Übersicht")
        .task {
            monatsBackupManager.pruefeUndErstelleBackupFallsNoetig(
                fahrten: fahrten,
                fahrzeuge: fahrzeuge,
                auditEntries: auditEntries
            )
        }
        .sheet(isPresented: $zeigePaywall) {
            PaywallView()
        }
        .sheet(item: $exportDatei) { datei in
            ShareSheet(dateiURLs: [datei.url])
        }
        .sheet(item: $backupDatei) { datei in
            ShareSheet(dateiURLs: [datei.url]) {
                monatsBackupManager.markiereAlsGeteilt()
            }
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

    /// PDF und CSV sind Teil der steuerlichen Grundpflicht (ordnungsgemäßes
    /// Fahrtenbuch) und bleiben frei nutzbar. Nur der DATEV-Export prüft
    /// vorher über `ProManager`, ob er freigeschaltet ist, und zeigt
    /// andernfalls `PaywallView`. Die eigentliche Erzeugung der Datei läuft
    /// in jedem Fall ausschließlich über `FahrtExporter` – hier findet
    /// keine eigene Exportlogik statt.
    private var exportSection: some View {
        Section("Exportieren") {
            Button {
                exportStarten(.pdf)
            } label: {
                Label("PDF exportieren", systemImage: "doc.richtext")
            }
            .accessibilityLabel("PDF exportieren")
            .accessibilityHint("Exportiert die Fahrten des ausgewählten Jahres als PDF-Dokument und öffnet das Teilen-Menü.")

            Button {
                exportStarten(.csv)
            } label: {
                Label("CSV exportieren", systemImage: "doc.text")
            }
            .accessibilityLabel("CSV exportieren")
            .accessibilityHint("Exportiert die Fahrten des ausgewählten Jahres als CSV-Datei und öffnet das Teilen-Menü.")

            Button {
                exportStarten(.datev)
            } label: {
                Label("DATEV exportieren", systemImage: "doc.badge.gearshape")
            }
            .accessibilityLabel("DATEV exportieren")
            .accessibilityHint("Exportiert die Fahrten des ausgewählten Jahres im DATEV-Format. Teil von KilometerLog Pro.")
        }
    }

    private func exportStarten(_ format: ExportFormat) {
        if format == .datev, !proManager.pruefeDATEVBerechtigung() {
            zeigePaywall = true
            return
        }
        do {
            let url: URL
            switch format {
            case .pdf:
                url = try FahrtExporter.exportierePDF(
                    fahrten: jahresFahrten,
                    fahrzeuge: fahrzeuge,
                    auditEntries: jahresAuditEntries,
                    jahr: ausgewaehltesJahr
                )
            case .csv:
                url = try FahrtExporter.exportiereCSV(
                    fahrten: jahresFahrten,
                    fahrzeuge: fahrzeuge,
                    auditEntries: jahresAuditEntries,
                    jahr: ausgewaehltesJahr
                )
            case .datev:
                url = try FahrtExporter.exportiereDATEV(fahrten: jahresFahrten, fahrzeuge: fahrzeuge, jahr: ausgewaehltesJahr)
            }
            exportDatei = ExportDatei(url: url)
        } catch {
            exportFehlerText = error.localizedDescription
            zeigeExportFehler = true
        }
    }

    // MARK: - Automatisches Backup

    /// Zeigt Status und Freigabe-Hinweis für das automatisch erzeugte
    /// monatliche CSV-Backup (siehe `MonatsBackupManager`). KilometerLog
    /// versendet die Datei nie selbst – der Nutzer entscheidet im
    /// Share-Sheet über das Ziel.
    private var backupSection: some View {
        Section("Automatisches Monats-Backup") {
            if let datum = monatsBackupManager.letztesBackupDatum, let url = monatsBackupManager.letztesBackupURL {
                LabeledContent("Zuletzt erzeugt", value: datum.alsKurzesDatum)

                if !monatsBackupManager.letztesBackupWurdeGeteilt {
                    Label("Noch nicht an einem sicheren Ort gesichert", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                Button {
                    backupDatei = ExportDatei(url: url)
                } label: {
                    Label("Backup sichern", systemImage: "square.and.arrow.up")
                }
                .accessibilityLabel("Backup sichern")
                .accessibilityHint("Öffnet das Teilen-Menü, um das monatliche CSV-Backup an einem selbst gewählten Ort abzulegen, zum Beispiel in iCloud Drive oder der Dateien-App.")
            } else {
                Text("Es wurde noch kein automatisches Backup erstellt. Das erste vollständige Monats-Backup entsteht nach dem ersten Monatswechsel.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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
