import Foundation
import HealthKit

final class HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()
    private var didRequest = false

    func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        if didRequest {
            completion(true)
            return
        }

        var typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            typesToShare.insert(mindful)
        }
        // Keep read set minimal; only request what we actually use. Currently, we only write mindful sessions.
        let typesToRead = Set<HKObjectType>()

        store.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, _ in
            if success { self.didRequest = true }
            completion(success)
        }
    }

    func saveMindfulSession(start: Date, end: Date, completion: ((Bool) -> Void)? = nil) {
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            completion?(false)
            return
        }
        let sample = HKCategorySample(type: mindfulType, value: HKCategoryValue.notApplicable.rawValue, start: start, end: end)
        store.save(sample) { success, _ in
            completion?(success)
        }
    }
}
