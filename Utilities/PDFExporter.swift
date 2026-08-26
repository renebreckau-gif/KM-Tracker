import CoreGraphics
import PDFKit
import UIKit

/// Erzeugt das PDF-Fahrtenbuch eines Steuerjahres.
///
/// Technischer Hinweis zur Frameworkwahl: Die eigentliche Seitengestaltung
/// (Text, Umbrüche, Seitenwechsel) übernimmt `UIGraphicsPDFRenderer` aus
/// UIKit – das ist die von Apple vorgesehene API, um NEUE PDF-Inhalte aus
/// Text zu erzeugen. `PDFKit` ist auf das Betrachten/Bearbeiten
/// BESTEHENDER PDF-Dokumente ausgelegt und bietet keine Text-Layout-API;
/// es wird hier ergänzend genutzt, um die erzeugten Daten am Ende über
/// `PDFDocument` auf Wohlgeformtheit zu prüfen (`seitenanzahl(in:)`).
/// Beides sind Apple-Frameworks, es kommt keine Drittanbieter-Bibliothek
/// zum Einsatz.
///
/// Jede Fahrt wird als kompakter Mehrzeilen-Block statt als einzelne,
/// extrem schmale Tabellenspalte dargestellt: Bei mindestens elf
/// geforderten Spalten (Datum, Start-/Ziel-Adresse, beide Tachostände,
/// Kilometer, Zweck, konkreter Zweck, Geschäftspartner, Fahrzeug, Betrag)
/// wäre eine einzeilige A4-Tabelle so schmal, dass lange Adressen oder
/// Geschäftspartner-Namen zwangsläufig abgeschnitten würden. Die
/// Aufgabenstellung erlaubt ausdrücklich „Umbruch ODER zusätzliche
/// Detailzeilen“ – hier werden beide kombiniert: Jede Fahrt bekommt eine
/// kompakte Kopfzeile plus mehrere Detailzeilen, alle mit echter
/// Textmessung und -umbruch, sodass nichts abgeschnitten wird.
enum PDFExporter {
    private static let seitenBreite: CGFloat = 595.2 // A4 bei 72pt/Zoll
    private static let seitenHoehe: CGFloat = 841.8
    private static let rand: CGFloat = 36
    /// Fest reservierte Kopfhöhe für ALLE Seiten (nicht nur die erste), damit
    /// die Seitenaufteilung unabhängig davon korrekt bleibt, wie viel der
    /// tatsächlich gezeichnete Kopf einer bestimmten Seite einnimmt.
    private static let kopfHoehe: CGFloat = 130
    private static let fussHoehe: CGFloat = 46

    private static var inhaltsBreite: CGFloat { seitenBreite - 2 * rand }
    private static var inhaltsStartY: CGFloat { rand + kopfHoehe }
    private static var inhaltsEndeY: CGFloat { seitenHoehe - fussHoehe - rand }
    private static var inhaltsHoeheProSeite: CGFloat { inhaltsEndeY - inhaltsStartY }

    private static let fussHinweis = "Erstellt mit KilometerLog. Keine Steuerberatung. Bitte von Steuerberater oder Finanzamt prüfen lassen."
    private static let fahrtenbuchHinweis = "Entspricht den Anforderungen an ein ordnungsgemäßes elektronisches Fahrtenbuch"

    // MARK: - Öffentliche API

    static func generierePDF(
        fahrten: [Fahrt],
        fahrzeuge: [Fahrzeug],
        auditEntries: [AuditEntry],
        jahr: Int
    ) -> Data {
        let fahrzeugeNachId = Dictionary(uniqueKeysWithValues: fahrzeuge.map { ($0.id, $0) })
        let jahresFahrten = fahrten
            .filter { Calendar.current.component(.year, from: $0.startDatum) == jahr }
            .sorted { $0.startDatum < $1.startDatum }

        let fahrzeugNamen = Set(jahresFahrten.compactMap { fahrzeugeNachId[$0.fahrzeugId]?.name }).sorted()
        let fahrzeugKontext = fahrzeugNamen.isEmpty
            ? "Keine Fahrzeuge zugeordnet"
            : "Fahrzeuge: \(fahrzeugNamen.joined(separator: ", "))"

        let bloecke = erstelleBloecke(fahrten: jahresFahrten, fahrzeugeNachId: fahrzeugeNachId, auditEntries: auditEntries)
        let seiten = verteileAufSeiten(bloecke)
        return zeichnePDF(seiten: seiten, jahr: jahr, fahrzeugKontext: fahrzeugKontext)
    }

