//
//  SettingsView.swift
//  RoutinityApp
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @State private var permissionDeniedMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        GoalsView()
                    } label: {
                        Label("목표 설정", systemImage: "target")
                    }
                }

                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("기록 알림", systemImage: "bell")
                    }
                    .onChange(of: notificationsEnabled) { _, isOn in
                        if isOn {
                            Task { await requestNotificationPermission() }
                        } else {
                            NotificationManager.cancelAll()
                        }
                    }
                    if let permissionDeniedMessage {
                        Text(permissionDeniedMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("기상·취침 기록을 깜빡했을 때 하루 한 번씩 알려드려요.")
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            await authViewModel.signOut()
                            dismiss()
                        }
                    } label: {
                        Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func requestNotificationPermission() async {
        let granted = await NotificationManager.requestAuthorizationIfNeeded()
        if granted {
            permissionDeniedMessage = nil
        } else {
            notificationsEnabled = false
            permissionDeniedMessage = "알림이 거부되어 있어요. 설정 앱에서 루티니티 알림을 허용해주세요."
        }
    }
}

#Preview {
    SettingsView(authViewModel: AuthViewModel())
}
