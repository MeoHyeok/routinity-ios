//
//  GoalSuggestionTests.swift
//  RoutinityAppTests
//

import Foundation
import Testing
@testable import RoutinityApp

struct GoalSuggestionTests {
    private func point(daysAgo: Int, wake: (target: String, actual: String, achieved: Bool)? = nil, study: (target: String, actual: String, achieved: Bool)? = nil) -> DailyTrendPoint {
        var scores: [ScoreEntry] = []
        if let wake {
            scores.append(ScoreEntry(
                targetType: GoalTargetType.wakeTime, targetValue: wake.target, actualValue: wake.actual,
                status: wake.achieved ? .achieved : .notAchieved
            ))
        }
        if let study {
            scores.append(ScoreEntry(
                targetType: GoalTargetType.studyDuration, targetValue: study.target, actualValue: study.actual,
                status: study.achieved ? .achieved : .notAchieved
            ))
        }
        return DailyTrendPoint(
            date: Date(timeIntervalSince1970: Double(-daysAgo) * 86400),
            dailyScore: 80,
            scores: scores,
            hadMeal: true
        )
    }

    @Test func returnsNilWhenMostlyAchieved() {
        let points = (0..<5).map { point(daysAgo: $0, wake: ("07:00", "06:55", true)) }
        #expect(computeGoalSuggestion(from: points) == nil)
    }

    @Test func returnsNilBelowSampleThresholdEvenWithHighMissRate() {
        // Only 2 actual wake times recorded — below the 3-sample minimum, even though both missed.
        let points = [
            point(daysAgo: 0, wake: ("07:00", "08:10", false)),
            point(daysAgo: 1, wake: ("07:00", "08:20", false)),
        ]
        #expect(computeGoalSuggestion(from: points) == nil)
    }

    @Test func suggestsWakeTimeGroundedInRecentActualAverage() {
        let points = (0..<4).map { point(daysAgo: $0, wake: ("07:00", "08:10", false)) }
        let suggestion = computeGoalSuggestion(from: points)
        #expect(suggestion?.lossTitle == "기상 지연")
        #expect(suggestion?.suggestedWakeTime == "08:10")
        #expect(suggestion?.suggestedStudyMinutes == nil)
        #expect(suggestion?.missRate == 1.0)
    }

    @Test func suggestsStudyDurationWhenItsTheWorseMetric() {
        let points = (0..<4).map {
            point(daysAgo: $0, wake: ("07:00", "07:00", true), study: ("60", "20", false))
        }
        let suggestion = computeGoalSuggestion(from: points)
        #expect(suggestion?.lossTitle == "공부 시간 부족")
        #expect(suggestion?.suggestedStudyMinutes == "20")
        #expect(suggestion?.suggestedWakeTime == nil)
    }

    @Test func picksWorseMetricWhenBothAreMissed() {
        // Wake missed every day (100%), study missed only some days (below wake's rate) —
        // suggestion should follow the higher miss rate (wake), not just whichever appears last.
        let points = (0..<4).map {
            point(daysAgo: $0, wake: ("07:00", "09:00", false), study: ("60", "50", $0 < 2))
        }
        let suggestion = computeGoalSuggestion(from: points)
        #expect(suggestion?.lossTitle == "기상 지연")
    }
}
