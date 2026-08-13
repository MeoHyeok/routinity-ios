//
//  ReportViewModel.swift
//  RoutinityApp
//

import Combine
import Foundation
import Supabase

@MainActor
final class ReportViewModel: ObservableObject {
    @Published private(set) var report: WeeklyReport?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseManager.client

    func loadWeeklyReport() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let report: WeeklyReport = try await client.functions.invoke("reports-weekly", options: .init(method: .get))
            self.report = report
        } catch {
            errorMessage = friendlyErrorMessage(error)
        }
    }
}
