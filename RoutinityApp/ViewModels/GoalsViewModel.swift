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
    @Published private(set) var isDeleting = false
    @Published var errorMessage: String?
    @Published var savedMessage: String?

    /// The routine a genuinely new account gets set up with automatically, so a fresh signup
    /// isn't scored against nothing until they find the goals screen themselves. Kept alongside
    /// GoalsView's own suggestion-pill copy so the two stay in sync.
    static let defaultWakeTime = "08:00"
    static let defaultStudyMinutes = "300"

    private let client = SupabaseManager.client

    /// Silently backfills the default routine for a brand-new account — called once from the
    /// onboarding tour's first appearance. Only applies when *both* goals are still unset, so it
    /// never clobbers something the user already configured (e.g. re-running onboarding after
    /// deleting just one of the two).
    func applyDefaultGoalsIfMissing() async {
        guard !hasWakeGoal, !hasStudyGoal else { return }
        wakeTime = Self.defaultWakeTime
        studyMinutes = Self.defaultStudyMinutes
        await save()
    }

    func loadGoals() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let goals: [Goal] = try await loggedInvoke("GET /goals") {
                try await client.functions.invoke("goals", options: .init(method: .get))
            }
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
        // doesn't stop the other field's edit from ever being sent. Tracked as two separate slots
        // (not one shared `saveError`, `??`-defaulted) so a network failure on one field can never
        // silently swallow a validation failure on the other — both need to reach the user.
        var savedAnything = false
        var upsertError: Error?
        do {
            savedAnything = try await upsert(type: GoalTargetType.wakeTime, value: wakeTime)
        } catch {
            upsertError = error
        }
        // .numberPad only changes the on-screen keyboard — paste and hardware keyboards still let
        // non-numeric text through, and the server's own validation error is raw/ungrammatical
        // Korean if left to surface on its own, so catch it here instead of round-tripping.
        var validationError: GoalsValidationError?
        if !studyMinutes.isEmpty, !isValidStudyMinutesString(studyMinutes) {
            validationError = .invalidStudyMinutes
        } else {
            do {
                savedAnything = try await upsert(type: GoalTargetType.studyDuration, value: studyMinutes) || savedAnything
            } catch {
                upsertError = upsertError ?? error
            }
        }

        // Re-sync from the server regardless of success/failure so the UI never drifts from
        // what's actually saved, even if one of the two upserts above failed partway through.
        // This also resets errorMessage, so re-apply below whatever actually went wrong.
        await loadGoals()

        let errorTexts = [upsertError.map(friendlyErrorMessage), validationError?.errorDescription].compactMap { $0 }
        if !errorTexts.isEmpty {
            // The two upserts are independent (see comment above), so one can fail while the
            // other genuinely saved — showing only the error here would otherwise make a real,
            // successful save look like it never happened.
            let combined = errorTexts.joined(separator: " ")
            errorMessage = savedAnything ? "\(combined) (다른 목표는 저장됐어요.)" : combined
        } else if savedAnything {
            savedMessage = "저장되었습니다."
        }
    }

    func deleteGoal(type: String) async {
        // A rapid double-tap on "목표 삭제" before the first request's `hasGoal` update lands
        // would otherwise fire two DELETEs — the second always 404s ("goal not found") since the
        // first already removed the row.
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }
        errorMessage = nil
        savedMessage = nil

        do {
            try await loggedInvoke("DELETE /goals?target_type=\(type)") {
                try await client.functions.invoke(
                    "goals",
                    options: .init(method: .delete, query: [URLQueryItem(name: "target_type", value: type)])
                )
            }
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
        let _: Goal = try await loggedInvoke("POST /goals (\(type))") {
            try await client.functions.invoke("goals", options: .init(body: request))
        }
        return true
    }
}

/// Mirrors the server's own `study_duration` validation (see docs/api-contract.md) — a positive
/// integer, and no more than 1440 (there are only that many minutes in a day) — checked
/// client-side first so the round trip to the server's own English validation error is avoidable.
private func isValidStudyMinutesString(_ value: String) -> Bool {
    guard let number = Int(value.trimmingCharacters(in: .whitespaces)) else { return false }
    return (1...1440).contains(number)
}

private enum GoalsValidationError: LocalizedError {
    case invalidStudyMinutes

    var errorDescription: String? {
        switch self {
        case .invalidStudyMinutes:
            return "공부 시간 목표는 1~1440 사이의 숫자(분)로 입력해주세요."
        }
    }
}
