//
//  RootView.swift
//  RoutinityApp
//

import Supabase
import SwiftUI

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()
    /// Shown once — the very first time this device reaches the authenticated app, whether that's
    /// right after signup (email confirmation off) or the first sign-in after confirming an email
    /// (confirmation on). Deliberately device-local rather than per-account: a fresh install
    /// re-showing it for an existing account is a reasonable tradeoff for not needing a server
    /// round trip just to gate a one-time tutorial.
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            if !authViewModel.hasLoadedInitialSession {
                ProgressView()
            } else if authViewModel.isAuthenticated {
                // Keyed on the signed-in user so a session swap between two non-nil sessions
                // (e.g. a Keychain-restored session getting replaced by a fresh sign-in) forces
                // SwiftUI to recreate MainTabView instead of leaving the previous user's
                // already-loaded logs/scores/goals on screen under the new account.
                MainTabView(authViewModel: authViewModel)
                    .id(authViewModel.session?.user.id)
                    .fullScreenCover(isPresented: .init(get: { !hasSeenOnboarding }, set: { hasSeenOnboarding = !$0 })) {
                        OnboardingView(onFinish: { hasSeenOnboarding = true })
                    }
            } else {
                AuthView(viewModel: authViewModel)
            }
        }
        // AuthView and the initial-session ProgressView otherwise follow the system appearance —
        // on a light-mode device that meant white-on-white text (routinityFieldStyle hardcodes
        // white foreground) over the explicit near-black routinityBackground. Every screen past
        // login already forces dark individually; this covers the two that were missed.
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootView()
}
