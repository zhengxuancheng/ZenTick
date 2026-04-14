import Foundation
import SwiftData

@Model
final class MeditationSession {
    var id: UUID
    var startDate: Date
    var duration: TimeInterval
    var completed: Bool

    init(startDate: Date, duration: TimeInterval, completed: Bool = true) {
        self.id = UUID()
        self.startDate = startDate
        self.duration = duration
        self.completed = completed
    }
}
