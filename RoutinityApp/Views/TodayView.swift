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
    @State private var showSettings = false
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

    private var achievedCount: Int {
        scoreViewModel.scores.filter { $0.status == .achieved }.count
    }

    private var mealCount: Int {
        logsViewModel.logs.filter { $0.type == .meal }.count
    }

    /// Wake is a once-a-day event — nothing stopped repeated taps from piling up duplicate
    /// "기상" logs, each counted separately in "오늘 기록".
    private var hasLoggedWakeToday: Bool {
        logsViewModel.logs.contains { $0.type == .wake }
    }

    /// An open study session (a study_start with no matching study_end yet today). Used to
    /// stop "공부 시작" from being tapped again mid-session, and "공부 종료" from being tapped
    /// with nothing to end.
    private var isStudyInProgress: Bool {
        let starts = logsViewModel.logs.filter { $0.type == .studyStart }.count
        let ends = logsViewModel.logs.filter { $0.type == .studyEnd }.count
        return starts > ends
    }

    private func isQuickLogDisabled(_ type: LogEntry.LogType) -> Bool {
        switch type {
        case .wake: return hasLoggedWakeToday
        case .studyStart: return isStudyInProgress
        case .studyEnd: return !isStudyInProgress
        case .meal: return false
        }
    }

    /// Only wake/studyStart being disabled means "already done today" (checkmark reads
    /// correctly there). studyEnd is disabled for the opposite reason — nothing open to end —
    /// so it keeps its normal icon, just dimmed.
    private func isQuickLogCompleted(_ type: LogEntry.LogType) -> Bool {
        switch type {
        case .wake: return hasLoggedWakeToday
        case .studyStart: return isStudyInProgress
        case .studyEnd, .meal: return false
        }
    }

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
                _ = await (scoreTask, logsTask)
                hasLoadedOnce = true
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(authViewModel: authViewModel)
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

                HStack(spacing: 8) {
                    statPill(value: "\(logsViewModel.logs.count)", label: "오늘 기록")
                    statPill(value: "\(achievedCount)", label: "목표 달성")
                }
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

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(LogEntry.LogType.allCases, id: \.self) { type in
                    quickLogButton(for: type)
                }
            }
        }
    }

    private func quickLogButton(for type: LogEntry.LogType) -> some View {
        let disabledByState = isQuickLogDisabled(type)
        let isCompleted = isQuickLogCompleted(type)
        return Button {
            Task {
                await logsViewModel.recordLog(type: type)
                await scoreViewModel.refreshTodayScore()
                if logsViewModel.errorMessage == nil {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.routinityViolet.opacity(disabledByState ? 0.12 : 0.3))
                        .frame(width: 34, height: 34)
                    if logsViewModel.isRecording == type {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: isCompleted ? "checkmark" : type.symbolName)
                            .font(.footnote)
                            .foregroundStyle(disabledByState ? Color.secondary : Color.white)
                    }
                }
                Text(type.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(disabledByState ? Color.secondary : Color.white)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .routinityCard(padding: 12)
        .disabled(logsViewModel.isRecording != nil || disabledByState)
    }
}

private extension ScoreViewModel {
    func entry(for targetType: String) -> ScoreEntry? {
        scores.first { $0.targetType == targetType }
    }
}

#Preview {
    TodayView(authViewModel: AuthViewModel())
}
