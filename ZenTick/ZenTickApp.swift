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

                Tab(String(localized: "history_title"), systemImage: "calendar", value: "history") {
                    HistoryView()
                }

                Tab(String(localized: "stats_title"), systemImage: "chart.bar", value: "stats") {
                    StatsView()
                }

                Tab(String(localized: "settings_title"), systemImage: "gearshape", value: "settings") {
                    SettingsView()
                }
            }
            .environment(storeService)
            .preferredColorScheme(resolvedColorScheme)
            .onOpenURL { url in
                handleDeepLink(url)
            }
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

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "zentick" else { return }
        switch url.host {
        case "timer": selectedTab = "timer"
        case "history": selectedTab = "history"
        case "stats": selectedTab = "stats"
        case "settings": selectedTab = "settings"
        default: selectedTab = "timer"
        }
    }
}
