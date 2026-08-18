//
//  RoutineDayMetricsTests.swift
//  RoutinityAppTests
//

import Foundation
import Testing
@testable import RoutinityApp

struct RoutineDayMetricsTests {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func log(_ type: LogEntry.LogType, _ minutesFromBase: Int) -> LogEntry {
        LogEntry(
            id: UUID(), type: type,
            timestamp: base.addingTimeInterval(Double(minutesFromBase) * 60),
            createdAt: base
        )
    }

    @Test func emptyLogsProduceNoOpenSessionsAndNilRest() {
        let metrics = computeRoutineDayMetrics(from: [])
        #expect(metrics.wakeOpenSince == nil)
        #expect(metrics.hasLoggedWake == false)
        #expect(metrics.restMinutesSoFar == nil)
        #expect(metrics.totalMealMinutes == 0)
        #expect(metrics.hasClosedMealSession == false)
    }

    @Test func wakeWithoutSleepIsOpen() {
        let metrics = computeRoutineDayMetrics(from: [log(.wake, 0)])
        #expect(metrics.wakeOpenSince == base)
        #expect(metrics.hasLoggedWake == true)
        #expect(metrics.hasLoggedSleep == false)
    }

    @Test func wakeThenSleepClosesTheSession() {
        let metrics = computeRoutineDayMetrics(from: [log(.wake, 0), log(.sleep, 30)])
        #expect(metrics.wakeOpenSince == nil)
        #expect(metrics.hasLoggedWake == true)
        #expect(metrics.hasLoggedSleep == true)
    }

    @Test func closedStudyPairSumsMinutesAcrossMultipleSessions() {
        let logs = [
            log(.studyStart, 0), log(.studyEnd, 25),
            log(.studyStart, 40), log(.studyEnd, 55),
        ]
        let metrics = computeRoutineDayMetrics(from: logs)
        #expect(metrics.totalStudyMinutes == 40)
        #expect(metrics.hasClosedStudySession == true)
        #expect(metrics.studyOpenSince == nil)
    }

    @Test func openStudySessionDoesNotCountTowardTotalYet() {
        let metrics = computeRoutineDayMetrics(from: [log(.studyStart, 0)])
        #expect(metrics.totalStudyMinutes == 0)
        #expect(metrics.studyOpenSince == base)
        // Not "closed" yet even though it's in progress — hasClosedSession is specifically about
        // completed pairs, matching the "1분 미만" vs "-" distinction it's used for.
        #expect(metrics.hasClosedStudySession == false)
    }

    @Test func restIsElapsedTimeMinusMealAndStudy() {
        // 기상 at t=0, 취침-independent "now" at t=60, 10 minutes of meal, 15 of study in between.
        let logs = [
            log(.wake, 0),
            log(.mealStart, 5), log(.mealEnd, 15),
            log(.studyStart, 20), log(.studyEnd, 35),
        ]
        let now = base.addingTimeInterval(60 * 60)
        let metrics = computeRoutineDayMetrics(from: logs, now: now)
        #expect(metrics.totalMealMinutes == 10)
        #expect(metrics.totalStudyMinutes == 15)
        #expect(metrics.restMinutesSoFar == 35) // 60 elapsed - 10 meal - 15 study
    }

    @Test func restNeverGoesNegativeEvenIfAccountedTimeExceedsElapsed() {
        // Pathological/clock-skew case: a closed session claims more minutes than have actually
        // elapsed since 기상. Should clamp to 0, not go negative.
        let logs = [log(.wake, 0), log(.studyStart, 0), log(.studyEnd, 120)]
        let now = base.addingTimeInterval(60 * 60) // only 60 minutes have "really" passed
        let metrics = computeRoutineDayMetrics(from: logs, now: now)
        #expect(metrics.restMinutesSoFar == 0)
    }

    @Test func durationLabelPrefersMinutesThenSubMinuteThenDash() {
        #expect(durationLabel(minutes: 5, hasClosedSession: true) == "5분")
        #expect(durationLabel(minutes: 0, hasClosedSession: true) == "1분 미만")
        #expect(durationLabel(minutes: 0, hasClosedSession: false) == "-")
    }

    @Test func streakCountsConsecutiveHighScoresFromTheEnd() {
        let points = [80, 90, 40, 100, 85].enumerated().map {
            DailyTrendPoint(date: base.addingTimeInterval(Double($0.offset) * 86400), dailyScore: $0.element, scores: [], hadMeal: true)
        }
        // Trailing run of ≥80 is [100, 85] — the earlier 40 breaks the streak before it.
        #expect(computeStreakDays(from: points) == 2)
    }

    @Test func streakStopsAtFirstMissingScore() {
        let points = [90, nil, 90].enumerated().map {
            DailyTrendPoint(date: base.addingTimeInterval(Double($0.offset) * 86400), dailyScore: $0.element, scores: [], hadMeal: true)
        }
        #expect(computeStreakDays(from: points) == 1)
    }
}
