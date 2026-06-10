//
//  FocusCycleApp.swift
//  FocusCycle Watch App
//
//  Created by Abhijeet Shelke on 20/06/25.
//

import SwiftUI

@main
struct FocusCycle_Watch_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    WatchConnectivityManager.shared.activate()
                    WatchConnectivityManager.shared.pushLatestSnapshot()
                }
                .onChange(of: scenePhase) { _, phase in
                    handleScenePhaseChange(phase)
                }
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            // App is going to background - ensure extended runtime is active if timer is running
            NotificationCenter.default.post(name: .appDidEnterBackground, object: nil)
            // Catch-all sync: deliver any setting changes made this session to iOS.
            WatchConnectivityManager.shared.pushLatestSnapshot()
        case .active:
            // App is becoming active - resume normal operation
            NotificationCenter.default.post(name: .appDidBecomeActive, object: nil)
            WatchConnectivityManager.shared.pushLatestSnapshot()
        case .inactive:
            // App is becoming inactive - prepare for background
            NotificationCenter.default.post(name: .appWillResignActive, object: nil)
        @unknown default:
            break
        }
    }
}

extension Notification.Name {
    static let appDidEnterBackground = Notification.Name("appDidEnterBackground")
    static let appDidBecomeActive = Notification.Name("appDidBecomeActive")
    static let appWillResignActive = Notification.Name("appWillResignActive")
}
