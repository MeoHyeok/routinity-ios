# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

Xcode/SwiftUI iOS project (`RoutinityApp`). Day 1 of the roadmap is done: `supabase-swift` SPM package is wired up and the source tree is split into `Views/`, `ViewModels/`, `Services/`, `Resources/`. Screens themselves are not built yet — `frontend_roadmap.md` (Korean) describes the 10-day plan for what's about to be built, summarized below since it defines the intended architecture.

`RoutinityApp/` is an Xcode `PBXFileSystemSynchronizedRootGroup` (Xcode 16+ synced folder): any file or folder created under it is automatically picked up by the build — no project.pbxproj edits needed for new source/resource files. pbxproj edits are only needed for things like adding SPM package dependencies.

## Intended architecture (per frontend_roadmap.md)

The app is a SwiftUI + MVVM client for a Supabase backend that is already built and deployed:

```
SwiftUI View  →  ViewModel  →  API Client  →  Supabase backend (already deployed)
 (UI only)      (@Published    (network calls)
                 state, logic)
```

- **View**: UI rendering only, no logic.
- **ViewModel**: holds `@Published` state, handles button actions/logic.
- **API Client**: calls backend endpoints — `/logs`, `/goals`, `/scores`, `/reports/weekly`.
- **Auth**: Supabase Auth via the `supabase-swift` SPM package (added; see `RoutinityApp/Services/SupabaseManager.swift`, which exposes a shared `SupabaseClient`).
- A backend API contract doc is expected at `docs/api-contract.md` (not present yet — check for it before assuming endpoint shapes).

Planned screens and their endpoints:

| Screen | Purpose | API |
|---|---|---|
| Login/Signup | Supabase Auth | Auth SDK |
| Home | One-tap logging (wake/meal/study start-end) | `POST /logs` |
| Today timeline | List of today's logs | `GET /logs?date=` |
| Goal setting | Input/view target values | `POST/GET /goals` |
| Review/score | Today's score vs. goals | `GET /scores` |
| Weekly report | AI-generated report text | `GET /reports/weekly` |

When implementing a new screen, follow the View/ViewModel/Service split above rather than putting networking or state logic directly in views.

## Build & run

Standard Xcode project. Dependencies are Xcode-managed SPM packages declared directly in `project.pbxproj` (no root `Package.swift`).

```bash
# Resolve SPM package dependencies (needed after pbxproj changes / first checkout)
xcodebuild -resolvePackageDependencies -project RoutinityApp.xcodeproj -scheme RoutinityApp

# Build for the simulator
xcodebuild -project RoutinityApp.xcodeproj -scheme RoutinityApp -sdk iphonesimulator build

# Open in Xcode
open RoutinityApp.xcodeproj
```

### Supabase credentials

`SupabaseManager` (in `RoutinityApp/Services/`) reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from `RoutinityApp/Resources/Secrets.plist`, which is gitignored. Copy the repo-root `Secrets.example.plist` template to `RoutinityApp/Resources/Secrets.plist` and fill in real values from the Supabase dashboard before hitting any Supabase call — without it (or if the placeholder values are left as-is), `SupabaseManager` prints a warning and falls back to a placeholder client so the app still builds and launches. The example file lives at the repo root, not under `RoutinityApp/`, specifically so it isn't picked up by the synchronized group and bundled into the shipped app.

### Adding another SPM package

There's no `Package.swift` to edit — add packages the same way `supabase-swift` was added: through Xcode's *File > Add Package Dependencies*, or by hand-editing `project.pbxproj` (add an `XCRemoteSwiftPackageReference`, an `XCSwiftPackageProductDependency`, wire the product into the target's `packageProductDependencies` and the Frameworks build phase, then run `-resolvePackageDependencies`).

- Deployment target: iOS 26.5
- Swift version: 5.0
- Bundle ID: `com.meohyeok.RoutinityApp`

### Tests

`RoutinityAppTests` (Swift Testing, not XCTest) covers pure logic extracted into `RoutinityApp/Services/` — e.g. `GoalSuggestion.swift`. It is a plain `PBXGroup`, not a synchronized folder like the main app target, so a new test file needs to be added to the target in Xcode (or via the `xcodeproj` Ruby gem) rather than just dropping it in the directory.

`-sdk iphonesimulator` alone leaves `xcodebuild` to guess a destination, which resolves to the generic "Any iOS Simulator Device" placeholder and fails outright for `test` (only `build` tolerates it) — an explicit simulator destination is required:

```bash
xcodebuild -project RoutinityApp.xcodeproj -scheme RoutinityApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```
