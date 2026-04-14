import Foundation

@Observable
final class TimerService {
    var remainingSeconds: TimeInterval = 0
    var isRunning: Bool = false
    var isPaused: Bool = false
    var isCompleted: Bool = false

    private(set) var startDate: Date?
    private(set) var totalDuration: TimeInterval = 0
    private var timer: Timer?
    private var backgroundDate: Date?

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1.0 - (remainingSeconds / totalDuration)
    }

    func start(duration: TimeInterval) {
        totalDuration = duration
        remainingSeconds = duration
        startDate = Date()
        isRunning = true
        isPaused = false
        isCompleted = false
        startTimer()
    }

    func pause() {
        isPaused = true
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        isPaused = false
        startTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        isCompleted = false
        remainingSeconds = 0
    }

    func appDidEnterBackground() {
        guard isRunning, !isPaused else { return }
        backgroundDate = Date()
        timer?.invalidate()
        timer = nil
    }

    func appWillEnterForeground() {
        guard isRunning, !isPaused, let bgDate = backgroundDate else { return }
        let elapsed = Date().timeIntervalSince(bgDate)
        remainingSeconds = max(0, remainingSeconds - elapsed)
        backgroundDate = nil

        if remainingSeconds <= 0 {
            complete()
        } else {
            startTimer()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            MainActor.assumeIsolated {
                self.tick()
            }
        }
    }

    private func tick() {
        remainingSeconds -= 0.1
        if remainingSeconds <= 0 {
            remainingSeconds = 0
            complete()
        }
    }

    private func complete() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        isCompleted = true
    }
}
