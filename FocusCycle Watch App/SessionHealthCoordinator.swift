import Foundation
import HealthKit

/// Captures pre- and post-session HealthKit readings around a practice and
/// merges them with the live workout aggregate into a `SessionHealthMetrics`.
///
/// Usage:
///   1. On session start, call `captureBaseline()`.
///   2. When the session ends, call `finalize(aggregate:)` with the workout
///      builder's aggregate. The completion gives you metrics ready to pass
///      into `StreakManager.recordSession(metrics:)`.
final class SessionHealthCoordinator {
    private var startDate: Date?
    private var preHRV: Double?
    private var preSpO2: Double?

    func captureBaseline(start: Date = Date()) {
        startDate = start
        let now = start
        HealthKitManager.shared.latestHRV(before: now) { [weak self] value in
            self?.preHRV = value
        }
        HealthKitManager.shared.latestSpO2(before: now) { [weak self] value in
            self?.preSpO2 = value
        }
    }

    func finalize(aggregate: HeartRateManager.Aggregate,
                  completion: @escaping (SessionHealthMetrics) -> Void) {
        let end = Date()
        let start = startDate ?? end

        // HealthKit auto-records an HRV reading after a mindful session save;
        // sample the window from session start to end+5min to catch it.
        let postEnd = end.addingTimeInterval(5 * 60)

        var metrics = SessionHealthMetrics(
            avgHeartRate: aggregate.avgHeartRate,
            avgRespiratoryRate: aggregate.avgRespiratoryRate,
            activeEnergyKcal: aggregate.activeEnergyKcal,
            hrvPreSdnnMs: preHRV,
            hrvPostSdnnMs: nil,
            spo2PrePercent: preSpO2,
            spo2PostPercent: nil,
            hrSamples: aggregate.hrSamples.isEmpty ? nil : aggregate.hrSamples
        )

        let group = DispatchGroup()

        group.enter()
        HealthKitManager.shared.averageHRV(start: start, end: postEnd) { value in
            metrics.hrvPostSdnnMs = value
            group.leave()
        }

        group.enter()
        HealthKitManager.shared.averageSpO2(start: start, end: postEnd) { value in
            metrics.spo2PostPercent = value
            group.leave()
        }

        group.notify(queue: .main) {
            completion(metrics)
        }
    }
}
