import SwiftUI
import SwiftData

/// Wurzel-Navigation der App: eine Standard-`TabView` mit drei Tabs, jeder
/// mit eigenem `NavigationStack`. Es gibt bewusst keine eigene TabBar, keinen
/// Floating-Tab-Bar-Ersatz und keine Emojis – ausschließlich die
/// systemeigene, seit iOS 26 mit Liquid-Glass-Optik gerenderte `TabView`.
struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                FahrtenListView()
            }
            .tabItem {
                Label("Fahrten", systemImage: "car.fill")
            }

            NavigationStack {
                UebersichtView()
            }
            .tabItem {
                Label("Übersicht", systemImage: "chart.bar.fill")
            }

            NavigationStack {
                EinstellungenView()
            }
            .tabItem {
                Label("Einstellungen", systemImage: "gearshape.fill")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Fahrzeug.self, Fahrt.self, AuditEntry.self], inMemory: true)
}
