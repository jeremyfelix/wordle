//
//  Constraints.swift
//  WordleSolver
//
//  Core value types for the Wordle solver. This file intentionally does NOT
//  import SwiftUI — it's pure Foundation so it can be unit tested and reused
//  without pulling in any UI framework. (Beginner note: keeping "model" code
//  free of UI imports is a common iOS architecture pattern often called
//  MVVM — it makes the logic easy to test and easy to reason about.)
//

import Foundation

/// The three tile colors a Wordle guess letter can have, matching the web
/// app's `data-color` values ("black", "yellow", "green") and wordle.py's
/// pattern characters ('.', lowercase, UPPERCASE).
///
/// - black: letter is not in the word (or position/letter is still unknown
///   for an empty tile — see `Guess`, which tracks "has a letter" separately).
/// - yellow: letter is in the word, but not at this position.
/// - green: letter is in the word, at exactly this position.
enum TileColor: String, Codable, CaseIterable {
    case black
    case yellow
    case green

    /// Tapping a tile cycles its color: black -> yellow -> green -> black.
    /// This mirrors index.html's `onTileClick`, which does
    /// `COLORS[(idx + 1) % COLORS.length]`.
    var next: TileColor {
        switch self {
        case .black: return .yellow
        case .yellow: return .green
        case .green: return .black
        }
    }
}

/// One row of the solver UI: a 5-letter guess with a color per tile.
///
/// Modeling note: `letters` is `[Character?]` (5 slots, any of which may be
/// empty/nil) rather than a `String`, because a guess row can be partially
/// filled in the UI (e.g. only 3 of 5 tiles typed so far).
///
/// Codable note: `Character` does NOT conform to `Codable` in the Swift
/// standard library, so `[Character?]` cannot synthesize `Codable`
/// automatically. We therefore implement `Codable` by hand, encoding each
/// letter as an optional single-character `String` (`[String?]`) and
/// converting back to `Character` on decode. This keeps the rest of the app's
/// `[Character?]` API unchanged while still persisting cleanly to JSON /
/// UserDefaults.
struct Guess: Identifiable, Codable, Equatable {
    let id: UUID

    /// Exactly 5 slots. `nil` means "no letter typed yet at this position".
    var letters: [Character?]

    /// Exactly 5 slots, parallel to `letters`. Defaults to `.black` for every
    /// position (matches the web app's tiles always starting black).
    var colors: [TileColor]

    init(id: UUID = UUID(), letters: [Character?] = Array(repeating: nil, count: 5), colors: [TileColor] = Array(repeating: .black, count: 5)) {
        self.id = id
        self.letters = letters
        self.colors = colors
    }

    // MARK: - Codable (manual, because Character isn't Codable)

    private enum CodingKeys: String, CodingKey {
        case id, letters, colors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        colors = try container.decode([TileColor].self, forKey: .colors)
        // Each letter persists as an optional single-character String.
        let stringLetters = try container.decode([String?].self, forKey: .letters)
        letters = stringLetters.map { $0?.first }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(colors, forKey: .colors)
        let stringLetters: [String?] = letters.map { $0.map(String.init) }
        try container.encode(stringLetters, forKey: .letters)
    }

    /// Convenience accessor: the letter at `position` (0...4), or nil.
    func letter(at position: Int) -> Character? {
        guard letters.indices.contains(position) else { return nil }
        return letters[position]
    }

    /// Convenience accessor: the color at `position` (0...4). Falls back to
    /// `.black` if `position` is somehow out of range (defensive default;
    /// should never happen since rows are always created with 5 slots).
    func color(at position: Int) -> TileColor {
        guard colors.indices.contains(position) else { return .black }
        return colors[position]
    }

    /// True if every tile in this row is still empty (no letters typed).
    var isEmpty: Bool {
        letters.allSatisfy { $0 == nil }
    }
}

/// The fully-parsed set of constraints derived from all current guesses,
/// equivalent to the web app's `parseGuesses` return object in index.html:
/// `{ green, yellow, black, doubled, maxCount }`.
///
/// IMPORTANT — this models index.html (the canonical Wordle Solver the repo
/// owner actually uses), NOT wordle.py. The two differ in two ways that matter
/// here: index.html derives `black` from black-COLORED TILES (not a separate
/// "--black" string), and it adds a `maxCount` constraint. Matching index.html
/// exactly is what lets `WordleFilter.scenarioKey` reproduce the same bot
/// suggestion keys, so suggestions exported from the web PWA import and match
/// in this native app.
///
/// All letters stored here are lowercase.
struct Constraints: Equatable {
    /// position -> required letter (green tiles).
    var green: [Int: Character] = [:]

    /// letter -> list of positions where that letter is known NOT to be
    /// (yellow tiles: the letter is in the word, but not at these spots).
    /// Positions are intentionally NOT de-duplicated, mirroring index.html
    /// (so `scenarioKey` stays byte-identical to the web app).
    var yellow: [Character: [Int]] = [:]

    /// Letters confirmed to not be in the word at all (a letter that is also
    /// green/yellow somewhere is excluded from this set).
    var black: Set<Character> = []

    /// letter -> minimum number of times that letter must appear in the
    /// word. Only present for letters where the guesses imply 2+ copies
    /// (e.g. two green 't's, or 't' green once and yellow once in the SAME
    /// guess). See `WordleFilter.buildConstraints`.
    var doubled: [Character: Int] = [:]

    /// letter -> maximum number of times that letter may appear in the word.
    /// Derived when a letter shows up as BOTH confirmed (green/yellow) and
    /// black within a single guess: the black copy proves there are no more
    /// than the confirmed count of that letter. Mirrors index.html's
    /// `maxCount`.
    var maxCount: [Character: Int] = [:]
}
