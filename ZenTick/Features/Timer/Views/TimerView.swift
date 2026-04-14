import SwiftUI
import SwiftData

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var storeService
    @AppStorage("healthKitEnabled") private var healthKitEnabled = false
    @State private var viewModel = TimerViewModel()
    @State private var showCompletion = false
    @State private var lastSession: MeditationSession?

    var body: some View {
        Group {
            if showCompletion {
                CompletionView(
                    durationMinutes: Int(viewModel.timerService.totalDuration / 60),
                    note: $viewModel.sessionNote
                ) {
                    viewModel.saveNote(to: lastSession)
                    showCompletion = false
                    lastSession = nil
                }
                .transition(.opacity)
            } else if viewModel.isTimerActive {
                TimerRunningView(viewModel: viewModel) {
                    let session = createSession()
                    lastSession = session
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showCompletion = true
                    }
                }
            } else {
                NavigationStack {
                    TimerSetupView(viewModel: viewModel)
                        .navigationTitle("ZenTick")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isTimerActive)
        .onChange(of: viewModel.timerService.isPreparing) { old, new in
            if old && !new {
                viewModel.onPrepareFinished()
            }
        }
        #if os(iOS)
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
        ) { _ in
            viewModel.handleBackground()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
        ) { _ in
            viewModel.handleForeground()
        }
        #endif
    }

    private func createSession() -> MeditationSession? {
        guard viewModel.timerService.isCompleted, let startDate = viewModel.timerService.startDate else { return nil }

        viewModel.audioService.playBell(viewModel.selectedBellSound, strikes: 1)
        viewModel.ambientService.stop()

        let session = MeditationSession(
            startDate: startDate,
            duration: viewModel.timerService.totalDuration,
            completed: true
        )
        modelContext.insert(session)

        if healthKitEnabled && storeService.isPro {
            let duration = viewModel.timerService.totalDuration
            Task {
                _ = await viewModel.healthKitService.saveMindfulSession(
                    startDate: startDate,
                    duration: duration
                )
            }
        }

        viewModel.timerService.isCompleted = false
        return session
    }
}
