//
//  InsightsViewModel.swift
//  RoutinityApp
//

import Combine
import Foundation
import Supabase

@MainActor
final class InsightsViewModel: ObservableObject {
    @Published private(set) var insights: Insights?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseManager.client

    func loadInsights() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let insights: Insights = try await client.functions.invoke("insights", options: .init(method: .get))
            self.insights = insights
        } catch {
            errorMessage = friendlyErrorMessage(error)
        }
    }
}
