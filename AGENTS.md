# Repository Guidelines

## Project Structure & Module Organization
- Source: `FocusCycle Watch App/` (SwiftUI views and app entry), shared models in `FocusCycle Watch App/Shared/`.
- Tests: `FocusCycle Watch AppTests/` for unit tests; `FocusCycle Watch AppUITests/` for UI and launch tests.
- Config: `FocusCycle.xcodeproj/` (schemes/build settings), `FocusCycle-Watch-App-Info.plist` (metadata), assets in `FocusCycle Watch App/Assets.xcassets`.

## Build, Test, and Development Commands
- Use stable Xcode (App Store), not beta, for archiving/upload.
- Build (watchOS Debug): `xcodebuild -project FocusCycle.xcodeproj -scheme "FocusCycle Watch App" -configuration Debug build`
- Test (watchOS Sim): `xcodebuild -project FocusCycle.xcodeproj -scheme "FocusCycle Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (41mm)' test`
- Archive (container): select scheme `FocusCycle` → destination `Any iOS Device (arm64)` → Product → Archive (upload via Organizer).
- List schemes: `xcodebuild -list -project FocusCycle.xcodeproj`

## Coding Style & Naming Conventions
- Language: Swift (SwiftUI). Use Xcode default formatting; 4-space indentation; trim trailing whitespace.
- Names: Types PascalCase; variables/functions camelCase; constants camelCase with `let`; test methods `test...`.
- Files: One primary type per file; co-locate view helpers with their view.
- Imports: Prefer explicit imports; keep `SwiftUI` first in SwiftUI view files.

## Testing Guidelines
- Framework: XCTest for unit and UI tests.
- Naming: Mirror source files (e.g., `ContentViewTests.swift`); methods start with `test` and validate one behavior.
- Running: Use Xcode (Product → Test) or the test command above. Target meaningful coverage for models, view logic, and critical flows.

## HealthKit & Mindfulness
- Capability: Add HealthKit to the watch target.
- Info.plist: set `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` with clear reasons.
- Authorization: `HealthKitManager` requests access before starting an extended session; update requested types if you add new Health data.
- Mindful Minutes: A mindful session is saved when a timer completes/resets.

## Commit & Pull Request Guidelines
- Commits: Use Conventional Commits (e.g., `feat: add haptic presets`, `fix: correct timer rounding`). Imperative, scoped messages.
- Pull Requests: Clear description, linked issues, watch-simulator screenshots/GIFs, and test notes. Ensure `xcodebuild ... test` passes and no new warnings.

## Security & Configuration Tips
- Avoid committing secrets or device-specific data. Guard feature flags in `WatchConnectivityManager.swift`; prefer dependency injection for testability.

## Release Checklist (App Store)
- Stable tools: Build with latest public Xcode and SDKs.
- Scheme: Share `FocusCycle` scheme; archive the container (not the watch target); upload via Organizer.
- Store listing: Apple Watch screenshots, Description/Keywords, Support and Privacy Policy URLs.
- App Privacy: Declare Health data usage (not linked, no tracking) consistent with the app.
