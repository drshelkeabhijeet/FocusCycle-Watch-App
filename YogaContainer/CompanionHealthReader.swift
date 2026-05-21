import Foundation
import HealthKit

/// Reads baseline wellness signals from the iPhone's HealthKit store so the
/// companion app can surface them on the Insights tab independent of WCSession
/// snapshots. All reads are best-effort; missing values map to `nil`.
@MainActor
final class CompanionHealthReader: ObservableObject {
    static let shared = CompanionHealthReader()

    @Published private(set) var restingHeartRate: Double?       // bpm
    @Published private(set) var vo2Max: Double?                 // mL/(kg·min)
    @Published private(set) var latestSpO2: Double?             // 0...1
    @Published private(set) var latestRespiratoryRate: Double?  // breaths/min
    @Published private(set) var lastNightSleepHours: Double?    // hours asleep
    @Published private(set) var lastNightDate: Date?
    @Published private(set) var isAuthorized: Bool = false

    private let store = HKHealthStore()

    private var typesToRead: Set<HKObjectType> {
        var s = Set<HKObjectType>()
        [
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .vo2Max),
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation),
            HKObjectType.quantityType(forIdentifier: .respiratoryRate),
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKObjectType.quantityType(forIdentifier: .heartRate),
        ].forEach { if let t = $0 { s.insert(t) } }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { s.insert(sleep) }
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) { s.insert(mindful) }
        return s
    }

    private init() {}

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: typesToRead)
            self.isAuthorized = true
        } catch {
            self.isAuthorized = false
        }
    }

    /// Refresh every published value. Call from `.refreshable` and `onAppear`.
    func refresh() async {
        async let rhr = readLatest(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        async let vo2 = readLatest(.vo2Max, unit: HKUnit(from: "ml/(kg*min)"))
        async let spo2 = readLatest(.oxygenSaturation, unit: .percent())
        async let rr = readLatest(.respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()))
        async let sleep = readLastNightSleep()

        let (rhrV, vo2V, spo2V, rrV, sleepV) = await (rhr, vo2, spo2, rr, sleep)
        self.restingHeartRate = rhrV
        self.vo2Max = vo2V
        self.latestSpO2 = spo2V
        self.latestRespiratoryRate = rrV
        if let sleepV {
            self.lastNightSleepHours = sleepV.0
            self.lastNightDate = sleepV.1
        }
    }

    // MARK: - Private

    private nonisolated func readLatest(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return nil }
        return await withCheckedContinuation { (cont: CheckedContinuation<Double?, Never>) in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let s = (samples?.first as? HKQuantitySample) else { cont.resume(returning: nil); return }
                cont.resume(returning: s.quantity.doubleValue(for: unit))
            }
            store.execute(q)
        }
    }

    /// Sums all "asleep" sleep-analysis intervals over the last 36 hours — a
    /// reasonable approximation of "last night's sleep" without modelling
    /// Apple's full sleep schedule.
    private nonisolated func readLastNightSleep() async -> (Double, Date)? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let cal = Calendar.current
        let now = Date()
        guard let start = cal.date(byAdding: .hour, value: -36, to: now) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)

        return await withCheckedContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    cont.resume(returning: nil); return
                }
                let asleep = samples.filter {
                    let v = $0.value
                    return v == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                        || v == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                        || v == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                        || v == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                }
                let total = asleep.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                let lastEnd = asleep.last?.endDate ?? samples.last?.endDate ?? Date()
                cont.resume(returning: (total / 3600.0, lastEnd))
            }
            store.execute(q)
        }
    }
}
