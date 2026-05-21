import Foundation
import SwiftUI
import HealthKit

/// Live workout session that collects heart rate, respiratory rate, and active
/// energy. Used by all three practices; the activity type is supplied by the
/// caller (`.yoga` for yoga, `.mindAndBody` for pranayama and meditation).
final class HeartRateManager: NSObject, ObservableObject {
    struct Sample: Identifiable { let id = UUID(); let date: Date; let bpm: Int }

    @Published var bpm: Int?
    @Published var samples: [Sample] = []
    @Published var statusText: String = ""

    /// Aggregate metrics captured during the latest session. Populated when
    /// `stop()` finishes; cleared on next `start()`.
    struct Aggregate {
        var avgHeartRate: Double?
        var avgRespiratoryRate: Double?
        var activeEnergyKcal: Double?
    }
    @Published private(set) var lastAggregate: Aggregate = Aggregate()

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var activityType: HKWorkoutActivityType = .yoga
    private var sessionStart: Date?

    private var authorized = false

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        // Delegate to the central manager so the user only sees one prompt.
        HealthKitManager.shared.requestAuthorizationIfNeeded { ok in
            DispatchQueue.main.async {
                self.authorized = ok
                self.statusText = ok ? "" : "Heart rate permission unavailable"
                completion(ok)
            }
        }
    }

    func start(activityType: HKWorkoutActivityType = .yoga) {
        self.activityType = activityType
        requestAuthorization { [weak self] ok in
            guard ok, let self else { return }
            self.beginWorkoutStreaming()
            DispatchQueue.main.async {
                self.statusText = ""
            }
        }
    }

    func stop(completion: ((Aggregate) -> Void)? = nil) {
        let endDate = Date()
        guard let session, let builder else {
            completion?(Aggregate())
            return
        }
        session.end()
        builder.endCollection(withEnd: endDate) { [weak self] _, _ in
            guard let self else { completion?(Aggregate()); return }
            let aggregate = self.collectAggregate(from: builder)
            builder.finishWorkout { _, _ in }
            DispatchQueue.main.async {
                self.lastAggregate = aggregate
                self.session = nil
                self.builder = nil
                self.bpm = nil
                self.statusText = ""
                completion?(aggregate)
            }
        }
    }

    private func collectAggregate(from builder: HKLiveWorkoutBuilder) -> Aggregate {
        var agg = Aggregate()
        if let hrType = HKObjectType.quantityType(forIdentifier: .heartRate),
           let stats = builder.statistics(for: hrType),
           let q = stats.averageQuantity() {
            agg.avgHeartRate = q.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        }
        if let rrType = HKObjectType.quantityType(forIdentifier: .respiratoryRate),
           let stats = builder.statistics(for: rrType),
           let q = stats.averageQuantity() {
            agg.avgRespiratoryRate = q.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        }
        if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
           let stats = builder.statistics(for: energyType),
           let q = stats.sumQuantity() {
            agg.activeEnergyKcal = q.doubleValue(for: HKUnit.kilocalorie())
        }
        return agg
    }

    private func beginWorkoutStreaming() {
        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType = .indoor
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            builder = session?.associatedWorkoutBuilder()
        } catch {
            return
        }
        guard let session, let builder else { return }
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
        builder.delegate = self
        session.delegate = self
        let now = Date()
        sessionStart = now
        DispatchQueue.main.async {
            self.samples.removeAll()
            self.lastAggregate = Aggregate()
        }
        session.startActivity(with: now)
        builder.beginCollection(withStart: now) { _, _ in }
    }
}

extension HeartRateManager: HKLiveWorkoutBuilderDelegate, HKWorkoutSessionDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(hrType),
              let stats = workoutBuilder.statistics(for: hrType),
              let quantity = stats.mostRecentQuantity() else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let val = Int(round(quantity.doubleValue(for: unit)))
        DispatchQueue.main.async {
            self.bpm = val
            self.samples.append(Sample(date: Date(), bpm: val))
            if self.samples.count > 240 { self.samples.removeFirst(self.samples.count - 240) }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}
}
