//
//  AICoachView.swift
//  RoutinityApp
//

import SwiftUI

struct AICoachView: View {
    @StateObject private var viewModel = ReportViewModel()
    @StateObject private var trendViewModel = TrendViewModel()
    @State private var period: ReportPeriod = .daily

    private var goalSuggestion: GoalSuggestion? {
        computeGoalSuggestion(from: trendViewModel.points)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    Picker("기간", selection: $period) {
                        Text("오늘").tag(ReportPeriod.daily)
                        Text("주간").tag(ReportPeriod.weekly)
                        Text("월간").tag(ReportPeriod.monthly)
                    }
                    .pickerStyle(.segmented)

                    if viewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else if let report = viewModel.report {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(LinearGradient.routinityAccent)
                                Text(report.generatedVia == "claude" ? "AI 생성 리포트" : "기본 템플릿 리포트")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if report.cached {
                                    Text("캐시됨")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(Color.white.opacity(0.08), in: Capsule())
                                }
                            }

                            if let dateRange = report.dateRange {
                                Text("\(dateRange.from) ~ \(dateRange.to)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }

                            Text(report.content)
                                .font(.body)
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .routinityCard(glow: true)

                        if let suggestedAction = report.suggestedAction {
                            SuggestedActionCard(action: suggestedAction)
                        }

                        goalSuggestionCard

                        if let breakdown = report.timeBreakdown {
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
            .toolbar(.hidden, for: .navigationBar)
            .task(id: period) {
                await viewModel.loadReport(period: period)
            }
            .task {
                // Loaded once (not tied to `period`) purely to ground goalSuggestionCard in real
                // recent data — same 14-day window TodayView's streak calc already uses safely.
                await trendViewModel.loadTrend(days: 14)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AI 코치")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient.routinityHeadline)
            Text("루틴을 바탕으로 한 코멘트를 받아보세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var goalSuggestionCard: some View {
        if let suggestion = goalSuggestion {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(Color.routinityOrange)
                    Text("목표 제안")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                Text("\(suggestion.lossTitle)이 최근 \(Int((suggestion.missRate * 100).rounded()))%로 잦아요. 최근 실제 평균에 맞춰 목표를 \(suggestion.suggestedLabel)로 조정해보는 건 어떨까요?")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                NavigationLink {
                    GoalsView(suggestedWakeTime: suggestion.suggestedWakeTime, suggestedStudyMinutes: suggestion.suggestedStudyMinutes)
                } label: {
                    Text("목표 조정하러 가기")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.routinityViolet)
                }
            }
            .routinityCard(glow: true)
        }
    }
}

#Preview {
    AICoachView()
}
