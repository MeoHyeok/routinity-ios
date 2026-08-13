//
//  GoalsView.swift
//  RoutinityApp
//

import SwiftUI

struct GoalsView: View {
    @StateObject private var viewModel = GoalsViewModel()

    var body: some View {
        Form {
            Section("기상 목표 (예: 07:00)") {
                TextField("HH:mm", text: $viewModel.wakeTime)
                    .keyboardType(.numbersAndPunctuation)
                    .autocapitalization(.none)
            }

            Section("공부 시간 목표 (분)") {
                TextField("예: 120", text: $viewModel.studyMinutes)
                    .keyboardType(.numberPad)
            }

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

            Button {
                Task { await viewModel.save() }
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("저장")
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(viewModel.isSaving)
        }
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
}

#Preview {
    NavigationStack {
        GoalsView()
    }
}
