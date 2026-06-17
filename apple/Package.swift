// swift-tools-version:5.9
//
//  Package.swift — Swift Package Manager manifest for the WordleSolver LOGIC CORE.
//
//  Purpose: this lets the pure-Foundation solver logic (Sources/Model) and its
//  unit tests (Tests) be built and run with `swift test` on any platform with a
//  Swift toolchain — Linux, CI, or macOS — WITHOUT Xcode. This is how the logic
//  is verified outside a Mac (e.g. `swift test` on Linux).
//
//  Scope: ONLY the SwiftUI-free core is part of this package. The app's UI
//  (Sources/Views) and state container (Sources/Store) import SwiftUI/Combine
//  and are built by the Xcode app project instead (see README.md) — they are
//  intentionally NOT listed as target sources here, so this package compiles on
//  platforms that have no SwiftUI.
//
//  Note: the module is named `WordleSolver` to match `@testable import
//  WordleSolver` in the tests and the Xcode app target's module name, so the
//  same test file works in both build systems.
//
import PackageDescription

let package = Package(
    name: "WordleSolver",
    targets: [
        .target(
            name: "WordleSolver",
            path: "Sources/Model"
        ),
        .testTarget(
            name: "WordleSolverTests",
            dependencies: ["WordleSolver"],
            path: "Tests"
        ),
    ]
)
