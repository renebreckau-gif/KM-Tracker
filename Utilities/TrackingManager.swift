import CoreLocation
import Foundation
import Observation

/// Verwertbarkeitsstatus des aktuellen GPS-Signals für die Anzeige in `TrackingView`.
enum GPSSignalStatus {
    case suche
    case gut
    case schwach
    case verloren

    var anzeigeName: String {
        switch self {
        case .suche:
            return "Suche GPS-Signal …"
        case .gut:
            return "GPS-Signal gut"
        case .schwach:
            return "GPS-Signal schwach"
        case .verloren:
            return "GPS-Signal verloren, km manuell ergänzen"
        }
    }
}

/// Nicht persistentes Ergebnis einer beendeten Aufzeichnung.
///
/// Enthält ausschließlich verdichtete Werte – keine Route, keine
/// GPS-Rohpunkte. `distanzKm` ist eine GPS-gestützte Schätzung und ersetzt
/// nicht die tatsächlichen Tachostände: `ManuelleFahrtView` verlangt diese
/// weiterhin vom Nutzer und nutzt `distanzKm` lediglich als Kontext/Hilfe.
struct TrackingErgebnis: Identifiable {
    /// Nur für SwiftUIs `sheet(item:)`-Präsentation in `TrackingView`
    /// relevant, keine persistente Kennung.
    let id = UUID()
    let startZeitpunkt: Date
    let endZeitpunkt: Date
    let distanzKm: Double
    let startAdresse: String?
    let zielAdresse: String?
    /// `true`, wenn während der Aufzeichnung mindestens einmal das
    /// GPS-Signal über die Verlustschwelle hinaus verloren ging. In diesem
    /// Fall muss die Bestätigung der Tachostände im Fahrt-Eintrag
    /// dokumentiert werden.
    let gpsSignalGingVerloren: Bool
}

/// Wrapper um `CLLocationManager` für die aktive Fahrtaufzeichnung.
///
/// **Privacy by Design:** GPS-Punkte leben ausschließlich in `punkte`, einem
/// In-Memory-Array dieser Instanz, das nie den Prozessspeicher verlässt.
/// `stopTracking()` liefert nur ein verdichtetes `TrackingErgebnis` und
/// leert `punkte` sofort danach. Es gibt keine `route`-Beziehung zu `Fahrt`,
/// kein Bewegungsprofil, keine Hintergrundaufzeichnung außerhalb einer
/// aktiven Fahrt und keinerlei Netzwerkversand von Standortdaten (die
/// Adressermittlung läuft ausschließlich über Apples `CLGeocoder`, es gibt
/// keine eigene Serveranbindung).
@Observable
final class TrackingManager: NSObject {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    /// Nur während der aktiven Session im Speicher gehalten, niemals
    /// persistiert und nach `stopTracking()` sofort geleert.
    private var punkte: [CLLocation] = []

    private var startZeitpunkt: Date?
    private var letzterGeocodierterZielPunkt: CLLocation?
    private var letzteBewegungAm: Date = .now
    private var gpsSignalGingWaehrendSessionVerloren = false
    private var ueberwachungsTimer: Timer?

    /// Punkte mit schlechterer horizontaler Genauigkeit als dieser Wert (in
    /// Metern) sind für eine Kilometerangabe zu ungenau und werden verworfen.
    private let maximaleUngenauigkeit: CLLocationDistance = 50
    /// Veraltete, zwischengespeicherte Positionen (älter als dieser Wert in
    /// Sekunden) werden ignoriert.
    private let maximalesPunktAlter: TimeInterval = 10
    /// Ein Punkt, der rechnerisch eine höhere Geschwindigkeit ergäbe als
    /// dieser Wert (km/h), ist ein GPS-Sprung (z. B. nach einem Tunnel) und
    /// wird verworfen, statt in die Distanz einzurechnen.
    private let maximalPlausibleGeschwindigkeitKmh: Double = 250
    /// Ohne verwertbaren Punkt über diese Dauer gilt das Signal als verloren.
    private let signalVerlustSchwelle: TimeInterval = 20
    /// Ab dieser Standzeit wird die Abtastrate zusätzlich reduziert (langes
    /// Halten, z. B. ein Termin vor Ort während einer mehrteiligen Fahrt).
    private let langeStandzeitSchwelle: TimeInterval = 180
    /// Nur Bewegung oberhalb dieser Geschwindigkeit gilt als „Fahrt hat
    /// wieder begonnen“ – filtert GPS-Jitter im Stand heraus.
    private let bewegungsSchwelleKmh: Double = 5
    /// Ziel-Adresse wird höchstens alle 150 m neu ermittelt, um nicht bei
    /// jedem einzelnen Punkt einen Geocoding-Aufruf auszulösen.
    private let zielGeocodierungsAbstand: CLLocationDistance = 150

