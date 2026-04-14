import Foundation

#if canImport(HealthKit)
import HealthKit

final class HealthKitService {
    private let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            return false
        }

        do {
            try await healthStore.requestAuthorization(toShare: [mindfulType], read: [])
            return true
        } catch {
            return false
        }
    }

    func saveMindfulSession(startDate: Date, duration: TimeInterval) async -> Bool {
        guard isAvailable else { return false }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            return false
        }

        let endDate = startDate.addingTimeInterval(duration)
        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: startDate,
            end: endDate
        )

        do {
            try await healthStore.save(sample)
            return true
        } catch {
            return false
        }
    }
}
#else
final class HealthKitService {
    var isAvailable: Bool { false }
    func requestAuthorization() async -> Bool { false }
    func saveMindfulSession(startDate: Date, duration: TimeInterval) async -> Bool { false }
}
#endif
