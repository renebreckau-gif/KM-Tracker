import CoreLocation
import Observation

/// Kapselt den zweistufigen Berechtigungsfluss für den Standortzugriff:
///
/// 1. **Vordergrund** (`.authorizedWhenInUse`) – wird beim ersten Versuch,
///    eine Fahrt zu starten, angefragt. Reicht aus, solange die App im
///    Vordergrund bleibt.
/// 2. **Hintergrund** (`.authorizedAlways`) – wird ausschließlich dann
///    angefragt, wenn der Nutzer bereits eine aktive Aufzeichnung laufen hat
///    und in `TrackingView` ausdrücklich einer klaren Erklärung zustimmt,
///    dass die Fahrt sonst bei gesperrtem Bildschirm oder App-Wechsel
///    pausiert. Es gibt keine automatische oder stille Always-Anfrage beim
///    App-Start oder vor dem ersten „Fahrt starten“.
///
/// `LocationPermissionCoordinator` fragt selbst keine Standort-Updates ab –
/// dafür ist ausschließlich `TrackingManager` zuständig.
@Observable
final class LocationPermissionCoordinator: NSObject {
    private let locationManager = CLLocationManager()

    private(set) var status: CLAuthorizationStatus

    override init() {
        status = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
    }

    var hatVordergrundBerechtigung: Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }

    var hatHintergrundBerechtigung: Bool {
        status == .authorizedAlways
    }

    /// `true`, wenn der Nutzer den Zugriff endgültig verweigert hat (nicht
    /// zu verwechseln mit `.notDetermined`, wo die Systemabfrage noch
    /// aussteht). In diesem Fall hilft nur noch der Umweg über die
    /// Systemeinstellungen.
    var istEndgueltigAbgelehnt: Bool {
        status == .denied || status == .restricted
    }

    func fordereVordergrundBerechtigungAn() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Nur aufrufen, nachdem der Nutzer `hintergrundErklaerung` gesehen und
    /// der Fortführung bei gesperrtem Bildschirm ausdrücklich zugestimmt hat.
    func fordereHintergrundBerechtigungAn() {
        locationManager.requestAlwaysAuthorization()
    }

    /// Erklärtext für den ersten, obligatorischen Berechtigungsschritt.
    static let vordergrundErklaerung =
        "KilometerLog benötigt deinen Standort, um während einer von dir gestarteten Fahrt automatisch die gefahrene Strecke zu ermitteln. Der Standort wird ausschließlich während einer aktiven Aufzeichnung verwendet – nie im Hintergrund außerhalb einer Fahrt."

    /// Erklärtext für den optionalen Zusatzschritt „Immer erlauben“, der nur
    /// während einer bereits laufenden Aufzeichnung angezeigt wird.
    static let hintergrundErklaerung =
        "Damit deine Fahrt auch bei gesperrtem Bildschirm oder beim Wechsel zu einer anderen App zuverlässig weiter aufgezeichnet wird, benötigt KilometerLog zusätzlich die Berechtigung „Immer“. Ohne diese Berechtigung pausiert die Aufzeichnung, sobald die App in den Hintergrund wechselt. Auch mit „Immer“ wird dein Standort ausschließlich während einer von dir gestarteten Fahrt verwendet."
}

extension LocationPermissionCoordinator: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
    }
}