    private(set) var isTracking = false
    private(set) var aktuelleGeschwindigkeit: Double = 0
    private(set) var aktuelleKm: Double = 0
    private(set) var signalStatus: GPSSignalStatus = .suche
    private(set) var startAdresse: String?
    private(set) var zielAdresse: String?
    private(set) var gpsVerlustSeit: Date?

    override init() {
        super.init()
        locationManager.delegate = self
        // Die App steuert Genauigkeit/Frequenz selbst über `passeGenauigkeitAn`.
        // Automatisches Pausieren bliebe hingegen unvorhersehbar und könnte
        // dazu führen, dass eine aktive Fahrt unbemerkt nicht mehr
        // aktualisiert wird – deshalb bewusst deaktiviert.
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = .automotiveNavigation
        passeGenauigkeitAn(geschwindigkeitKmh: 0)
    }

    /// Startet eine neue Aufzeichnung. Setzt mindestens die
    /// Vordergrund-Berechtigung voraus (siehe `LocationPermissionCoordinator`);
    /// ohne Berechtigung passiert nichts.
    func startTracking() {
        guard !isTracking else { return }
        let status = locationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }

        punkte.removeAll()
        startZeitpunkt = .now
        letzterGeocodierterZielPunkt = nil
        letzteBewegungAm = .now
        aktuelleKm = 0
        aktuelleGeschwindigkeit = 0
        signalStatus = .suche
        gpsVerlustSeit = nil
        gpsSignalGingWaehrendSessionVerloren = false
        startAdresse = nil
        zielAdresse = nil

        // Hintergrundaktualisierung ausschließlich für die Dauer dieser
        // ausdrücklich gestarteten Fahrt – niemals darüber hinaus. Erfordert
        // zusätzlich den Info.plist-Eintrag `UIBackgroundModes: [location]`
        // (siehe Configuration/Info.plist).
        let hatHintergrundBerechtigung = status == .authorizedAlways
        locationManager.allowsBackgroundLocationUpdates = hatHintergrundBerechtigung
        locationManager.showsBackgroundLocationIndicator = hatHintergrundBerechtigung

