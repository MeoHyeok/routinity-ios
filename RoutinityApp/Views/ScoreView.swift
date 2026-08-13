//
//  ScoreView.swift
//  RoutinityApp
//

import SwiftUI

struct ScoreView: View {
    @StateObject private var viewModel = ScoreViewModel()

    var body: some View {
        VStack(spacing: 24) {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.scores.isEmpty {
                Text("목표를 설정하면 오늘의 달성 현황이 표시됩니다.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.scores) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(Self.displayName(for: entry.targetType))
                                    .font(.headline)
                                Spacer()
                                Text(Self.statusText(entry.status))
                                    .font(.subheadline)
                                    .foregroundStyle(Self.statusColor(entry.status))
                            }
                            Text("목표 \(entry.targetValue) · 실제 \(entry.actualValue ?? "-")")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button("새로고침") {
                Task { await viewModel.refreshTodayScore() }
            }
            .disabled(viewModel.isLoading)
        }
        .padding()
        .navigationTitle("오늘 점수")
        .task {
            await viewModel.refreshTodayScore()
        }
    }

    private static func displayName(for targetType: String) -> String {
        switch targetType {
        case GoalTargetType.wakeTime: return "기상"
        case GoalTargetType.studyDuration: return "공부 시간"
        default: return targetType
        }
    }

    private static func statusText(_ status: ScoreEntry.Status) -> String {
        switch status {
        case .achieved: return "달성"
        case .notAchieved: return "미달성"
        case .missing: return "기록 없음"
        }
    }

    private static func statusColor(_ status: ScoreEntry.Status) -> Color {
        switch status {
        case .achieved: return .green
        case .notAchieved: return .red
        case .missing: return .secondary
        }
    }
}

#Preview {
    NavigationStack {
        ScoreView()
    }
}
