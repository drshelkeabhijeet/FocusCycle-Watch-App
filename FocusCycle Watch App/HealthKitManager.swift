import Foundation
import HealthKit

/// All HealthKit read/write plumbing for the watch.
///
/// Authorization is requested once for the union of every type any practice
/// might use, so the user only sees a single system prompt.
final class HealthKitManager {
    static let shared = HealthKitManager()

    let store = HKHealthStore()
    private var didRequest = false

    // MARK: Types

    private var hrvType: HKQuantityType? { HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) }
    private var spo2Type: HKQuantityType? { HKObjectType.quantityType(forIdentifier: .oxygenSaturation) }
    private var respRateType: HKQuantityType? { HKObjectType.quantityType(forIdentifier: .respiratoryRate) }
    private var energyType: HKQuantityType? { HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) }
    private var heartType: HKQuantityType? { HKObjectType.quantityType(forIdentifier: .heartRate) }
    private var mindfulType: HKCategoryType? { HKObjectType.categoryType(forIdentifier: .mindfulSession) }

    func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }

        var typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let mindfulType { typesToShare.insert(mindfulType) }

        var typesToRead: Set<HKObjectType> = []
        [heartType, hrvType, spo2Type, respRateType, energyType].forEach { type in
            if let type { typesToRead.insert(type) }
        }

        store.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, _ in
            if success { self.didRequest = true }
            completion(success)
        }
    }

    // MARK: Mindful session

    func saveMindfulSession(start: Date, end: Date, completion: ((Bool) -> Void)? = nil) {
        guard let mindfulType else {
            completion?(false)
            return
        }
        let sample = HKCategorySample(type: mindfulType, value: HKCategoryValue.notApplicable.rawValue, start: start, end: end)
        store.save(sample) { success, _ in
            completion?(success)
        }
    }

    // MARK: Pre/post-session reads

    /// Latest sample of `type` strictly before `referenceDate` and no older than `maxAge`.
    private func latestSample(_ type: HKQuantityType, unit: HKUnit, before referenceDate: Date, maxAge: TimeInterval, completion: @escaping (Double?) -> Void) {
        let start = referenceDate.addingTimeInterval(-maxAge)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: referenceDate, options: .strictEndDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            guard let q = (samples?.first as? HKQuantitySample) else { completion(nil); return }
            completion(q.quantity.doubleValue(for: unit))
        }
        store.execute(query)
    }

    /// Average sample of `type` between two dates (HRV/SpO2/RR/HR).
    private func averageQuantity(_ type: HKQuantityType, unit: HKUnit, start: Date, end: Date, completion: @escaping (Double?) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let stats = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
            guard let result, let q = result.averageQuantity() else { completion(nil); return }
            completion(q.doubleValue(for: unit))
        }
        store.execute(stats)
    }

    // Latest HRV reading within last 2 hours.
    func latestHRV(before date: Date = Date(), completion: @escaping (Double?) -> Void) {
        guard let hrvType else { completion(nil); return }
        latestSample(hrvType, unit: .secondUnit(with: .milli), before: date, maxAge: 2 * 3600, completion: completion)
    }

    // Latest SpO2 reading within last 1 hour.
    func latestSpO2(before date: Date = Date(), completion: @escaping (Double?) -> Void) {
        guard let spo2Type else { completion(nil); return }
        latestSample(spo2Type, unit: .percent(), before: date, maxAge: 3600, completion: completion)
    }

    // Average HRV (SDNN ms) within a window — call shortly after session end to
    // capture the sample HealthKit auto-records around a mindful session.
    func averageHRV(start: Date, end: Date, completion: @escaping (Double?) -> Void) {
        guard let hrvType else { completion(nil); return }
        averageQuantity(hrvType, unit: .secondUnit(with: .milli), start: start, end: end, completion: completion)
    }

    func averageSpO2(start: Date, end: Date, completion: @escaping (Double?) -> Void) {
        guard let spo2Type else { completion(nil); return }
        averageQuantity(spo2Type, unit: .percent(), start: start, end: end, completion: completion)
    }
}
