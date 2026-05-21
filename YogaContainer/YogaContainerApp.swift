//
//  YogaContainerApp.swift
//  YogaContainer
//
//  Created by Abhijeet Shelke on 26/08/25.
//

import SwiftUI

@main
struct YogaContainerApp: App {
    @StateObject private var store = CompanionStore.shared
    @StateObject private var wc = WatchConnectivityManager.shared
    @StateObject private var health = CompanionHealthReader.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(wc)
                .environmentObject(health)
                .task {
                    wc.activate()
                    await health.requestAuthorization()
                    await health.refresh()
                }
        }
    }
}
