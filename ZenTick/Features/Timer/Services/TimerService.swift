import Foundation

@Observable
final class TimerService {
    var remainingSeconds: TimeInterval = 0
    var isRunning: Bool = false
    var isPaused: Bool = false
    var isCompleted: Bool = false

    // Preparation countdown
    var isPreparing: Bool = false
    var prepareRemaining: Int = 0

    var startDate: Date?
    private(set) var totalDuration: TimeInterval = 0
    private var timer: Timer?
    private var backgroundDate: Date?

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1.0 - (remainingSeconds / totalDuration)
    }

    func start(duration: TimeInterval, prepareSeconds: Int = 5) {
        totalDuration = duration
        remainingSeconds = duration
        isRunning = true
        isPaused = false
        isCompleted = false

        if prepareSeconds > 0 {
            isPreparing = true
            prepareRemaining = prepareSeconds
            startPrepareCountdown()
        } else {
            startDate = Date()
            startTimer()
        }
    }

    func pause() {
        guard !isPreparing else { return }
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
        isPreparing = false
        prepareRemaining = 0
        remainingSeconds = 0
    }

    func appDidEnterBackground() {
        guard isRunning, !isPaused, !isPreparing else { return }
        backgroundDate = Date()
        timer?.invalidate()
        timer = nil
    }

    func appWillEnterForeground() {
        guard isRunning, !isPaused, !isPreparing, let bgDate = backgroundDate else { return }
        let elapsed = Date().timeIntervalSince(bgDate)
        remainingSeconds = max(0, remainingSeconds - elapsed)
        backgroundDate = nil

        if remainingSeconds <= 0 {
            complete()
        } else {
            startTimer()
        }
    }

    // MARK: - Preparation countdown

    private func startPrepareCountdown() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            MainActor.assumeIsolated {
                self.prepareTick()
            }
        }
    }

    private func prepareTick() {
        prepareRemaining -= 1
        if prepareRemaining <= 0 {
            timer?.invalidate()
            timer = nil
            isPreparing = false
            startDate = Date()
            startTimer()
        }
    }

    // MARK: - Main timer

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
