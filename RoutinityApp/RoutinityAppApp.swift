//
//  RoutinityAppApp.swift
//  RoutinityApp
//
//  Created by 머혁 on 8/12/26.
//

import SwiftUI

@main
struct RoutinityAppApp: App {
    init() {
        _ = SupabaseManager.client
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
