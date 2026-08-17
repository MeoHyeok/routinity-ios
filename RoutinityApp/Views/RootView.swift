//
//  RootView.swift
//  RoutinityApp
//

import Supabase
import SwiftUI

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()

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
