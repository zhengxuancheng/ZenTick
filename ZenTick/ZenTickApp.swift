import SwiftUI
import SwiftData

@main
struct ZenTickApp: App {
    @State private var storeService = StoreService()
    @State private var selectedTab = "timer"
    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system"

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                Tab("Timer", systemImage: "timer", value: "timer") {
                    TimerView()
                }

                Tab("History", systemImage: "calendar", value: "history") {
                    HistoryView()
                }

                Tab("Stats", systemImage: "chart.bar", value: "stats") {
                    StatsView()
                }

                Tab("Settings", systemImage: "gearshape", value: "settings") {
                    SettingsView()
                }
            }
            .environment(storeService)
            .preferredColorScheme(resolvedColorScheme)
        }
        .modelContainer(for: MeditationSession.self)
    }

    private var resolvedColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "dark": .dark
        case "light": .light
        default: nil
        }
    }
}
