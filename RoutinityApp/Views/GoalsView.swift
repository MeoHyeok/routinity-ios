//
//  GoalsView.swift
//  RoutinityApp
//

import SwiftUI

struct GoalsView: View {
    @StateObject private var viewModel = GoalsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                goalCard(
                    title: "기상 목표",
                    hint: "예: 07:00",
                    hasGoal: viewModel.hasWakeGoal
                ) {
                    TextField("HH:mm", text: $viewModel.wakeTime)
                        .keyboardType(.numbersAndPunctuation)
                        .autocapitalization(.none)
                        .routinityFieldStyle()
                } onDelete: {
                    Task { await viewModel.deleteGoal(type: GoalTargetType.wakeTime) }
                }

                goalCard(
                    title: "공부 시간 목표",
                    hint: "분 단위, 예: 120",
                    hasGoal: viewModel.hasStudyGoal
                ) {
                    TextField("예: 120", text: $viewModel.studyMinutes)
                        .keyboardType(.numberPad)
                        .routinityFieldStyle()
                } onDelete: {
                    Task { await viewModel.deleteGoal(type: GoalTargetType.studyDuration) }
                }

                VStack(spacing: 8) {
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if let savedMessage = viewModel.savedMessage {
                        Text(savedMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Task { await viewModel.save() }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("저장")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isSaving)
            }
            .padding(20)
        }
        .background(Color.routinityBackground)
        .navigationTitle("목표 설정")
        .task {
            await viewModel.loadGoals()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private func goalCard(
        title: String,
        hint: String,
        hasGoal: Bool,
        @ViewBuilder field: () -> some View,
        onDelete: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            field()

            if hasGoal {
                Button("목표 삭제", role: .destructive, action: onDelete)
                    .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinityCard()
    }
}

#Preview {
    NavigationStack {
        GoalsView()
    }
}
