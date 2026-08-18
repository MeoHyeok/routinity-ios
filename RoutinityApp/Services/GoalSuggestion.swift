//
//  GoalSuggestion.swift
//  RoutinityApp
//

import Foundation

/// A concrete next-goal proposal grounded in the recent actual average, not just a stat about
/// what's being missed — shared by 분석 (트렌드 데이터를 직접 봄) and AI 코치 (리포트를 보다가도 같은
/// 제안과 목표 설정 경로로 이어지도록) so a report reader isn't left to hunt down the 분석 탭 to act on it.
struct GoalSuggestion {
    let lossTitle: String
    let missRate: Double
    let suggestedLabel: String
    let suggestedWakeTime: String?
    let suggestedStudyMinutes: String?
}

/// Picks whichever of 기상/공부 is missed most often over the given window, and — only once
/// there's enough real data to ground it — proposes the recent actual average as a more
/// achievable next target. Meal irregularity has no goal type to adjust, so it never produces a
/// suggestion. Returns nil below a 30% miss rate (already doing fine) or without enough samples.
func computeGoalSuggestion(from points: [DailyTrendPoint]) -> GoalSuggestion? {
    let wakeMissRate = missRate(for: GoalTargetType.wakeTime, in: points) ?? 0
    let studyMissRate = missRate(for: GoalTargetType.studyDuration, in: points) ?? 0
    let overallMissRate = max(wakeMissRate, studyMissRate)
    guard overallMissRate >= 0.3 else { return nil }

    if wakeMissRate >= studyMissRate {
        guard let minutes = averageActualWakeMinutes(in: points) else { return nil }
        let label = timeString(fromMinutes: minutes)
        return GoalSuggestion(
            lossTitle: "기상 지연", missRate: wakeMissRate, suggestedLabel: label,
            suggestedWakeTime: label, suggestedStudyMinutes: nil
        )
    } else {
        guard let minutes = averageActualStudyMinutes(in: points), minutes > 0 else { return nil }
        return GoalSuggestion(
            lossTitle: "공부 시간 부족", missRate: studyMissRate, suggestedLabel: "\(minutes)분",
            suggestedWakeTime: nil, suggestedStudyMinutes: "\(minutes)"
        )
    }
}

private func missRate(for targetType: String, in points: [DailyTrendPoint]) -> Double? {
    let entries = points.compactMap { $0.entry(for: targetType) }
    guard !entries.isEmpty else { return nil }
    let missed = entries.filter { $0.status != .achieved }.count
    return Double(missed) / Double(entries.count)
}

private func averageActualWakeMinutes(in points: [DailyTrendPoint]) -> Int? {
    let values = points
        .compactMap { $0.entry(for: GoalTargetType.wakeTime)?.actualValue }
        .compactMap { minutesFromTimeString($0) }
    guard values.count >= 3 else { return nil }
    return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
}

private func averageActualStudyMinutes(in points: [DailyTrendPoint]) -> Int? {
    let values = points
        .compactMap { $0.entry(for: GoalTargetType.studyDuration)?.actualValue }
        .compactMap { Int($0) }
    guard values.count >= 3 else { return nil }
    return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
}

private func minutesFromTimeString(_ value: String) -> Int? {
    let parts = value.split(separator: ":")
    guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
    return hour * 60 + minute
}

private func timeString(fromMinutes minutes: Int) -> String {
    let normalized = ((minutes % 1440) + 1440) % 1440
    return String(format: "%02d:%02d", normalized / 60, normalized % 60)
}
