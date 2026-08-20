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

    @Test func sleepButtonLocksWhileStudyOrMealIsStillOpen() {
        let openStudy = computeRoutineDayMetrics(from: [log(.wake, 0), log(.studyStart, 10)])
        #expect(openStudy.isSleepButtonLocked == true)

        let openMeal = computeRoutineDayMetrics(from: [log(.wake, 0), log(.mealStart, 10)])
        #expect(openMeal.isSleepButtonLocked == true)

        let bothClosed = computeRoutineDayMetrics(from: [
            log(.wake, 0), log(.studyStart, 10), log(.studyEnd, 20), log(.mealStart, 30), log(.mealEnd, 40),
        ])
        #expect(bothClosed.isSleepButtonLocked == false)
    }

    @Test func sleepButtonNeverLocksBeforeWaking() {
        // 기상 itself must always stay reachable, regardless of stray open study/meal state.
        let metrics = computeRoutineDayMetrics(from: [])
        #expect(metrics.isSleepButtonLocked == false)
    }

    @Test func alreadyOpenStudyOrMealNeverLocksItsOwnCloseButton() {
        // Regression: 공부 시작 → 취침 (without ending 공부) used to leave 공부 stuck locked with no
        // way to ever close it, since its lock condition only checked wake state. It must stay
        // closeable regardless of what else is going on.
        let logs = [log(.wake, 0), log(.studyStart, 10), log(.sleep, 20)]
        let metrics = computeRoutineDayMetrics(from: logs)
        #expect(metrics.studyOpenSince != nil) // still genuinely open
        #expect(metrics.isStudyButtonLocked == false)
    }

    @Test func restStopsAccumulatingOnceTheSessionIsClosedBySleep() {
        // 기상 at t=0, 취침 at t=60. Reopening the app much later the same KST day (no new
        // 기상) shouldn't make 휴식 keep growing past the moment 취침 was logged.
        let logs = [log(.wake, 0), log(.sleep, 60)]
        let now = base.addingTimeInterval(180 * 60) // reopened 2 hours after 취침
        let metrics = computeRoutineDayMetrics(from: logs, now: now)
        #expect(metrics.restMinutesSoFar == 60) // capped at the 취침 timestamp, not `now`
    }

    @Test func restResumesAccumulatingAfterASameDayReopenWake() {
        // 기상 → 취침 → 기상 again (session reopened, still no matching 취침 for the new wake) —
        // rest should count through to `now` again, not stay capped at the earlier 취침.
        let logs = [log(.wake, 0), log(.sleep, 60), log(.wake, 90)]
        let now = base.addingTimeInterval(150 * 60)
        let metrics = computeRoutineDayMetrics(from: logs, now: now)
        #expect(metrics.wakeOpenSince != nil)
        #expect(metrics.restMinutesSoFar == 150) // elapsed since the *first* 기상 (t=0) to `now`
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
