//
//  ScoreView.swift
//  RoutinityApp
//

import SwiftUI

struct ScoreView: View {
    let userId: UUID

    @StateObject private var viewModel = ScoreViewModel()

    var body: some View {
        VStack(spacing: 24) {
            if viewModel.isLoading {
                ProgressView()
            } else if let score = viewModel.score {
                VStack(spacing: 8) {
                    Text("\(score.score)")
                        .font(.system(size: 64, weight: .bold))
                    Text("오늘의 점수")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    if let wakeScore = score.wakeScore {
                        HStack {
                            Text("기상")
                            Spacer()
                            Text("\(wakeScore)점")
                        }
                    }
                    if let studyScore = score.studyScore {
                        HStack {
                            Text("공부 시간")
                            Spacer()
                            Text("\(studyScore)점")
                        }
                    }
                }
                .padding(.horizontal, 40)
            } else {
                Text("목표를 설정하고 오늘 기록을 남기면\n점수가 표시됩니다.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button("새로고침") {
                Task { await viewModel.refreshTodayScore(userId: userId) }
            }
            .disabled(viewModel.isLoading)
        }
        .padding()
        .navigationTitle("오늘 점수")
        .task {
            await viewModel.refreshTodayScore(userId: userId)
        }
    }
}

#Preview {
    NavigationStack {
        ScoreView(userId: UUID())
    }
}
