import SwiftUI

struct TimerSetupView: View {
    @Bindable var viewModel: TimerViewModel
    @State private var showCustomPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                durationDisplay
                presetGrid
                bellSettings
                startButton
            }
            .padding()
        }
        .sheet(isPresented: $showCustomPicker) {
            CustomDurationPicker(minutes: $viewModel.customMinutes) {
                viewModel.selectedDuration = TimeInterval(viewModel.customMinutes * 60)
                showCustomPicker = false
            }
        }
    }
}

// MARK: - Subviews

private extension TimerSetupView {
    var durationDisplay: some View {
        Text(String(localized: "duration_display \(Int(viewModel.selectedDuration / 60))"))
            .font(.system(size: 64, weight: .thin, design: .rounded))
            .monospacedDigit()
            .padding(.top, 20)
            .contentTransition(.numericText())
            .animation(.spring(duration: 0.3), value: viewModel.selectedDuration)
            .accessibilityLabel(String(localized: "a11y_duration \(Int(viewModel.selectedDuration / 60))"))
    }

    var presetGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
            spacing: 12
        ) {
            ForEach(viewModel.durationPresets, id: \.self) { preset in
                PresetButton(
                    label: viewModel.presetLabel(for: preset),
                    isSelected: viewModel.selectedDuration == preset
                ) {
                    HapticService.selection()
                    viewModel.selectedDuration = preset
                }
            }

            PresetButton(
                label: String(localized: "custom"),
                isSelected: !viewModel.durationPresets.contains(viewModel.selectedDuration)
            ) {
                HapticService.selection()
                showCustomPicker = true
            }
        }
    }

    var bellSettings: some View {
        VStack(spacing: 16) {
            HStack {
                Text(String(localized: "start_bell"))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker(String(localized: "strikes"), selection: $viewModel.startBellStrikes) {
                    Text(String(localized: "bell_off")).tag(0)
                    Text("1x").tag(1)
                    Text("3x").tag(3)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            HStack {
                Text(String(localized: "interval_bell"))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker(String(localized: "interval"), selection: $viewModel.intervalMinutes) {
                    Text(String(localized: "bell_off")).tag(0)
                    Text(String(localized: "minutes_5")).tag(5)
                    Text(String(localized: "minutes_10")).tag(10)
                    Text(String(localized: "minutes_15")).tag(15)
                }
                .pickerStyle(.menu)
            }

            HStack {
                Text(String(localized: "ambient_sound"))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker(String(localized: "ambient_sound"), selection: $viewModel.selectedAmbientSound) {
                    ForEach(AmbientSound.allCases) { sound in
                        Text(sound.displayName).tag(sound)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    var startButton: some View {
        Button {
            HapticService.medium()
            viewModel.startTimer()
        } label: {
            Text(String(localized: "begin"))
                .font(.title2.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 28))
        }
        .padding(.top, 8)
        .accessibilityHint(String(localized: "a11y_begin_hint \(Int(viewModel.selectedDuration / 60))"))
    }
}

// MARK: - Preset Button

private struct PresetButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    isSelected ? Color.accentColor : Color(.systemGray5),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
    }
}

// MARK: - Custom Duration Picker

private struct CustomDurationPicker: View {
    @Binding var minutes: Int
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            Picker(String(localized: "minutes"), selection: $minutes) {
                ForEach(1...120, id: \.self) { m in
                    Text(String(localized: "duration_display \(m)")).tag(m)
                }
            }
            .pickerStyle(.wheel)
            .navigationTitle(String(localized: "custom_duration"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "done"), action: onConfirm)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
