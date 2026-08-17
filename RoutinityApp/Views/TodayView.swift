//
//  TodayView.swift
//  RoutinityApp
//

import SwiftUI
import UIKit

struct TodayView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var logsViewModel = LogsViewModel()
    @StateObject private var scoreViewModel = ScoreViewModel()
    @StateObject private var sleepReportViewModel = ReportViewModel()
    @StateObject private var streakViewModel = TrendViewModel()
    @State private var showSettings = false
    @State private var showSleepReport = false
    /// Distinguishes "still loading" from "genuinely empty" for the very first load — after
    /// that, quick-log refreshes flip isLoading again but shouldn't blank the whole screen.
    @State private var hasLoadedOnce = false

    private static let dateHeadingFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy. MM. dd"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()

    /// Consecutive days (ending today) with daily_score ≥ 80 — matches the "green" threshold
    /// already used everywhere else in the app as the bar for "achieved". A single "N개 목표
    /// 달성" count for today was ambiguous about what it meant or over what period; a streak
    /// is a clearer, more motivating framing for the same underlying data.
    private var streakDays: Int {
        var count = 0
        for point in streakViewModel.points.reversed() {
            guard let score = point.dailyScore, score >= 80 else { break }
            count += 1
        }
        return count
    }

    private var mealCount: Int {
        logsViewModel.logs.filter { $0.type == .mealEnd }.count
    }

    /// Average daily_score over the streak window excluding today (streakViewModel.points is
    /// sorted ascending, so today is always the last point) — gives a personal baseline to
    /// compare today's score against, Apple Watch sleep-score style, rather than only judging
    /// against the fixed goal-based score.
    private var personalAverageScore: Int? {
        let priorScores = streakViewModel.points.dropLast().compactMap { $0.dailyScore }
        guard !priorScores.isEmpty else { return nil }
        return Int((Double(priorScores.reduce(0, +)) / Double(priorScores.count)).rounded())
    }

    private var personalScoreDelta: Int? {
        guard let today = scoreViewModel.dailyScore, let baseline = personalAverageScore else { return nil }
        return today - baseline
    }

    /// The timestamp of a start-type log that hasn't been closed by its matching end-type log
    /// yet today — walks logs in order rather than just comparing counts, so a resumed session
    /// always counts from the real open start, not "now". Used for all three start/end pairs
    /// (기상~취침, 식사 시작~종료, 공부 시작~종료), which all follow the same shape.
    private func openStart(_ startType: LogEntry.LogType, _ endType: LogEntry.LogType) -> Date? {
        var open: Date?
        for log in logsViewModel.logs.sorted(by: { $0.timestamp < $1.timestamp }) {
            if log.type == startType { open = log.timestamp }
            else if log.type == endType { open = nil }
        }
        return open
    }

    private var wakeOpenSince: Date? { openStart(.wake, .sleep) }
    private var mealOpenSince: Date? { openStart(.mealStart, .mealEnd) }
    private var studyOpenSince: Date? { openStart(.studyStart, .studyEnd) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header

                    if hasLoadedOnce {
                        scoreRingCard
                        metricCardsRow
                    } else {
                        loadingPlaceholder
                    }

                    quickLogSection

                    if let errorMessage = logsViewModel.errorMessage ?? scoreViewModel.errorMessage {
                        VStack(spacing: 8) {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                            Button("다시 시도") {
                                Task {
                                    await scoreViewModel.refreshTodayScore()
                                    await logsViewModel.loadLogs(on: Date())
                                }
                            }
                            .font(.footnote.weight(.semibold))
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.routinityBackground)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                async let scoreTask: Void = scoreViewModel.refreshTodayScore()
                async let logsTask: Void = logsViewModel.loadLogs(on: Date())
                // 14 days, not more — TrendViewModel fires one /scores + one /logs call per day
                // concurrently, and piling on top of the score/logs calls already in flight here
                // risks tripping the 60-per-minute rate limit on a single screen load.
                async let streakTask: Void = streakViewModel.loadTrend(days: 14)
                _ = await (scoreTask, logsTask, streakTask)
                hasLoadedOnce = true
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(authViewModel: authViewModel)
            }
            .sheet(isPresented: $showSleepReport) {
                SleepReportSheet(viewModel: sleepReportViewModel)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("루티니티")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient.routinityHeadline)
                Text("오늘 루틴을 기록해보세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.routinityCard, in: Circle())
            }
        }
    }

    /// Shown only until the first load resolves — without this, the ring/cards briefly rendered
    /// their empty state ("-", "목표 없음") indistinguishably from actually having no goals,
    /// which reads as data having vanished rather than still loading.
    private var loadingPlaceholder: some View {
        VStack {
            ProgressView()
                .tint(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .routinityCard(glow: true)
    }

    private var scoreRingCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 12)
                if let score = scoreViewModel.dailyScore {
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100)
                        .stroke(
                            AngularGradient(colors: [.routinityOrange, .routinityPink], center: .center),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
                VStack(spacing: 0) {
                    Text(scoreViewModel.dailyScore.map { "\($0)" } ?? "-")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("TODAY")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let delta = personalScoreDelta {
                        Text(delta == 0 ? "평소와 비슷" : "평소보다 \(delta > 0 ? "+" : "")\(delta)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(delta > 0 ? Color.routinityGreen : (delta < 0 ? Color.routinityPink : Color.secondary))
                    }
                }
            }
            .frame(width: 132, height: 132)

            VStack(alignment: .leading, spacing: 10) {
                Text(Self.dateHeadingFormatter.string(from: Date()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Self.weekdayFormatter.string(from: Date()))
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                statPill(value: "\(streakDays)일", label: "연속 달성")
            }
            Spacer()
        }
        .routinityCard(glow: true)
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 56)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var metricCardsRow: some View {
        HStack(spacing: 12) {
            metricCard(
                icon: "sun.max.fill",
                tint: .routinityOrange,
                title: "기상",
                value: scoreViewModel.entry(for: GoalTargetType.wakeTime)?.actualValue ?? "-",
                subtitle: scoreViewModel.entry(for: GoalTargetType.wakeTime).map { "목표 \($0.targetValue)" } ?? "목표 없음"
            )
            metricCard(
                icon: "book.fill",
                tint: .routinityCyan,
                title: "공부",
                value: (scoreViewModel.entry(for: GoalTargetType.studyDuration)?.actualValue).map { "\($0)분" } ?? "-",
                subtitle: scoreViewModel.entry(for: GoalTargetType.studyDuration).map { "목표 \($0.targetValue)분" } ?? "목표 없음"
            )
            metricCard(
                icon: "fork.knife",
                tint: .routinityPink,
                title: "식사",
                value: "\(mealCount)회",
                subtitle: "오늘 기록"
            )
        }
    }

    private func metricCard(icon: String, tint: Color, title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.35), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinityCard(padding: 12)
    }

    private var quickLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("간편 기록")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            // 기상↔취침: 취침을 기록하면 그 즉시 오늘 리포트를 생성해서 보여준다. 하루의 시작이라
            // 다른 버튼들과 달리 절대 잠기지 않는다.
            toggleLogButton(startType: .wake, endType: .sleep, openSince: wakeOpenSince, showsStopwatch: false, isLocked: false)

            // 식사 시작↔종료: 지금 깨어있는 상태(기상~취침 사이)가 아니거나 공부가 진행 중이면 잠금 —
            // 취침을 기록한 뒤에는 그날의 활동이 끝난 것이므로 다시 기상하기 전까진 잠긴 채로 둔다.
            toggleLogButton(
                startType: .mealStart, endType: .mealEnd, openSince: mealOpenSince, showsStopwatch: false,
                isLocked: wakeOpenSince == nil || studyOpenSince != nil
            )

            // 공부 시작↔종료: 지금 깨어있는 상태가 아니거나 식사가 진행 중이면 잠금. 진행 중일 때 실시간 스톱워치 표시.
            toggleLogButton(
                startType: .studyStart, endType: .studyEnd, openSince: studyOpenSince, showsStopwatch: true,
                isLocked: wakeOpenSince == nil || mealOpenSince != nil
            )
        }
    }

    private func toggleLogButton(
        startType: LogEntry.LogType,
        endType: LogEntry.LogType,
        openSince: Date?,
        showsStopwatch: Bool,
        isLocked: Bool
    ) -> some View {
        let inProgress = openSince != nil
        let type = inProgress ? endType : startType
        let isRecordingThisPair = logsViewModel.isRecording == startType || logsViewModel.isRecording == endType
        return Button {
            recordAndRefresh(type)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.routinityViolet.opacity(isLocked ? 0.12 : 0.3))
                        .frame(width: 40, height: 40)
                    if isRecordingThisPair {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: isLocked ? "lock.fill" : type.symbolName)
                            .font(.subheadline)
                            .foregroundStyle(isLocked ? Color.secondary : Color.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isLocked ? Color.secondary : Color.white)
                    if inProgress, showsStopwatch, let start = openSince {
                        Text(start, style: .timer)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.routinityCyan)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 6)
        }
        .routinityCard(padding: 12)
        .disabled(logsViewModel.isRecording != nil || isLocked)
    }

    private func recordAndRefresh(_ type: LogEntry.LogType) {
        Task {
            await logsViewModel.recordLog(type: type)
            await scoreViewModel.refreshTodayScore()
            guard logsViewModel.errorMessage == nil else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // 취침을 기록하면 그 시점 데이터로 오늘 리포트를 생성해서 바로 보여준다.
            if type == .sleep {
                await sleepReportViewModel.loadReport(period: .daily)
                showSleepReport = true
            }
        }
    }
}

private extension ScoreViewModel {
    func entry(for targetType: String) -> ScoreEntry? {
        scores.first { $0.targetType == targetType }
    }
}

/// Shown right after 취침 is logged — the report generated from that moment's data.
private struct SleepReportSheet: View {
    @ObservedObject var viewModel: ReportViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if let report = viewModel.report {
                        Text(report.content)
                            .font(.body)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .routinityCard()

                        if let suggestedAction = viewModel.report?.suggestedAction {
                            SuggestedActionCard(action: suggestedAction)
                        }

                        if let breakdown = viewModel.report?.timeBreakdown {
                            TimeBreakdownChart(breakdown: breakdown)
                        }
                    } else if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .background(Color.routinityBackground)
            .navigationTitle("오늘 리포트")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    TodayView(authViewModel: AuthViewModel())
}