        isTracking = true
        locationManager.startUpdatingLocation()
        starteUeberwachung()
    }

    /// Beendet die Aufzeichnung, stoppt CoreLocation zuverlässig und liefert
    /// ein verdichtetes, nicht persistentes Ergebnis. `punkte` wird geleert.
    @discardableResult
    func stopTracking() -> TrackingErgebnis? {
        guard isTracking, let startZeitpunkt else { return nil }

        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.showsBackgroundLocationIndicator = false
        ueberwachungsTimer?.invalidate()
        ueberwachungsTimer = nil
        isTracking = false

        let ergebnis = TrackingErgebnis(
            startZeitpunkt: startZeitpunkt,
            endZeitpunkt: .now,
            distanzKm: aktuelleKm,
            startAdresse: startAdresse,
            zielAdresse: zielAdresse,
            gpsSignalGingVerloren: gpsSignalGingWaehrendSessionVerloren
        )

        punkte.removeAll()
        self.startZeitpunkt = nil

        return ergebnis
    }

    /// Flüchtige Kopie der Session-Punkte ausschließlich für die kurzzeitige
    /// Kartenvorschau in `TrackingView`. Wird nirgends gespeichert und ist
    /// nicht Teil von `TrackingErgebnis`.
    var vorschauPunkte: [CLLocation] {
        punkte
    }

    // MARK: - Smart Sampling (Batterieoptimierung)

    /// Passt `desiredAccuracy`/`distanceFilter` an Geschwindigkeit und
    /// Standzeit an:
    /// - Langes Halten (> `langeStandzeitSchwelle`): minimale Frequenz,
    ///   maximale Akkuschonung, Tracking bleibt aber aktiv.
    /// - Kurzer Stillstand (< 3 km/h): reduzierte, aber reaktionsfähige Frequenz.
    /// - Stadtverkehr/Stop-and-go (3–50 km/h): engmaschig und genau.
    /// - Autobahn (> 50 km/h): gleichmäßige, hohe Geschwindigkeit – ein
    ///   größerer Punktabstand genügt für eine korrekte Distanzberechnung.
    private func passeGenauigkeitAn(geschwindigkeitKmh: Double) {
        let standzeitDauer = Date.now.timeIntervalSince(letzteBewegungAm)

        if standzeitDauer >= langeStandzeitSchwelle {
            locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            locationManager.distanceFilter = 100
        } else if geschwindigkeitKmh < 3 {
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 25
        } else if geschwindigkeitKmh < 50 {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = 10
        } else {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = 20
        }
    }

    // MARK: - Plausibilitätsprüfung

    /// Verwirft offensichtlich ungenaue oder unrealistische Punkte, bevor sie
    /// in Distanz- oder Geschwindigkeitsberechnung einfließen.
    private func istPlausibel(_ neuerPunkt: CLLocation, nach letzterPunkt: CLLocation?) -> Bool {
        guard neuerPunkt.horizontalAccuracy >= 0,
              neuerPunkt.horizontalAccuracy <= maximaleUngenauigkeit else {
            return false
        }
        guard abs(neuerPunkt.timestamp.timeIntervalSinceNow) < maximalesPunktAlter else {
            return false
        }
        guard let letzterPunkt else { return true }

        let entfernung = neuerPunkt.distance(from: letzterPunkt)
        let zeitDifferenz = neuerPunkt.timestamp.timeIntervalSince(letzterPunkt.timestamp)
        guard zeitDifferenz > 0 else { return false }

        let impliziierteGeschwindigkeitKmh = (entfernung / zeitDifferenz) * 3.6
        // Ein GPS-Sprung (z. B. nach einem Tunnel) ergäbe eine unrealistische
        // Geschwindigkeit – dieser Punkt wird verworfen, statt die Strecke
        // künstlich zu verlängern.
        return impliziierteGeschwindigkeitKmh <= maximalPlausibleGeschwindigkeitKmh
    }

    // MARK: - Periodische Überwachung (Signalverlust & langes Halten)

    private func starteUeberwachung() {
        ueberwachungsTimer?.invalidate()
        ueberwachungsTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.periodischePruefung()
        }
    }

    /// Läuft unabhängig von eingehenden Standort-Updates, damit sowohl ein
    /// Signalverlust als auch ein sehr langes Halten (ohne neue Punkte durch
    /// den vergrößerten `distanceFilter`) zuverlässig erkannt werden.
    private func periodischePruefung() {
        guard isTracking else { return }

        if let letzterPunkt = punkte.last {
            let vergangeneZeit = Date.now.timeIntervalSince(letzterPunkt.timestamp)
            if vergangeneZeit > signalVerlustSchwelle {
                if gpsVerlustSeit == nil {
                    gpsVerlustSeit = letzterPunkt.timestamp
                }
                gpsSignalGingWaehrendSessionVerloren = true
                signalStatus = .verloren
                aktuelleGeschwindigkeit = 0
            }
        }

        passeGenauigkeitAn(geschwindigkeitKmh: aktuelleGeschwindigkeit)
    }

    // MARK: - Adressermittlung

    /// Wird einmalig für den ersten gültigen Punkt der Session aufgerufen.
    private func ermittleStartAdresse(fuer punkt: CLLocation) {
        guard !geocoder.isGeocoding else { return }
        geocoder.reverseGeocodeLocation(punkt) { [weak self] platzmarken, _ in
            guard let self, let adresse = platzmarken?.first?.kompletteAdresse else { return }
            DispatchQueue.main.async {
                self.startAdresse = adresse
            }
        }
    }

    /// Aktualisiert die (vorläufige) Zieladresse höchstens alle
    /// `zielGeocodierungsAbstand` Meter, um nicht bei jedem Punkt einen
    /// Geocoding-Aufruf auszulösen.
    private func aktualisiereZielAdresseFallsNoetig(mit punkt: CLLocation) {
        if let letzter = letzterGeocodierterZielPunkt, punkt.distance(from: letzter) < zielGeocodierungsAbstand {
            return
        }
        guard !geocoder.isGeocoding else { return }
        letzterGeocodierterZielPunkt = punkt

        geocoder.reverseGeocodeLocation(punkt) { [weak self] platzmarken, _ in
            guard let self, let adresse = platzmarken?.first?.kompletteAdresse else { return }
            DispatchQueue.main.async {
                self.zielAdresse = adresse
            }
        }
    }
}

