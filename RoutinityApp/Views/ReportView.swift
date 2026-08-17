//
//  ReportView.swift
//  RoutinityApp
//

import SwiftUI

struct ReportView: View {
    let period: ReportPeriod

    @StateObject private var viewModel = ReportViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if let report = viewModel.report {
                    if let dateRange = report.dateRange {
                        Text("\(dateRange.from) ~ \(dateRange.to)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text(report.content)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .routinityCard()

                    VStack(alignment: .leading, spacing: 2) {
                        if let generatedVia = report.generatedVia {
                            Text(generatedVia == "claude" ? "AI가 생성한 리포트입니다." : "기본 템플릿으로 생성된 리포트입니다.")
                        }

                        if report.cached {
                            Text("오늘 이미 생성된 리포트를 보여주고 있어요.")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.routinityBackground)
        .navigationTitle(period.navigationTitle)
        .task {
            await viewModel.loadReport(period: period)
        }
    }
}

#Preview {
    NavigationStack {
        ReportView(period: .weekly)
    }
}
