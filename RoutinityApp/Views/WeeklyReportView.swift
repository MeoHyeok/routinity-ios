//
//  WeeklyReportView.swift
//  RoutinityApp
//

import SwiftUI

struct WeeklyReportView: View {
    @StateObject private var viewModel = ReportViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if let report = viewModel.report {
                    Text(report.content)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)

                    if let generatedVia = report.generatedVia {
                        Text(generatedVia == "claude" ? "AI가 생성한 리포트입니다." : "기본 템플릿으로 생성된 리포트입니다.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if report.cached {
                        Text("오늘 이미 생성된 리포트를 보여주고 있어요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("주간 리포트")
        .task {
            await viewModel.loadWeeklyReport()
        }
    }
}

#Preview {
    NavigationStack {
        WeeklyReportView()
    }
}