    /// Lädt erzeugte PDF-Daten über `PDFKit` und liefert die tatsächliche
    /// Seitenanzahl zurück – eine einfache Wohlgeformtheitsprüfung, z. B.
    /// für künftige Tests.
    static func seitenanzahl(in daten: Data) -> Int {
        PDFDocument(data: daten)?.pageCount ?? 0
    }

    // MARK: - Inhaltsblöcke

    private enum Block {
        case abschnittsUeberschrift(String)
        case fahrtEintrag([String])
        case text([String], font: UIFont)

        func hoehe(breite: CGFloat) -> CGFloat {
            switch self {
            case .abschnittsUeberschrift(let titel):
                return PDFExporter.hoeheFuerZeile(titel, font: .boldSystemFont(ofSize: 14), breite: breite) + 10
            case .fahrtEintrag(let zeilen):
                var summe: CGFloat = 0
                for (index, zeile) in zeilen.enumerated() {
                    let font: UIFont = index == 0 ? .boldSystemFont(ofSize: 11) : .systemFont(ofSize: 10)
                    summe += PDFExporter.hoeheFuerZeile(zeile, font: font, breite: breite) + 2
                }
                return summe + 10
            case .text(let zeilen, let font):
                var summe: CGFloat = 0
                for zeile in zeilen {
                    summe += PDFExporter.hoeheFuerZeile(zeile, font: font, breite: breite) + 2
                }
                return summe + 6
            }
        }
    }

    private static func erstelleBloecke(
        fahrten: [Fahrt],
        fahrzeugeNachId: [UUID: Fahrzeug],
        auditEntries: [AuditEntry]
    ) -> [Block] {
        var bloecke: [Block] = [.abschnittsUeberschrift("Fahrten")]

        if fahrten.isEmpty {
            bloecke.append(.text(["Keine Fahrten im ausgewählten Jahr."], font: .italicSystemFont(ofSize: 11)))
        }

        for fahrt in fahrten {
            let fahrzeug = fahrzeugeNachId[fahrt.fahrzeugId]
            let betrag = FahrtkostenRechner.berechne(km: fahrt.km, fahrzeugTyp: fahrzeug?.typ ?? .sonstiges)

            var zeilen = [
                "\(fahrt.startDatum.alsKurzesDatum)  ·  \(fahrzeug?.name ?? "Nicht zugeordnet")  ·  \(fahrt.km.alsKilometerWert) km  ·  \(betrag.alsEuroBetrag)",
                "Start: \(fahrt.startAdresse)  →  Ziel: \(fahrt.zielAdresse)",
                "Tachostand: \(fahrt.kmStandStart.alsKilometerWert) km → \(fahrt.kmStandEnde.alsKilometerWert) km",
                "\(fahrt.zweck.anzeigeName): \(fahrt.zweckKonkret)"
                    + (fahrt.geschaeftspartner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? ""
                        : " · Geschäftspartner: \(fahrt.geschaeftspartner)")
            ]
            if let notizen = fahrt.notizen, !notizen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                zeilen.append("Notiz: \(notizen)")
            }
            bloecke.append(.fahrtEintrag(zeilen))
        }

