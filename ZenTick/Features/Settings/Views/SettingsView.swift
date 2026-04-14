import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(StoreService.self) private var storeService
    @AppStorage("selectedBellSound") private var selectedBellSound: String = BellSound.deepBowl.rawValue
    @AppStorage("defaultDuration") private var defaultDuration: Double = 600
    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system"
    @AppStorage("healthKitEnabled") private var healthKitEnabled: Bool = false
    @AppStorage("iCloudSync") private var iCloudSync: Bool = false
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled: Bool = false
    @AppStorage("dailyReminderHour") private var dailyReminderHour: Int = 8
    @AppStorage("dailyReminderMinute") private var dailyReminderMinute: Int = 0

    @State private var audioService = AudioService()
    @State private var healthKitService = HealthKitService()
    @State private var notificationService = NotificationService()
    @State private var isPurchasing = false
    @State private var showRestoreAlert = false
    @State private var playingBell: String?

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = dailyReminderHour
                components.minute = dailyReminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                dailyReminderHour = components.hour ?? 8
                dailyReminderMinute = components.minute ?? 0
                if dailyReminderEnabled {
                    notificationService.scheduleDailyReminder(
                        hour: dailyReminderHour, minute: dailyReminderMinute
                    )
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                timerDefaultsSection
                bellSoundSection
                reminderSection
                appearanceSection
                healthSection
                iCloudSection
                proSection
                aboutSection
            }
            .navigationTitle(String(localized: "settings_title"))
        }
    }
}

// MARK: - Sections

private extension SettingsView {
    var timerDefaultsSection: some View {
        Section(String(localized: "timer_defaults")) {
            Picker(String(localized: "default_duration"), selection: $defaultDuration) {
                Text(String(localized: "duration_display \(5)")).tag(300.0)
                Text(String(localized: "duration_display \(10)")).tag(600.0)
                Text(String(localized: "duration_display \(15)")).tag(900.0)
                Text(String(localized: "duration_display \(20)")).tag(1200.0)
                Text(String(localized: "duration_display \(30)")).tag(1800.0)
                Text(String(localized: "duration_display \(45)")).tag(2700.0)
                Text(String(localized: "duration_display \(60)")).tag(3600.0)
            }
        }
    }

    var bellSoundSection: some View {
        Section {
            ForEach(BellSound.allCases) { bell in
                HStack {
                    Text(bell.displayName)

                    if playingBell == bell.rawValue {
                        SoundWaveView()
                            .frame(width: 24, height: 16)
                            .padding(.leading, 4)
                    }

                    Spacer()

                    if selectedBellSound == bell.rawValue {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if proLocked(bell) { return }
                    HapticService.selection()
                    selectedBellSound = bell.rawValue
                    audioService.configureAudioSession()
                    audioService.playBell(bell)
                    playingBell = bell.rawValue
                    Task {
                        try? await Task.sleep(for: .seconds(3))
                        if playingBell == bell.rawValue {
                            playingBell = nil
                        }
                    }
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
                .accessibilityLabel(bell.displayName)
                .accessibilityHint(
                    proLocked(bell)
                        ? String(localized: "a11y_bell_locked")
                        : String(localized: "a11y_bell_tap_preview")
                )
            }
        } header: {
            Text(String(localized: "bell_sound"))
        } footer: {
            Text(String(localized: "bell_sound_footer"))
        }
    }

    var reminderSection: some View {
        Section {
            Toggle(String(localized: "daily_reminder"), isOn: $dailyReminderEnabled)
                .onChange(of: dailyReminderEnabled) { _, enabled in
                    if enabled {
                        Task {
                            let granted = await notificationService.requestAuthorization()
                            if granted {
                                notificationService.scheduleDailyReminder(
                                    hour: dailyReminderHour, minute: dailyReminderMinute
                                )
                            } else {
                                dailyReminderEnabled = false
                            }
                        }
                    } else {
                        notificationService.cancelDailyReminder()
                    }
                }

            if dailyReminderEnabled {
                DatePicker(
                    String(localized: "reminder_time"),
                    selection: reminderTime,
                    displayedComponents: .hourAndMinute
                )
            }
        } header: {
            Text(String(localized: "reminder"))
        } footer: {
            if dailyReminderEnabled {
                Text(String(localized: "reminder_footer"))
            }
        }
    }

    var appearanceSection: some View {
        Section(String(localized: "appearance")) {
            Picker(String(localized: "color_scheme"), selection: $colorSchemePreference) {
                Text(String(localized: "scheme_system")).tag("system")
                Text(String(localized: "scheme_light")).tag("light")
                Text(String(localized: "scheme_dark")).tag("dark")
            }
        }
    }

    var healthSection: some View {
        Section {
            Toggle(String(localized: "health_sync"), isOn: $healthKitEnabled)
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
                ProUpsellRow(text: String(localized: "requires_pro"))
            }
        } header: {
            Text(String(localized: "health"))
        } footer: {
            if healthKitEnabled && storeService.isPro {
                Text(String(localized: "health_footer"))
            }
        }
    }

    var iCloudSection: some View {
        Section {
            Toggle(String(localized: "icloud_sync"), isOn: $iCloudSync)
        } header: {
            Text(String(localized: "sync"))
        } footer: {
            Text(String(localized: "icloud_footer"))
        }
    }

    var proSection: some View {
        Section {
            if storeService.isPro {
                Label(String(localized: "pro_unlocked"), systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Color.accentColor)
            } else {
                Button {
                    HapticService.medium()
                    Task {
                        isPurchasing = true
                        defer { isPurchasing = false }
                        _ = try? await storeService.purchase()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "unlock_pro"))
                                .font(.headline)
                            Text(String(localized: "pro_features"))
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

                Button(String(localized: "restore_purchases")) {
                    HapticService.light()
                    Task {
                        await storeService.restore()
                        showRestoreAlert = true
                    }
                }
                .alert(String(localized: "restore_complete"), isPresented: $showRestoreAlert) {
                    Button(String(localized: "ok")) { }
                } message: {
                    Text(
                        storeService.isPro
                            ? String(localized: "restore_success")
                            : String(localized: "restore_not_found")
                    )
                }
            }
        } header: {
            Text("Pro")
        }
    }

    var aboutSection: some View {
        Section(String(localized: "about")) {
            HStack {
                Text(String(localized: "version"))
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

// MARK: - Sound Wave Animation

private struct SoundWaveView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 2.5)
                    .frame(height: animating ? CGFloat.random(in: 8...16) : 4)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}
