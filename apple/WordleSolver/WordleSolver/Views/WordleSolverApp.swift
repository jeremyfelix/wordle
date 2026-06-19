//
//  WordleSolverApp.swift
//  WordleSolver
//
//  App entry point. The `@main` attribute marks this as where the app
//  starts. This single file/struct targets BOTH macOS and iOS once it's
//  part of an Xcode "Multiplatform App" target — SwiftUI's `App` protocol
//  and `WindowGroup` scene both work the same way on each platform; Xcode
//  picks the right underlying app lifecycle (AppKit on macOS, UIKit on iOS)
//  automatically.
//

import SwiftUI

@main
struct WordleSolverApp: App {
    // `@StateObject` (rather than plain `let`/`@ObservedObject`) ensures the
    // GameStore is created exactly once for the lifetime of the app, even
    // though SwiftUI may recreate this `App` struct's body multiple times.
    @StateObject private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