        bloecke.append(.abschnittsUeberschrift("Summen"))
        let gruppiert = Dictionary(grouping: fahrten, by: \.fahrzeugId)
        var gesamtKm = 0.0
        var gesamtBetrag = 0.0
        var summenZeilen: [String] = []
        for (fahrzeugId, fahrtenFuerFahrzeug) in gruppiert.sorted(by: {
            (fahrzeugeNachId[$0.key]?.name ?? "Nicht zugeordnet") < (fahrzeugeNachId[$1.key]?.name ?? "Nicht zugeordnet")
        }) {
            let typ = fahrzeugeNachId[fahrzeugId]?.typ ?? .sonstiges
            let km = fahrtenFuerFahrzeug.reduce(0) { $0 + $1.km }
            let betrag = fahrtenFuerFahrzeug.reduce(0) { $0 + FahrtkostenRechner.berechne(km: $1.km, fahrzeugTyp: typ) }
            gesamtKm += km
            gesamtBetrag += betrag
            summenZeilen.append("\(fahrzeugeNachId[fahrzeugId]?.name ?? "Nicht zugeordnet"): \(km.alsKilometerWert) km, \(betrag.alsEuroBetrag)")
        }
        if summenZeilen.isEmpty {
            summenZeilen.append("Keine Fahrten im ausgewählten Jahr.")
        }
        summenZeilen.append("Gesamt: \(gesamtKm.alsKilometerWert) km, \(gesamtBetrag.alsEuroBetrag)")
        bloecke.append(.text(summenZeilen, font: .boldSystemFont(ofSize: 11)))

        let relevanteFahrtIds = Set(fahrten.map(\.id))
        let relevanteAudits = auditEntries
            .filter { relevanteFahrtIds.contains($0.fahrtId) }
            .sorted { $0.zeitstempel < $1.zeitstempel }

        if !relevanteAudits.isEmpty {
            bloecke.append(.abschnittsUeberschrift("Änderungsverlauf"))
            for eintrag in relevanteAudits {
                bloecke.append(.text([
                    "\(eintrag.zeitstempel.alsKurzesDatum)  ·  \(eintrag.feldName)",
                    "„\(eintrag.alterWert)“ → „\(eintrag.neuerWert)“",
                    "Grund: \(eintrag.grund)"
                ], font: .systemFont(ofSize: 10)))
            }
        }

