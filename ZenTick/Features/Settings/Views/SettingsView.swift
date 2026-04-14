import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(StoreService.self) private var storeService
    @AppStorage("selectedBellSound") private var selectedBellSound: String = BellSound.deepBowl.rawValue
    @AppStorage("defaultDuration") private var defaultDuration: Double = 600
    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system"
    @AppStorage("healthKitEnabled") private var healthKitEnabled: Bool = false
    @AppStorage("iCloudSync") private var iCloudSync: Bool = false

    @State private var audioService = AudioService()
    @State private var healthKitService = HealthKitService()
    @State private var isPurchasing = false
    @State private var showRestoreAlert = false

    var body: some View {
        NavigationStack {
            List {
                timerDefaultsSection
                bellSoundSection
                appearanceSection
                healthSection
                iCloudSection
                proSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Sections

private extension SettingsView {
    var timerDefaultsSection: some View {
        Section("Timer Defaults") {
            Picker("Default Duration", selection: $defaultDuration) {
                Text("5 min").tag(300.0)
                Text("10 min").tag(600.0)
                Text("15 min").tag(900.0)
                Text("20 min").tag(1200.0)
                Text("30 min").tag(1800.0)
                Text("45 min").tag(2700.0)
                Text("60 min").tag(3600.0)
            }
        }
    }

    var bellSoundSection: some View {
        Section("Bell Sound") {
            ForEach(BellSound.allCases) { bell in
                HStack {
                    Text(bell.rawValue)
                    Spacer()
                    if selectedBellSound == bell.rawValue {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if !storeService.isPro && (bell == .warmBowl || bell == .crystalBowl) {
                        return
                    }
                    selectedBellSound = bell.rawValue
                    audioService.configureAudioSession()
                    audioService.playBell(bell)
                }
                .opacity(proLocked(bell) ? 0.5 : 1)
                .overlay(alignment: .trailing) {
                    if proLocked(bell) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, -20)
                    }
                }
            }
        }
    }

    var appearanceSection: some View {
        Section("Appearance") {
            Picker("Color Scheme", selection: $colorSchemePreference) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
        }
    }

    var healthSection: some View {
        Section {
            Toggle("Apple Health Sync", isOn: $healthKitEnabled)
                .disabled(!storeService.isPro)
                .onChange(of: healthKitEnabled) { _, enabled in
                    if enabled {
                        Task {
                            let granted = await healthKitService.requestAuthorization()
                            if !granted {
                                healthKitEnabled = false
                            }
                        }
                    }
                }

            if !storeService.isPro {
                ProUpsellRow(text: "Requires Pro")
            }
        } header: {
            Text("Health")
        } footer: {
            if healthKitEnabled && storeService.isPro {
                Text("Completed sessions will be saved as Mindful Minutes in Apple Health.")
            }
        }
    }

    var iCloudSection: some View {
        Section {
            Toggle("iCloud Sync", isOn: $iCloudSync)
        } header: {
            Text("Sync")
        } footer: {
            Text("Sync your meditation history across your Apple devices via iCloud.")
        }
    }

    var proSection: some View {
        Section {
            if storeService.isPro {
                Label("Pro Unlocked", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Color.accentColor)
            } else {
                Button {
                    Task {
                        isPurchasing = true
                        defer { isPurchasing = false }
                        _ = try? await storeService.purchase()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Unlock ZenTick Pro")
                                .font(.headline)
                            Text("Full history, stats, custom bells, Health sync")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if isPurchasing {
                            ProgressView()
                        } else {
                            Text(storeService.proProduct?.displayPrice ?? "$4.99")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
                .disabled(isPurchasing)

                Button("Restore Purchases") {
                    Task {
                        await storeService.restore()
                        showRestoreAlert = true
                    }
                }
                .alert("Restore Complete", isPresented: $showRestoreAlert) {
                    Button("OK") { }
                } message: {
                    Text(
                        storeService.isPro
                            ? "Pro has been restored!"
                            : "No previous purchase found."
                    )
                }
            }
        } header: {
            Text("Pro")
        }
    }

    var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(
                    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                )
                .foregroundStyle(.secondary)
            }
        }
    }

    func proLocked(_ bell: BellSound) -> Bool {
        !storeService.isPro && (bell == .warmBowl || bell == .crystalBowl)
    }
}
