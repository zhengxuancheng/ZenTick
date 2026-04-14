import SwiftUI
import SwiftData

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var storeService
    @AppStorage("healthKitEnabled") private var healthKitEnabled = false
    @State private var viewModel = TimerViewModel()
    @State private var showCompletion = false

    var body: some View {
        Group {
            if viewModel.isTimerActive {
                TimerRunningView(viewModel: viewModel) {
                    viewModel.completeSession(
                        modelContext: modelContext,
                        syncHealth: healthKitEnabled && storeService.isPro
                    )
                    showCompletion = true
                }
            } else {
                NavigationStack {
                    TimerSetupView(viewModel: viewModel)
                        .navigationTitle("ZenTick")
                        .navigationBarTitleDisplayMode(.inline)
                }
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
        .alert("Session Complete", isPresented: $showCompletion) {
            Button("OK") { }
        } message: {
            let minutes = Int(viewModel.timerService.totalDuration / 60)
            Text("You meditated for \(minutes) minutes. Session saved.")
        }
    }
}