extension TrackingManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isTracking else { return }

        for punkt in locations {
            guard istPlausibel(punkt, nach: punkte.last) else { continue }

            if let letzterPunkt = punkte.last {
                let zusaetzlicheDistanz = punkt.distance(from: letzterPunkt)
                aktuelleKm += zusaetzlicheDistanz / 1000

                let zeitDifferenz = punkt.timestamp.timeIntervalSince(letzterPunkt.timestamp)
                if zeitDifferenz > 0 {
                    aktuelleGeschwindigkeit = max(0, (zusaetzlicheDistanz / zeitDifferenz) * 3.6)
                }
            } else {
                ermittleStartAdresse(fuer: punkt)
            }

            punkte.append(punkt)

            if aktuelleGeschwindigkeit > bewegungsSchwelleKmh {
                letzteBewegungAm = punkt.timestamp
            }
            if gpsVerlustSeit != nil {
                gpsVerlustSeit = nil
            }
            signalStatus = punkt.horizontalAccuracy <= 20 ? .gut : .schwach

            aktualisiereZielAdresseFallsNoetig(mit: punkt)
            passeGenauigkeitAn(geschwindigkeitKmh: aktuelleGeschwindigkeit)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Einzelne, transiente Fehler (z. B. kurzzeitig kein Fix) führen
        // nicht sofort zum Abbruch. `periodischePruefung()` entscheidet
        // anhand der seit dem letzten gültigen Punkt vergangenen Zeit, ob
        // das Signal tatsächlich als verloren gilt.
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Erlaubt es, „Immer“ nachträglich WÄHREND einer laufenden
        // Aufzeichnung zu aktivieren (siehe TrackingView), ohne die Fahrt
        // neu starten zu müssen.
        guard isTracking else { return }
        let hatHintergrundBerechtigung = manager.authorizationStatus == .authorizedAlways
        locationManager.allowsBackgroundLocationUpdates = hatHintergrundBerechtigung
        locationManager.showsBackgroundLocationIndicator = hatHintergrundBerechtigung
    }
}

private extension CLPlacemark {
    /// Baut aus den Placemark-Bestandteilen eine vollständige Adresse
    /// (Straße, PLZ, Ort) zusammen, wie sie `Fahrt.startAdresse`/`zielAdresse`
    /// erwartet.
    var kompletteAdresse: String? {
        var bestandteile: [String] = []
        if let strasse = thoroughfare {
            if let hausnummer = subThoroughfare {
                bestandteile.append("\(strasse) \(hausnummer)")
            } else {
                bestandteile.append(strasse)
            }
        }

        var ortsteil: [String] = []
        if let plz = postalCode { ortsteil.append(plz) }
        if let ort = locality { ortsteil.append(ort) }
        if !ortsteil.isEmpty {
            bestandteile.append(ortsteil.joined(separator: " "))
        }

        guard !bestandteile.isEmpty else { return nil }
        return bestandteile.joined(separator: ", ")
    }
}
