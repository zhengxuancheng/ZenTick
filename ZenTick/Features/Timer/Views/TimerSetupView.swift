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
        Text("\(Int(viewModel.selectedDuration / 60)) min")
            .font(.system(size: 64, weight: .thin, design: .rounded))
            .monospacedDigit()
            .padding(.top, 20)
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
                    viewModel.selectedDuration = preset
                }
            }

            PresetButton(
                label: "Custom",
                isSelected: !viewModel.durationPresets.contains(viewModel.selectedDuration)
            ) {
                showCustomPicker = true
            }
        }
    }

    var bellSettings: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Start Bell")
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Strikes", selection: $viewModel.startBellStrikes) {
                    Text("Off").tag(0)
                    Text("1x").tag(1)
                    Text("3x").tag(3)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            HStack {
                Text("Interval Bell")
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Interval", selection: $viewModel.intervalMinutes) {
                    Text("Off").tag(0)
                    Text("5 min").tag(5)
                    Text("10 min").tag(10)
                    Text("15 min").tag(15)
                }
                .pickerStyle(.menu)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    var startButton: some View {
        Button {
            viewModel.startTimer()
        } label: {
            Text("Begin")
                .font(.title2.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 28))
        }
        .padding(.top, 8)
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
        }
    }
}

// MARK: - Custom Duration Picker

private struct CustomDurationPicker: View {
    @Binding var minutes: Int
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            Picker("Minutes", selection: $minutes) {
                ForEach(1...120, id: \.self) { m in
                    Text("\(m) min").tag(m)
                }
            }
            .pickerStyle(.wheel)
            .navigationTitle("Custom Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onConfirm)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
