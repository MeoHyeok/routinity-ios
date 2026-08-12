//
//  GoalsViewModel.swift
//  RoutinityApp
//

import Combine
import Foundation
import Supabase

@MainActor
final class GoalsViewModel: ObservableObject {
    @Published var wakeTime = ""
    @Published var studyMinutes = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published var savedMessage: String?

    private let client = SupabaseManager.client
    private var goalsByType: [Goal.TargetType: Goal] = [:]

    func loadGoals(userId: UUID) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let goals: [Goal] = try await client
                .from("goals")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            goalsByType = Dictionary(uniqueKeysWithValues: goals.map { ($0.targetType, $0) })
            wakeTime = goalsByType[.wake]?.targetValue ?? ""
            studyMinutes = goalsByType[.studyMinutes]?.targetValue ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(userId: UUID) async {
        errorMessage = nil
        savedMessage = nil
        isSaving = true
        defer { isSaving = false }

        var saveError: Error?
        do {
            try await upsert(type: .wake, value: wakeTime, userId: userId)
            try await upsert(type: .studyMinutes, value: studyMinutes, userId: userId)
        } catch {
            saveError = error
        }

        // Re-sync from the DB regardless of success/failure so the UI (and the
        // insert-vs-update cache below) never drifts from what's actually saved,
        // even if one of the two upserts above failed partway through. This also
        // resets errorMessage, so re-apply the save error (if any) after it runs.
        await loadGoals(userId: userId)

        if let saveError {
            errorMessage = saveError.localizedDescription
        } else {
            savedMessage = "저장되었습니다."
        }
    }

    private func upsert(type: Goal.TargetType, value: String, userId: UUID) async throws {
        guard !value.isEmpty else { return }

        if let existing = goalsByType[type] {
            try await client
                .from("goals")
                .update(GoalUpdate(targetValue: value, updatedAt: Date()))
                .eq("id", value: existing.id)
                .execute()
        } else {
            try await client
                .from("goals")
                .insert(NewGoal(userId: userId, targetType: type.rawValue, targetValue: value))
                .execute()
        }
    }
}
