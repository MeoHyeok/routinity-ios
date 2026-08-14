//
//  ReportViewModel.swift
//  RoutinityApp
//

import Combine
import Foundation
import Supabase

@MainActor
final class ReportViewModel: ObservableObject {
    @Published private(set) var report: Report?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseManager.client

    func loadReport(period: ReportPeriod) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let report: Report = try await client.functions.invoke(period.functionName, options: .init(method: .get))
            self.report = report
        } catch {
            errorMessage = friendlyErrorMessage(error)
        }
    }
}
