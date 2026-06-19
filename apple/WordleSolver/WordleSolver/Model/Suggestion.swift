//
//  Suggestion.swift
//  WordleSolver
//
//  A single "bot suggests a word" record, keyed elsewhere by
//  `WordleFilter.scenarioKey(_:)`. Mirrors the shape of one entry in
//  index.html's `SUGGESTIONS` object / the committed `suggestions.json`:
//
//      "<scenarioKey>": { "word": "slice", "note": "", "remaining": 12,
//                          "saved": "2026-05-31" }
//
//  Pure Foundation (no SwiftUI import) — same reasoning as Constraints.swift.
//

import Foundation

/// One recorded bot suggestion for a given scenario (set of constraints).
struct Suggestion: Codable, Equatable {
    /// The 5-letter word the bot suggested, always lowercase.
    var word: String

    /// Optional free-form note explaining the suggestion. Empty string if
    /// none was given (matches index.html, which stores `note.trim()` —
    /// never omits the key).
    var note: String

    /// How many candidate words remained when this suggestion was saved.
    /// Optional because older/hand-written suggestions.json entries may
    /// omit it entirely (see the bundled file: most entries have no
    /// "remaining" key at all).
    var remaining: Int?

    /// The date this suggestion was saved, as "yyyy-MM-dd" (ISO date, no
    /// time component) — matches index.html's
    /// `new Date().toISOString().slice(0, 10)`.
    var saved: String
}

/// The top-level shape of an exported/bundled suggestions JSON file:
/// `{ "version": 1, "suggestions": { "<scenarioKey>": Suggestion, ... } }`.
struct SuggestionsFile: Codable {
    var version: Int
    var suggestions: [String: Suggestion]
}
