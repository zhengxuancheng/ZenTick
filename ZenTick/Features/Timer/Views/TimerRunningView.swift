import SwiftUI

struct TimerRunningView: View {
    @Bindable var viewModel: TimerViewModel
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.timerBackground
                .ignoresSafeArea()

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
        .onChange(of: viewModel.timerService.isCompleted) { _, completed in
            if completed {
                onComplete()
            }
        }
    }
}

// MARK: - Subviews

private extension TimerRunningView {
    var timerDisplay: some View {
        Text(viewModel.formattedTime)
            .font(.system(size: 80, weight: .ultraLight, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
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
                .animation(.linear(duration: 0.1), value: viewModel.timerService.progress)
        }
        .frame(width: 200, height: 200)
    }

    var controls: some View {
        HStack(spacing: 48) {
            Button {
                viewModel.stopTimer()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 60, height: 60)
                    .background(Color.white.opacity(0.1), in: Circle())
            }

            Button {
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
        }
        .padding(.bottom, 48)
    }
}
