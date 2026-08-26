import BackgroundTasks
import Foundation
import Observation

/// Sorgt für ein automatisches monatliches CSV-Backup als zusätzliche,
/// rein lokale Sicherungsmöglichkeit.
///
/// **Archivierbarkeit über mehrere Jahre:** Backups werden als reine
/// UTF-8-Text-CSV (mit BOM, siehe `CSVExporter`) im Dokumente-Verzeichnis
/// der App abgelegt – einem offenen, werkzeugunabhängigen Format, das sich
/// unabhängig von der Existenz dieser App noch in Jahrzehnten mit jeder
/// Tabellenkalkulation öffnen lässt. Das Dokumente-Verzeichnis wird (sofern
/// vom Nutzer nicht ausgeschlossen) in iCloud-Backups bzw. lokale
/// Gerätesicherungen einbezogen; zusätzlich kann der Nutzer jede Datei
/// jederzeit über `ShareSheet` an einen selbst gewählten Ort (iCloud Drive,
/// Dateien-App, …) kopieren.
///
/// **Arbeitsweise:**
/// 1. **Zuverlässiger Grundmechanismus**: `pruefeUndErstelleBackupFallsNoetig(...)`
///    wird bei jedem App-Start aufgerufen (siehe `KilometerLogApp.swift`)
///    und zusätzlich als Sicherheitsnetz, sobald `UebersichtView` erscheint
///    (für sehr lange App-Sitzungen ohne Neustart über einen Monatswechsel
///    hinweg). Fehlt für den VORMONAT noch ein Backup, wird es sofort
///    erzeugt. Das deckt „nach Monatswechsel bzw. beim ersten App-Start im
///    neuen Monat“ vollständig ab, unabhängig von Systemvorgaben.
/// 2. **Optionaler BGTaskScheduler-Weg**: Registrierung/Planung erfolgen
///    NUR, wenn `hintergrundAufgabenKennung` tatsächlich unter
///    `BGTaskSchedulerPermittedIdentifiers` in der Info.plist eingetragen
///    ist (siehe `Configuration/Info.plist`). Ohne diesen Eintrag würde
///    `BGTaskScheduler.shared.register(...)` laut Apple-Dokumentation zur
///    Laufzeit abstürzen – deshalb wird die Kennung vorher aktiv geprüft,
///    statt blind zu registrieren. Ist sie nicht vorhanden, greift
///    ausschließlich Weg 1.
@Observable
final class MonatsBackupManager {
    static let hintergrundAufgabenKennung = "com.kilometerlog.monatsbackup"

    private let fileManager: FileManager
    private let backupOrdner: URL

    /// `true`, sobald der Nutzer das Share-Sheet für das zuletzt erzeugte
    /// Backup tatsächlich geöffnet hat. Rein informativ für den Hinweis in
    /// der UI – es lässt sich technisch nicht erzwingen, dass die Datei
    /// danach auch wirklich an einem sicheren Ort abgelegt wurde, da der
    /// Nutzer selbst über das Ziel entscheidet.
    private(set) var letztesBackupWurdeGeteilt: Bool
    private(set) var letztesBackupDatum: Date?
    private(set) var letztesBackupURL: URL?

    private static let geteiltSchluessel = "MonatsBackupManager.letztesBackupWurdeGeteilt"
    private static let datumSchluessel = "MonatsBackupManager.letztesBackupDatum"
    private static let urlSchluessel = "MonatsBackupManager.letztesBackupURL"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let basis = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        backupOrdner = basis.appendingPathComponent("Backups", isDirectory: true)

