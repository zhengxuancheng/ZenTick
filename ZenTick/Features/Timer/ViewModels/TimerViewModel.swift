import Foundation
import SwiftData

@Observable
final class TimerViewModel {
    var selectedDuration: TimeInterval = 600
    var customMinutes: Int = 10
    var startBellStrikes: Int = 1
    var intervalMinutes: Int = 0
    var selectedBellSound: BellSound = .deepBowl

    let timerService = TimerService()
    let audioService = AudioService()
    let notificationService = NotificationService()
    let healthKitService = HealthKitService()

    var isTimerActive: Bool {
        timerService.isRunning || timerService.isCompleted
    }

    var formattedTime: String {
        let total = max(0, Int(timerService.remainingSeconds))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    let durationPresets: [TimeInterval] = [300, 600, 900, 1200, 1800, 2700, 3600]

    func presetLabel(for duration: TimeInterval) -> String {
        "\(Int(duration / 60)) min"
    }

    func startTimer() {
        audioService.configureAudioSession()

        if startBellStrikes > 0 {
            audioService.playBell(selectedBellSound, strikes: startBellStrikes)
        }

        timerService.start(duration: selectedDuration)

        Task {
            _ = await notificationService.requestAuthorization()
            let endDate = Date().addingTimeInterval(selectedDuration)
            notificationService.scheduleTimerEndNotification(at: endDate)
        }

        if intervalMinutes > 0 {
            startIntervalBells()
        }
    }

    func pauseTimer() {
        timerService.pause()
        notificationService.cancelTimerEndNotification()
        intervalTask?.cancel()
    }

    func resumeTimer() {
        timerService.resume()
        let endDate = Date().addingTimeInterval(timerService.remainingSeconds)
        notificationService.scheduleTimerEndNotification(at: endDate)

        if intervalMinutes > 0 {
            startIntervalBells()
        }
    }

    func stopTimer() {
        timerService.stop()
        notificationService.cancelTimerEndNotification()
        intervalTask?.cancel()
    }

    func completeSession(modelContext: ModelContext, syncHealth: Bool) {
        guard timerService.isCompleted, let startDate = timerService.startDate else { return }

        audioService.playBell(selectedBellSound, strikes: 1)

        let session = MeditationSession(
            startDate: startDate,
            duration: timerService.totalDuration,
            completed: true
        )
        modelContext.insert(session)

        if syncHealth {
            let duration = timerService.totalDuration
            Task {
                _ = await healthKitService.saveMindfulSession(
                    startDate: startDate,
                    duration: duration
                )
            }
        }

        timerService.isCompleted = false
    }

    func handleBackground() {
        timerService.appDidEnterBackground()
    }

    func handleForeground() {
        timerService.appWillEnterForeground()

        if timerService.isCompleted {
            audioService.configureAudioSession()
            audioService.playBell(selectedBellSound, strikes: 1)
        }
    }

    // MARK: - Interval bells

    private var intervalTask: Task<Void, Never>?

    private func startIntervalBells() {
        intervalTask?.cancel()
        guard intervalMinutes > 0 else { return }

        intervalTask = Task {
            let intervalSeconds = Double(intervalMinutes * 60)
            var nextBellAt = timerService.totalDuration - intervalSeconds

            while !Task.isCancelled && timerService.isRunning {
                if timerService.remainingSeconds <= nextBellAt && nextBellAt > 0 {
                    audioService.playBell(selectedBellSound, strikes: 1)
                    nextBellAt -= intervalSeconds
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
}