        return bloecke
    }

    // MARK: - Seitenaufteilung

    private static func verteileAufSeiten(_ bloecke: [Block]) -> [[Block]] {
        var seiten: [[Block]] = [[]]
        var aktuelleHoehe: CGFloat = 0

        for block in bloecke {
            let hoehe = block.hoehe(breite: inhaltsBreite)
            if aktuelleHoehe + hoehe > inhaltsHoeheProSeite, !seiten[seiten.count - 1].isEmpty {
                seiten.append([])
                aktuelleHoehe = 0
            }
            seiten[seiten.count - 1].append(block)
            aktuelleHoehe += hoehe
        }

        return seiten
    }

    // MARK: - Zeichnen

    private static func zeichnePDF(seiten: [[Block]], jahr: Int, fahrzeugKontext: String) -> Data {
        let seitenRect = CGRect(x: 0, y: 0, width: seitenBreite, height: seitenHoehe)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Fahrtenbuch \(jahr)",
            kCGPDFContextCreator as String: "KilometerLog"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: seitenRect, format: format)
        let gesamtseiten = seiten.count

        return renderer.pdfData { context in
            for (index, seite) in seiten.enumerated() {
                context.beginPage()
                let seitenNummer = index + 1
                var y = zeichneKopf(
                    seitenNummer: seitenNummer,
                    jahr: jahr,
                    fahrzeugKontext: fahrzeugKontext,
                    istErsteSeite: seitenNummer == 1
                )

                for block in seite {
                    y = zeichneBlock(block, ab: y)
                }

                zeichneFuss(seitenNummer: seitenNummer, gesamtseiten: gesamtseiten)
            }
        }
    }

    private static func zeichneKopf(seitenNummer: Int, jahr: Int, fahrzeugKontext: String, istErsteSeite: Bool) -> CGFloat {
        var y: CGFloat = rand

        if istErsteSeite {
            let titel = "Fahrtenbuch \(jahr)"
            y = zeichneText(titel, font: .boldSystemFont(ofSize: 20), bei: CGPoint(x: rand, y: y), breite: inhaltsBreite) + 4

            let kontext = "\(fahrzeugKontext) · Erzeugt am \(Date.now.formatted(.dateTime.day().month().year().hour().minute().locale(.deutsch)))"
            y = zeichneText(kontext, font: .systemFont(ofSize: 10), bei: CGPoint(x: rand, y: y), breite: inhaltsBreite) + 6

            y = zeichneText(fahrtenbuchHinweis, font: .italicSystemFont(ofSize: 10), bei: CGPoint(x: rand, y: y), breite: inhaltsBreite) + 10
        } else {
            let titel = "Fahrtenbuch \(jahr) (Fortsetzung)"
            y = zeichneText(titel, font: .boldSystemFont(ofSize: 12), bei: CGPoint(x: rand, y: y), breite: inhaltsBreite) + 10
        }

        let tabellenkopf = "Datum · Fahrzeug · Kilometer · Betrag"
        _ = zeichneText(tabellenkopf, font: .boldSystemFont(ofSize: 10), bei: CGPoint(x: rand, y: y), breite: inhaltsBreite)

        // Feste Rückgabe, unabhängig von der tatsächlich gezeichneten Höhe:
        // Damit bleibt die Seitenaufteilung (`inhaltsHoeheProSeite`) für
        // jede Seite exakt konsistent, auch wenn Folgeseiten einen kürzeren
        // Kopf zeichnen als die erste Seite.
        return inhaltsStartY
    }

    private static func zeichneBlock(_ block: Block, ab startY: CGFloat) -> CGFloat {
        var y = startY
        switch block {
        case .abschnittsUeberschrift(let titel):
            y = zeichneText(titel, font: .boldSystemFont(ofSize: 14), bei: CGPoint(x: rand, y: y), breite: inhaltsBreite) + 10
        case .fahrtEintrag(let zeilen):
            for (index, zeile) in zeilen.enumerated() {
                let font: UIFont = index == 0 ? .boldSystemFont(ofSize: 11) : .systemFont(ofSize: 10)
                y = zeichneText(zeile, font: font, bei: CGPoint(x: rand, y: y), breite: inhaltsBreite) + 2
            }
            y += 8
        case .text(let zeilen, let font):
            for zeile in zeilen {
                y = zeichneText(zeile, font: font, bei: CGPoint(x: rand, y: y), breite: inhaltsBreite) + 2
            }
            y += 4
        }
        return y
    }

    private static func zeichneFuss(seitenNummer: Int, gesamtseiten: Int) {
        let y = seitenHoehe - fussHoehe
        let seitenText = "Seite \(seitenNummer) von \(gesamtseiten)"
        let seitenTextBreite: CGFloat = 90

        _ = zeichneText(
            fussHinweis,
            font: .systemFont(ofSize: 8),
            bei: CGPoint(x: rand, y: y),
            breite: inhaltsBreite - seitenTextBreite - 8
        )
        _ = zeichneText(
            seitenText,
            font: .systemFont(ofSize: 8),
            bei: CGPoint(x: seitenBreite - rand - seitenTextBreite, y: y),
            breite: seitenTextBreite
        )
    }

    // MARK: - Textmessung und -zeichnung

    /// Misst die tatsächlich benötigte Höhe eines (ggf. mehrzeilig
    /// umbrechenden) Textes bei fester Breite – Grundlage sowohl für die
    /// Seitenaufteilung als auch für das eigentliche Zeichnen, damit beide
    /// garantiert dieselbe Höhe annehmen.
    private static func hoeheFuerZeile(_ text: String, font: UIFont, breite: CGFloat) -> CGFloat {
        let attribute: [NSAttributedString.Key: Any] = [.font: font]
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: breite, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attribute,
            context: nil
        )
        return ceil(rect.height)
    }

    @discardableResult
    private static func zeichneText(_ text: String, font: UIFont, bei punkt: CGPoint, breite: CGFloat) -> CGFloat {
        let hoehe = hoeheFuerZeile(text, font: font, breite: breite)
        let attribute: [NSAttributedString.Key: Any] = [.font: font]
        (text as NSString).draw(
            with: CGRect(x: punkt.x, y: punkt.y, width: breite, height: hoehe),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attribute,
            context: nil
        )
        return punkt.y + hoehe
    }
}