        letztesBackupWurdeGeteilt = UserDefaults.standard.bool(forKey: Self.geteiltSchluessel)
        letztesBackupDatum = UserDefaults.standard.object(forKey: Self.datumSchluessel) as? Date
        if let gespeichertePfad = UserDefaults.standard.string(forKey: Self.urlSchluessel) {
            letztesBackupURL = URL(fileURLWithPath: gespeichertePfad)
        }
    }

    /// Erzeugt genau dann ein Backup des Vormonats, wenn dafür noch keine
    /// Datei existiert. Gefahrlos mehrfach aufrufbar (z. B. bei jedem
    /// App-Start UND beim Öffnen der Übersicht) – ein bereits vorhandenes
    /// Backup wird nie überschrieben.
    @discardableResult
    func pruefeUndErstelleBackupFallsNoetig(
        fahrten: [Fahrt],
        fahrzeuge: [Fahrzeug],
        auditEntries: [AuditEntry],
        bezugsdatum: Date = .now,
        kalender: Calendar = .current
    ) -> URL? {
        guard let vormonatsDatum = kalender.date(byAdding: .month, value: -1, to: bezugsdatum) else {
            return nil
        }

        let jahrDesVormonats = kalender.component(.year, from: vormonatsDatum)
        let monatDesVormonats = kalender.component(.month, from: vormonatsDatum)
        let dateiname = String(format: "KilometerLog_Backup_%04d-%02d.csv", jahrDesVormonats, monatDesVormonats)
        let ziel = backupOrdner.appendingPathComponent(dateiname)

        guard !fileManager.fileExists(atPath: ziel.path) else {
            return nil
        }

        // Auch ohne Fahrten im Vormonat wird ein (dann nur aus der
        // Kopfzeile bestehendes) Backup erzeugt, damit lückenlos für jeden
        // Monat ein Snapshot existiert – Vollständigkeit ist ein
        // GoBD-Grundprinzip.
        let vormonatsFahrten = fahrten.filter {
            kalender.isDate($0.startDatum, equalTo: vormonatsDatum, toGranularity: .month)
                && kalender.isDate($0.startDatum, equalTo: vormonatsDatum, toGranularity: .year)
        }
        let daten = CSVExporter.generiereCSV(
            fahrten: vormonatsFahrten,
            fahrzeuge: fahrzeuge,
            jahr: jahrDesVormonats,
            auditEntries: auditEntries
        )

        do {
            try fileManager.createDirectory(at: backupOrdner, withIntermediateDirectories: true)
            try daten.write(to: ziel, options: .atomic)
        } catch {
            return nil
        }

        letztesBackupDatum = .now
        letztesBackupURL = ziel
        letztesBackupWurdeGeteilt = false
        UserDefaults.standard.set(letztesBackupDatum, forKey: Self.datumSchluessel)
        UserDefaults.standard.set(ziel.path, forKey: Self.urlSchluessel)
        UserDefaults.standard.set(false, forKey: Self.geteiltSchluessel)
        return ziel
    }

    /// Vom Aufrufer zu melden, sobald der Nutzer das Share-Sheet für das
    /// zuletzt erzeugte Backup tatsächlich geöffnet hat.
    func markiereAlsGeteilt() {
        letztesBackupWurdeGeteilt = true
        UserDefaults.standard.set(true, forKey: Self.geteiltSchluessel)
    }

    // MARK: - Optionaler BGTaskScheduler-Weg

    /// Registriert die Hintergrundaufgabe NUR, wenn `hintergrundAufgabenKennung`
    /// tatsächlich unter `BGTaskSchedulerPermittedIdentifiers` in der
    /// Info.plist eingetragen ist. Muss, falls überhaupt, spätestens beim
    /// App-Start (vor Ende von `KilometerLogApp.init()`) aufgerufen werden
    /// (Apple-Vorgabe).
    static func registriereHintergrundaufgabeFallsMoeglich(aufgabe: @escaping () -> Void) {
        guard erlaubteLaufzeitregeln else { return }

        BGTaskScheduler.shared.register(forTaskWithIdentifier: hintergrundAufgabenKennung, using: nil) { task in
            aufgabe()
            task.setTaskCompleted(success: true)
            planeNaechsteHintergrundaufgabe()
        }
    }

    /// Plant den nächsten Lauf, frühestens in einem Tag. Ohne erfüllte
    /// Laufzeitregeln ein bewusstes No-op.
    static func planeNaechsteHintergrundaufgabe() {
        guard erlaubteLaufzeitregeln else { return }

        let anfrage = BGAppRefreshTaskRequest(identifier: hintergrundAufgabenKennung)
        anfrage.earliestBeginDate = Calendar.current.date(byAdding: .day, value: 1, to: .now)
        try? BGTaskScheduler.shared.submit(anfrage)
    }

    /// Prüft aktiv, ob `hintergrundAufgabenKennung` in der Info.plist
    /// eingetragen ist, statt blind zu registrieren/planen und damit einen
    /// Laufzeitabsturz zu riskieren.
    private static var erlaubteLaufzeitregeln: Bool {
        let erlaubteKennungen = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String]
        return erlaubteKennungen?.contains(hintergrundAufgabenKennung) == true
    }
}
