import SwiftUI

struct TimerRunningView: View {
    @Bindable var viewModel: TimerViewModel
    let onComplete: () -> Void
    @State private var showStopConfirm = false

    var body: some View {
        ZStack {
            Color.timerBackground
                .ignoresSafeArea()

            if viewModel.timerService.isPreparing {
                prepareOverlay
            } else {
                VStack(spacing: 0) {
                    Spacer()
                    timerDisplay
                    Spacer()
                        .frame(height: 40)
                    progressRing
                    Spacer()
                    controls
                }
                .padding()
            }
        }
        #if os(iOS)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        #endif
        .onChange(of: viewModel.timerService.isCompleted) { _, completed in
            if completed {
                HapticService.success()
                onComplete()
            }
        }
        .onChange(of: viewModel.timerService.isPreparing) { old, new in
            if old && !new {
                // Preparation just finished, play bell
                HapticService.light()
            }
        }
        .confirmationDialog(
            String(localized: "stop_confirm_title"),
            isPresented: $showStopConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "stop_confirm_yes"), role: .destructive) {
                HapticService.medium()
                viewModel.stopTimer()
            }
            Button(String(localized: "stop_confirm_cancel"), role: .cancel) { }
        } message: {
            Text(String(localized: "stop_confirm_message"))
        }
    }
}

// MARK: - Subviews

private extension TimerRunningView {
    var prepareOverlay: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(String(localized: "prepare_title"))
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))

            Text("\(viewModel.timerService.prepareRemaining)")
                .font(.system(size: 120, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: viewModel.timerService.prepareRemaining)

            Text(String(localized: "prepare_hint"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))

            Spacer()

            Button {
                HapticService.light()
                viewModel.skipPrepare()
            } label: {
                Text(String(localized: "prepare_skip"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.bottom, 60)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "a11y_preparing \(viewModel.timerService.prepareRemaining)"))
    }

    var timerDisplay: some View {
        Text(viewModel.formattedTime)
            .font(.system(size: 80, weight: .ultraLight, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .contentTransition(.numericText())
            .animation(.linear(duration: 0.1), value: viewModel.formattedTime)
            .accessibilityLabel(String(localized: "a11y_remaining \(viewModel.formattedTime)"))
    }

    var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 3)

            Circle()
                .trim(from: 0, to: viewModel.timerService.progress)
                .stroke(
                    Color.accentColor.opacity(0.7),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: viewModel.timerService.progress)
        }
        .frame(width: 200, height: 200)
        .accessibilityHidden(true)
    }

    var controls: some View {
        HStack(spacing: 48) {
            Button {
                HapticService.warning()
                showStopConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 60, height: 60)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .accessibilityLabel(String(localized: "a11y_stop"))

            Button {
                HapticService.light()
                if viewModel.timerService.isPaused {
                    viewModel.resumeTimer()
                } else {
                    viewModel.pauseTimer()
                }
            } label: {
                Image(systemName: viewModel.timerService.isPaused ? "play.fill" : "pause.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Color.accentColor, in: Circle())
            }
            .accessibilityLabel(
                viewModel.timerService.isPaused
                    ? String(localized: "a11y_resume")
                    : String(localized: "a11y_pause")
            )
        }
        .padding(.bottom, 48)
    }
}
