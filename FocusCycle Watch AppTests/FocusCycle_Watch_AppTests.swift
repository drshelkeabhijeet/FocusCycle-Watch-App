//
//  FocusCycle_Watch_AppTests.swift
//  FocusCycle Watch AppTests
//
//  Created by Abhijeet Shelke on 20/06/25.
//

import Foundation
import Testing
@testable import FocusCycle_Watch_App

struct FocusCycle_Watch_AppTests {

    @Test func pranayamaPatternTotalDurationIsComputedCorrectly() {
        let pattern = PranayamaPattern(
            type: .anulom,
            inhaleDuration: 4,
            hold1Duration: 4,
            exhaleDuration: 6,
            hold2Duration: 2,
            cycles: 5
        )

        #expect(pattern.totalDuration == 80)
        #expect(pattern.phases.count == 4)
    }

    @Test func streakDataHasSessionTodayReflectsLastSessionDate() {
        var data = StreakData()
        #expect(data.hasSessionToday == false)

        data.lastSessionDate = Date()
        #expect(data.hasSessionToday == true)
    }

    @Test func appHapticDefaultIsAvailableInAllList() {
        #expect(AppHaptic.all.contains(AppHaptic.default))
        #expect(AppHaptic.all.count > 0)
    }

    @Test func launchStateStoreRoundTripWorks() {
        LaunchStateStore.remember(.meditation)
        #expect(LaunchStateStore.lastPractice() == .meditation)
    }

    @Test func companionSnapshotEnvelopeEncodesAndDecodes() throws {
        let snapshot = CompanionStateSnapshot(
            generatedAt: Date(),
            sequence: 1,
            streaksByActivity: [
                "yoga": CompanionStreakSummary(currentStreak: 2, longestStreak: 5, totalSessions: 12, totalMinutes: 180)
            ],
            presets: CompanionPresetsSnapshot(
                yoga: CompanionYogaPreset(holdSeconds: 30, restSeconds: 20, asanaCount: 10),
                pranayama: [
                    CompanionPranayamaPreset(typeRawValue: "Anulom", inhaleDuration: 4, hold1Duration: 4, exhaleDuration: 4, hold2Duration: 4, cycles: 10)
                ],
                meditation: CompanionMeditationPreset(durationMinutes: 12)
            )
        )

        let envelope = CompanionEnvelope.snapshot(snapshot)
        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(CompanionEnvelope.self, from: data)

        #expect(decoded.schemaVersion == CompanionSchema.version)
        #expect(decoded.kind == "stateSnapshot")
        #expect(decoded.stateSnapshot?.streaksByActivity["yoga"]?.currentStreak == 2)
    }

    @Test func companionSessionEventCarriesStableId() {
        let event = CompanionSessionEvent(
            id: UUID().uuidString,
            activityTypeRawValue: "meditation",
            durationSeconds: 600,
            date: Date(),
            pattern: nil
        )
        #expect(!event.id.isEmpty)
        #expect(event.activityTypeRawValue == "meditation")
    }

}
