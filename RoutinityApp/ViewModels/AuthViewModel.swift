//
//  AuthViewModel.swift
//  RoutinityApp
//

import Combine
import Foundation
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    enum Mode {
        case signIn
        case signUp
    }

    @Published var email = ""
    @Published var password = ""
    @Published var mode: Mode = .signIn
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published private(set) var session: Session?
    @Published private(set) var hasLoadedInitialSession = false

    var isAuthenticated: Bool { session != nil }

    private let auth = SupabaseManager.client.auth
    private var authStateTask: Task<Void, Never>?

    init() {
        authStateTask = Task { [weak self] in
            guard let self else { return }
            for await (event, session) in auth.authStateChanges {
                self.session = session
                if event == .initialSession {
                    self.hasLoadedInitialSession = true
                }
            }
        }

        #if DEBUG && targetEnvironment(simulator)
        autoLoginIfRequested()
        #endif
    }

    #if DEBUG && targetEnvironment(simulator)
    /// Lets `xcrun simctl launch` drive a real sign-in for manual/scripted verification,
    /// e.g. `SIMCTL_CHILD_AUTO_LOGIN_EMAIL=... SIMCTL_CHILD_AUTO_LOGIN_PASSWORD=...`.
    /// Compiled out of release builds and physical-device builds entirely.
    private func autoLoginIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard let email = env["AUTO_LOGIN_EMAIL"], let password = env["AUTO_LOGIN_PASSWORD"] else { return }
        self.email = email
        self.password = password
        self.mode = .signIn
        Task { await submit() }
    }
    #endif

    deinit {
        authStateTask?.cancel()
    }

    func submit() async {
        errorMessage = nil
        infoMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            switch mode {
            case .signIn:
                try await auth.signIn(email: email, password: password)
            case .signUp:
                let response = try await auth.signUp(email: email, password: password)
                if response.session == nil {
                    infoMessage = "가입 확인 이메일을 보냈습니다. 메일함을 확인한 뒤 로그인해주세요."
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        try? await auth.signOut()
    }
}
