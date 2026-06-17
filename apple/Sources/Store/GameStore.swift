//
//  GameStore.swift
//  WordleSolver
//
//  The single source of truth for app state: the list of guess rows, the
//  black-letters text, and the currently-matching candidate words. This is
//  an `ObservableObject` so SwiftUI views can subscribe to it and
//  automatically redraw whenever something changes (beginner note: this is
//  the standard "ViewModel" piece of the MVVM pattern used throughout
//  SwiftUI apps).
//
//  Persistence note: state is saved to `UserDefaults` as JSON. This is
//  native iOS/macOS persistence, which is more durable than a web app's
//  `localStorage` — `UserDefaults` survives app UPDATES (re-installing a new
//  version of the app from the App Store/TestFlight keeps it), whereas a
//  PWA's localStorage can be cleared by the browser or OS more aggressively
//  (e.g. iOS Safari can purge site data for PWAs that haven't been opened in
//  a while). `UserDefaults` is wiped only if the user deletes the app
//  entirely or explicitly resets it.
//

import Foundation
import Combine

@MainActor
final class GameStore: ObservableObject {

    /// All guess rows currently shown in the UI.
    @Published var guesses: [Guess] {
        didSet {
            recompute()
            persist()
        }
    }

    /// Free-form string of letters known to be absent from the word
    /// (mirrors wordle.py's `--black` flag). Independent of any tile.
    @Published var blackLetters: String = "" {
        didSet {
            recompute()
            persist()
        }
    }

    /// The words from `words.txt` still consistent with all current
    /// guesses + blackLetters. Recomputed automatically whenever `guesses`
    /// or `blackLetters` changes — never persisted, since it's derived.
    @Published private(set) var candidates: [String] = []

    /// The full dictionary, loaded once at startup.
    private let allWords: [String]

    private static let storageKey = "wordle.gamestate.v1"

    /// What actually gets encoded to JSON and saved to UserDefaults.
    private struct PersistedState: Codable {
        var guesses: [Guess]
        var blackLetters: String
    }

    init() {
        // Load the dictionary first; this doesn't depend on persisted state.
        self.allWords = WordList.load()

        // Load any previously-saved guesses/blackLetters. If nothing was
        // saved yet (first launch), start with a single empty guess row,
        // matching the web app's `loadState()` fallback of `addRow()`.
        if let saved = GameStore.loadPersisted() {
            self.guesses = saved.guesses
            self.blackLetters = saved.blackLetters
        } else {
            self.guesses = [Guess()]
            self.blackLetters = ""
        }

        // `didSet` does not fire for a property's own initial assignment
        // inside `init`, so we compute candidates once explicitly here to
        // make sure the UI has correct data as soon as the store exists.
        recompute()
    }

    /// Appends a new empty guess row.
    func addGuess() {
        guesses.append(Guess())
    }

    /// Removes the guess row at `index`, if that index is valid. Spec'd as
    /// an index-based method; the views in this project actually call
    /// `deleteGuess(id:)` below (safer when rows can be removed out of
    /// order), but this index-based variant is kept too since it's a
    /// natural, simple API for a store like this.
    func deleteGuess(at index: Int) {
        guard guesses.indices.contains(index) else { return }
        guesses.remove(at: index)
    }

    /// Removes the guess row with the matching `id`. This is what
    /// `ContentView`/`GuessRowView` actually use, because identifying a row
    /// by its stable `id` (rather than its current array index) is robust
    /// even if rows are deleted in quick succession or reordered.
    func deleteGuess(id: UUID) {
        guesses.removeAll { $0.id == id }
    }

    /// Replaces the guess with the same `id` as `updated`. Used by
    /// `GuessRowView` to push local edits (typed letters, tapped tile
    /// colors) back into the store.
    func updateGuess(_ updated: Guess) {
        guard let index = guesses.firstIndex(where: { $0.id == updated.id }) else { return }
        guesses[index] = updated
    }

    /// Clears everything back to a single empty row, mirroring the web
    /// app's "Clear" button.
    func reset() {
        guesses = [Guess()]
        blackLetters = ""
    }

    /// Recomputes `candidates` from the current guesses + blackLetters.
    /// Note there's no special-casing needed for "no guesses yet": an empty
    /// guess list and empty blackLetters produce empty constraints, and
    /// `WordleFilter.filter` then returns every word unchanged — exactly
    /// the same "show everything" behavior the web app gets from its
    /// `hasInput` check, just without needing a separate branch.
    private func recompute() {
        let constraints = WordleFilter.buildConstraints(from: guesses, blackLetters: blackLetters)
        candidates = WordleFilter.filter(words: allWords, constraints: constraints)
    }

    // MARK: - Persistence

    private func persist() {
        let state = PersistedState(guesses: guesses, blackLetters: blackLetters)
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: GameStore.storageKey)
    }

    private static func loadPersisted() -> PersistedState? {
        guard let data = UserDefaults.standard.data(forKey: GameStore.storageKey) else { return nil }
        return try? JSONDecoder().decode(PersistedState.self, from: data)
    }
}
