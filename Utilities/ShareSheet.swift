import SwiftUI
import UIKit

/// Standard-Share-Sheet (`UIActivityViewController`) für den Export von
/// Dateien.
///
/// Der Nutzer entscheidet in diesem System-Sheet selbst über das Ziel
/// (iCloud Drive, Dateien-App, AirDrop, Mail, …) – KilometerLog versendet
/// PDF-, CSV- oder DATEV-Dateien niemals selbstständig oder automatisch,
/// weder an einen eigenen Server noch an Dritte.
struct ShareSheet: UIViewControllerRepresentable {
    let dateiURLs: [URL]
    var abgeschlossen: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: dateiURLs, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            abgeschlossen?()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
