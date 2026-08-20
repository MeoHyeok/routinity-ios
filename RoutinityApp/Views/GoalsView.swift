//
//  GoalsView.swift
//  RoutinityApp
//

import SwiftUI

struct GoalsView: View {
    @StateObject private var viewModel = GoalsViewModel()
    /// Set when arriving from the 분석 탭's 로스 분석 제안 — a target the recent actual average
    /// suggests, shown as a tappable pill rather than pre-filled directly, so applying it is
    /// still an explicit choice and doesn't silently overwrite an existing goal on screen.
    var suggestedWakeTime: String? = nil
    var suggestedStudyMinutes: String? = nil

    // Mirrors GoalsViewModel's own defaults (the ones auto-applied for a brand-new account) so
    // there's a single "default routine" concept in the app, not two different sets of numbers.
    private static let starterWakeTime = GoalsViewModel.defaultWakeTime
    private static let starterStudyMinutes = GoalsViewModel.defaultStudyMinutes

    private static let wakeTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Presents wakeTime (an "HH:mm" string, the shape /goals actually stores) as a native time
    /// picker instead of free-text typing — a user asked for this after finding typing "07:00"
    /// with the colon fiddly. Only writes back through `set`, which SwiftUI only calls on an
    /// actual user selection, so just displaying a fallback here doesn't silently create a goal.
    private var wakeTimeSelection: Binding<Date> {
        Binding<Date>(
            get: {
                Self.wakeTimeFormatter.date(from: viewModel.wakeTime)
                    ?? Self.wakeTimeFormatter.date(from: Self.starterWakeTime)
                    ?? Date()
            },
            set: { viewModel.wakeTime = Self.wakeTimeFormatter.string(from: $0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                starterRoutineCard

                goalCard(
                    title: "기상 목표",
                    hint: "몇 시에 기상하고 싶으신가요?",
                    hasGoal: viewModel.hasWakeGoal
                ) {
                    DatePicker("기상 시간", selection: wakeTimeSelection, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(.routinityViolet)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    if let suggestedWakeTime {
                        suggestionPill(value: suggestedWakeTime) { viewModel.wakeTime = suggestedWakeTime }
                    }
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
                    if let suggestedStudyMinutes {
                        suggestionPill(value: "\(suggestedStudyMinutes)분") { viewModel.studyMinutes = suggestedStudyMinutes }
                    }
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

    /// Shown only for genuinely new users (no goal of either type ever set) — proposes a
    /// reasonable default rather than leaving them to guess starting numbers on a blank form,
    /// which is the actual gap between "여기서 로스가 나요" analytics and "루틴을 세워주는" onboarding.
    @ViewBuilder
    private var starterRoutineCard: some View {
        if !viewModel.isLoading && !viewModel.hasWakeGoal && !viewModel.hasStudyGoal {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(Color.routinityCyan)
                    Text("아직 설정한 루틴이 없어요")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                Text("기상 \(Self.starterWakeTime) · 공부 \(Self.starterStudyMinutes)분으로 가볍게 시작해보세요. 나중에 언제든 조정할 수 있어요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    viewModel.wakeTime = Self.starterWakeTime
                    viewModel.studyMinutes = Self.starterStudyMinutes
                } label: {
                    Text("이 루틴으로 시작하기")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.routinityViolet)
                }
            }
            .routinityCard(glow: true)
        }
    }

    private func suggestionPill(value: String, apply: @escaping () -> Void) -> some View {
        Button(action: apply) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("제안: \(value)")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.routinityViolet)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.routinityViolet.opacity(0.12), in: Capsule())
        }
    }
}

#Preview {
    NavigationStack {
        GoalsView()
    }
}
