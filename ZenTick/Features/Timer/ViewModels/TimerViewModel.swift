import Foundation
import SwiftData

@Observable
final class TimerViewModel {
    var selectedDuration: TimeInterval = 600
    var customMinutes: Int = 10
    var startBellStrikes: Int = 1
    var intervalMinutes: Int = 0
    var selectedBellSound: BellSound = .deepBowl
    var selectedAmbientSound: AmbientSound = .none
    var sessionNote: String = ""

    let timerService = TimerService()
    let audioService = AudioService()
    let ambientService = AmbientAudioService()
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
        String(localized: "duration_display \(Int(duration / 60))")
    }

    func startTimer() {
        audioService.configureAudioSession()
        sessionNote = ""
        timerService.start(duration: selectedDuration, prepareSeconds: 5)

        // Start ambient sound immediately during preparation
        if selectedAmbientSound != .none {
            ambientService.play(selectedAmbientSound)
        }
    }

    func onPrepareFinished() {
        // Play start bell when preparation ends and actual meditation begins
        if startBellStrikes > 0 {
            audioService.playBell(selectedBellSound, strikes: startBellStrikes)
        }

        Task {
            _ = await notificationService.requestAuthorization()
            let endDate = Date().addingTimeInterval(selectedDuration)
            notificationService.scheduleTimerEndNotification(at: endDate)
        }

        if intervalMinutes > 0 {
            startIntervalBells()
        }
    }

    func skipPrepare() {
        timerService.isPreparing = false
        timerService.prepareRemaining = 0
        if timerService.startDate == nil {
            timerService.startDate = Date()
        }
        onPrepareFinished()
    }

    func pauseTimer() {
        timerService.pause()
        ambientService.pause()
        notificationService.cancelTimerEndNotification()
        intervalTask?.cancel()
    }

    func resumeTimer() {
        timerService.resume()
        ambientService.resume()
        let endDate = Date().addingTimeInterval(timerService.remainingSeconds)
        notificationService.scheduleTimerEndNotification(at: endDate)

        if intervalMinutes > 0 {
            startIntervalBells()
        }
    }

    func stopTimer() {
        timerService.stop()
        ambientService.stop()
        notificationService.cancelTimerEndNotification()
        intervalTask?.cancel()
    }

    func saveNote(to session: MeditationSession?) {
        guard let session, !sessionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        session.note = sessionNote.trimmingCharacters(in: .whitespacesAndNewlines)
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
