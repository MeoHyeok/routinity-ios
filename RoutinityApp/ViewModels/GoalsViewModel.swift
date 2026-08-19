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
    /// Whether each field currently reflects a goal that's actually persisted on the server,
    /// as opposed to text the user is mid-typing. Drives whether "delete" is offered — deleting
    /// unsaved text would just 404 ("goal not found") since there's nothing to delete yet.
    @Published private(set) var hasWakeGoal = false
    @Published private(set) var hasStudyGoal = false
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published var savedMessage: String?

    private let client = SupabaseManager.client

    func loadGoals() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let goals: [Goal] = try await client.functions.invoke("goals", options: .init(method: .get))
            let goalsByType = Dictionary(uniqueKeysWithValues: goals.map { ($0.targetType, $0) })
            wakeTime = goalsByType[GoalTargetType.wakeTime]?.targetValue ?? ""
            studyMinutes = goalsByType[GoalTargetType.studyDuration]?.targetValue ?? ""
            hasWakeGoal = goalsByType[GoalTargetType.wakeTime] != nil
            hasStudyGoal = goalsByType[GoalTargetType.studyDuration] != nil
        } catch {
            errorMessage = friendlyErrorMessage(error)
        }
    }

    func save() async {
        errorMessage = nil
        savedMessage = nil
        isSaving = true
        defer { isSaving = false }

        // Attempted independently so one field failing to save (e.g. a transient network error)
        // doesn't stop the other field's edit from ever being sent.
        var savedAnything = false
        var saveError: Error?
        do {
            savedAnything = try await upsert(type: GoalTargetType.wakeTime, value: wakeTime)
        } catch {
            saveError = error
        }
        do {
            savedAnything = try await upsert(type: GoalTargetType.studyDuration, value: studyMinutes) || savedAnything
        } catch {
            saveError = error
        }

        // Re-sync from the server regardless of success/failure so the UI never drifts from
        // what's actually saved, even if one of the two upserts above failed partway through.
        // This also resets errorMessage, so re-apply the save error (if any) after it runs.
        await loadGoals()

        if let saveError {
            errorMessage = friendlyErrorMessage(saveError)
        } else if savedAnything {
            savedMessage = "저장되었습니다."
        }
    }

    func deleteGoal(type: String) async {
        errorMessage = nil
        savedMessage = nil

        do {
            try await client.functions.invoke(
                "goals",
                options: .init(method: .delete, query: [URLQueryItem(name: "target_type", value: type)])
            )
            switch type {
            case GoalTargetType.wakeTime:
                wakeTime = ""
                hasWakeGoal = false
            case GoalTargetType.studyDuration:
                studyMinutes = ""
                hasStudyGoal = false
            default:
                break
            }
        } catch {
            errorMessage = friendlyErrorMessage(error)
        }
    }

    /// Returns whether a request was actually made, so `save()` can tell "nothing to save" (both
    /// fields blank) apart from a real success — otherwise tapping 저장 on an untouched, empty
    /// form claimed "저장되었습니다" without ever calling the API.
    @discardableResult
    private func upsert(type: String, value: String) async throws -> Bool {
        guard !value.isEmpty else { return false }

        let request = GoalUpsertRequest(targetType: type, targetValue: value)
        let _: Goal = try await client.functions.invoke("goals", options: .init(body: request))
        return true
    }
}
