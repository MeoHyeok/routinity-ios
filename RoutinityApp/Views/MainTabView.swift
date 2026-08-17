//
//  MainTabView.swift
//  RoutinityApp
//

import SwiftUI

struct MainTabView: View {
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
        TabView {
            TodayView(authViewModel: authViewModel)
                .tabItem { Label("오늘", systemImage: "circle.dotted") }

            AnalysisView()
                .tabItem { Label("분석", systemImage: "chart.bar.fill") }

            AICoachView()
                .tabItem { Label("AI 코치", systemImage: "sparkles") }
        }
        .tint(.routinityViolet)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MainTabView(authViewModel: AuthViewModel())
}
