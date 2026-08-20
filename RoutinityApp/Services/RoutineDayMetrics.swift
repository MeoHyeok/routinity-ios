//
//  RoutineDayMetrics.swift
//  RoutinityApp
//

import Foundation

/// Pure computation over a day's raw logs, extracted out of TodayView so the actual logic — not
/// just the SwiftUI plumbing around it — is unit-testable. `now` is injectable so tests don't
/// depend on the real wall clock; call sites default to `Date()`.
struct RoutineDayMetrics {
    let wakeOpenSince: Date?
    let mealOpenSince: Date?
    let studyOpenSince: Date?
    let hasLoggedWake: Bool
    let hasLoggedSleep: Bool
    let actualWakeTime: Date?
    let mealCount: Int
    let totalMealMinutes: Int
    let totalStudyMinutes: Int
    let hasClosedMealSession: Bool
    let hasClosedStudySession: Bool
    /// Elapsed time since 기상 minus 식사/공부 totals so far — not the backend's post-hoc "휴식
    /// 시간" (which needs 취침 to define the 기상~취침 window), just today's rest time so far. Nil
    /// before 기상 is logged, since there's no window to measure from yet.
    let restMinutesSoFar: Int?

    /// 취침 locks while 식사 or 공부 is still in progress — closing the day without ending them
    /// would strand those sessions permanently open with no way to close them (their own lock
    /// conditions only allow *starting* a new session between 기상 and 취침, so once 취침 closes
    /// that window, an already-open 식사/공부 could never be reached again). 기상 itself must stay
    /// unlockable always, so this only ever affects the 취침 (closing) direction.
    var isSleepButtonLocked: Bool {
        wakeOpenSince != nil && (mealOpenSince != nil || studyOpenSince != nil)
    }

    /// Starting 식사 locks outside 기상~취침 or while 공부 is running. Closing an already-open 식사
    /// is never locked — safe regardless of wake state, since `isSleepButtonLocked` above prevents
    /// 취침 from ever being logged while 식사 is open in the first place.
    var isMealButtonLocked: Bool {
        mealOpenSince == nil && (wakeOpenSince == nil || studyOpenSince != nil)
    }

    /// Same rule as `isMealButtonLocked`, mirrored for 공부.
    var isStudyButtonLocked: Bool {
        studyOpenSince == nil && (wakeOpenSince == nil || mealOpenSince != nil)
    }
}

func computeRoutineDayMetrics(from logs: [LogEntry], now: Date = Date()) -> RoutineDayMetrics {
    let sorted = logs.sorted { $0.timestamp < $1.timestamp }

    // The timestamp of a start-type log that hasn't been closed by its matching end-type log yet
    // — walks logs in order rather than just comparing counts, so a resumed session always counts
    // from the real open start, not "now". Shared shape for all three start/end pairs (기상~취침,
    // 식사 시작~종료, 공부 시작~종료).
    func openStart(_ startType: LogEntry.LogType, _ endType: LogEntry.LogType) -> Date? {
        var open: Date?
        for log in sorted {
            if log.type == startType { open = log.timestamp }
            else if log.type == endType { open = nil }
        }
        return open
    }

    func totalMinutes(_ startType: LogEntry.LogType, _ endType: LogEntry.LogType) -> Int {
        var total = 0
        var openStart: Date?
        for log in sorted {
            if log.type == startType {
                openStart = log.timestamp
            } else if log.type == endType, let start = openStart {
                total += max(0, Int(log.timestamp.timeIntervalSince(start) / 60))
                openStart = nil
            }
        }
        return total
    }

    // Whether at least one pair closed today, regardless of duration — lets a metric card tell
    // "did this for under a minute" apart from "never did this at all," since totalMinutes
    // truncates to whole minutes and a sub-minute session would otherwise round down to 0 and
    // look identical to no record existing.
    func hasClosedSession(_ startType: LogEntry.LogType, _ endType: LogEntry.LogType) -> Bool {
        var openStart: Date?
        for log in sorted {
            if log.type == startType {
                openStart = log.timestamp
            } else if log.type == endType, openStart != nil {
                return true
            }
        }
        return false
    }

    let totalMealMinutes = totalMinutes(.mealStart, .mealEnd)
    let totalStudyMinutes = totalMinutes(.studyStart, .studyEnd)
    let actualWakeTime = sorted.first { $0.type == .wake }?.timestamp
    let wakeOpenSince = openStart(.wake, .sleep)

    // Once 취침 closes the session, "so far" should stop at that moment — otherwise reopening the
    // app later the same KST day (before a new 기상) keeps counting 휴식 upward past the point the
    // user told the app they'd gone to bed. Only applies while the session is actually closed
    // (wakeOpenSince == nil); if a later 기상 reopened it, count through to `now` as usual.
    let restMinutesSoFar: Int? = actualWakeTime.map { firstWake in
        let end = wakeOpenSince == nil ? (sorted.last { $0.type == .sleep }?.timestamp ?? now) : now
        let elapsed = max(0, Int(end.timeIntervalSince(firstWake) / 60))
        return max(0, elapsed - totalMealMinutes - totalStudyMinutes)
    }

    return RoutineDayMetrics(
        wakeOpenSince: wakeOpenSince,
        mealOpenSince: openStart(.mealStart, .mealEnd),
        studyOpenSince: openStart(.studyStart, .studyEnd),
        hasLoggedWake: logs.contains { $0.type == .wake },
        hasLoggedSleep: logs.contains { $0.type == .sleep },
        actualWakeTime: actualWakeTime,
        mealCount: logs.filter { $0.type == .mealEnd }.count,
        totalMealMinutes: totalMealMinutes,
        totalStudyMinutes: totalStudyMinutes,
        hasClosedMealSession: hasClosedSession(.mealStart, .mealEnd),
        hasClosedStudySession: hasClosedSession(.studyStart, .studyEnd),
        restMinutesSoFar: restMinutesSoFar
    )
}

/// Shared duration display: shows "1분 미만" for a genuinely-closed session that rounded down to
/// 0 whole minutes, so it reads apart from "never happened" rather than looking identical to it.
func durationLabel(minutes: Int, hasClosedSession: Bool) -> String {
    if minutes > 0 { return "\(minutes)분" }
    if hasClosedSession { return "1분 미만" }
    return "-"
}

/// Consecutive days (ending with the most recent point) with daily_score ≥ 80 — matches the
/// "green" threshold used elsewhere in the app as the bar for "achieved". `points` must be sorted
/// ascending by date (oldest first), so the most recent day is last.
func computeStreakDays(from points: [DailyTrendPoint]) -> Int {
    var count = 0
    for point in points.reversed() {
        guard let score = point.dailyScore, score >= 80 else { break }
        count += 1
    }
    return count
}

/// Average daily_score over the window excluding the most recent point (assumed to be "today") —
/// a personal baseline to compare today's score against, Apple Watch sleep-score style, rather
/// than only judging against the fixed goal-based score. `points` must be sorted ascending.
func computePersonalAverageScore(from points: [DailyTrendPoint]) -> Int? {
    let priorScores = points.dropLast().compactMap { $0.dailyScore }
    guard !priorScores.isEmpty else { return nil }
    return Int((Double(priorScores.reduce(0, +)) / Double(priorScores.count)).rounded())
}
