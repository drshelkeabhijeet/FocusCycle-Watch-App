import Foundation
import SwiftUI
import HealthKit

final class HeartRateManager: NSObject, ObservableObject {
    struct Sample: Identifiable { let id = UUID(); let date: Date; let bpm: Int }
    @Published var bpm: Int?
    @Published var samples: [Sample] = []

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private var authorized = false

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else { completion(false); return }
        let heart = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let toShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        let toRead: Set<HKObjectType> = [heart]
        healthStore.requestAuthorization(toShare: toShare, read: toRead) { success, _ in
            DispatchQueue.main.async { self.authorized = success; completion(success) }
        }
    }

    func start() {
        requestAuthorization { [weak self] ok in
            guard ok, let self else { return }
            self.beginWorkoutStreaming()
        }
    }

    func stop() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { _, _ in }
        builder?.finishWorkout(completion: { _, _ in })
        session = nil
        builder = nil
        bpm = nil
        // keep samples for graph until next start
    }

    private func beginWorkoutStreaming() {
        let config = HKWorkoutConfiguration()
        config.activityType = .yoga
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
        samples.removeAll()
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
            // append sample; cap to last 120 points (~2 min at 1s resolution)
            self.samples.append(Sample(date: Date(), bpm: val))
            if self.samples.count > 240 { self.samples.removeFirst(self.samples.count - 240) }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}
}
