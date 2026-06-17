//
//  WordleFilter.swift
//  WordleSolver
//
//  Swift port of the two core functions in wordle.py:
//    - parse_patterns(patterns, black_letters) -> buildConstraints(...)
//    - filter_words(words, constraints)        -> filter(words:constraints:)
//
//  This file is pure Foundation (no SwiftUI import) so the logic can be unit
//  tested in isolation — see Tests/WordleFilterTests.swift.
//
//  Design note: wordle.py builds a regex (`build_filter_regex`) to check the
//  green-position constraint, then does separate plain-Swift-style checks
//  for black/yellow/doubled. This port skips the regex step entirely and
//  does direct character-array comparisons for ALL constraints, including
//  green positions. This is behaviorally identical (a regex anchored with
//  fixed positions and '.' wildcards is just per-index equality) but is more
//  idiomatic Swift and avoids the overhead/edge cases of constructing and
//  compiling an NSRegularExpression for every filter pass.
//

import Foundation

/// Namespace for the solver's pure functions. A `struct` with only `static`
/// members is a common Swift pattern for grouping free functions without
/// instantiating anything (similar to a Python module of top-level
/// functions).
struct WordleFilter {

    /// Builds `Constraints` from the current guesses plus a separate
    /// "black letters" string (mirrors wordle.py's `--black` CLI flag /
    /// `parse_patterns(patterns, black_letters)`).
    ///
    /// - Parameters:
    ///   - guesses: All guess rows currently entered, in any order. Rows
    ///     with no letters at a given position simply contribute nothing
    ///     for that position (this matches skipping a blank tile — there is
    ///     no Python equivalent needed since wordle.py's patterns are always
    ///     fully-specified 5-character strings, but the UI lets a row be
    ///     partially filled in).
    ///   - blackLetters: Free-form string of letters known to be absent from
    ///     the word, independent of any tile color. Only this string (not
    ///     '.'-colored tiles) populates `Constraints.black`, exactly like
    ///     `black = set(black_letters)` in `parse_patterns` — a literal `.`
    ///     pattern character in wordle.py also contributes nothing to
    ///     `black` on its own.
    static func buildConstraints(from guesses: [Guess], blackLetters: String) -> Constraints {
        var constraints = Constraints()

        // `black` comes only from the separate blackLetters string.
        constraints.black = Set(blackLetters.lowercased())

        // Tracks, for each letter, the maximum number of green-or-yellow
        // colored tiles seen for that letter WITHIN a single guess (reset
        // per guess, then folded into a running max). Mirrors Python's
        // `max_in_guess` defaultdict.
        var maxInGuess: [Character: Int] = [:]

        // Tracks every position where a letter was GREEN, accumulated
        // across ALL guesses (never reset between guesses). Mirrors
        // Python's `letter_data[letter]['green_pos']` set.
        var greenPositions: [Character: Set<Int>] = [:]

        // Every letter we've ever seen colored (green or yellow), so we can
        // compute `doubled` for all of them at the end — mirrors Python's
        // `set(list(letter_data.keys()) + list(max_in_guess.keys()))`.
        var seenLetters: Set<Character> = []

        for guess in guesses {
            // Per-guess letter counts (green + yellow only), used to find
            // the max colored-copies-in-one-guess for this guess.
            var countsThisGuess: [Character: Int] = [:]

            for position in 0..<5 {
                guard let rawLetter = guess.letter(at: position) else {
                    // Empty tile — contributes nothing (no letter typed yet).
                    continue
                }
                let letter = Character(String(rawLetter).lowercased())
                let color = guess.color(at: position)

                switch color {
                case .green:
                    constraints.green[position] = letter
                    greenPositions[letter, default: []].insert(position)
                    countsThisGuess[letter, default: 0] += 1
                    seenLetters.insert(letter)
                case .yellow:
                    constraints.yellow[letter, default: []].append(position)
                    countsThisGuess[letter, default: 0] += 1
                    seenLetters.insert(letter)
                case .black:
                    // A black tile with a letter contributes nothing to
                    // `constraints.black` — exactly like a '.' character in
                    // a wordle.py pattern. Only the separate blackLetters
                    // string populates the black set.
                    break
                }
            }

            for (letter, count) in countsThisGuess {
                if count > (maxInGuess[letter] ?? 0) {
                    maxInGuess[letter] = count
                }
            }
        }

        // Compute doubled-letter minimum-required-occurrence constraints.
        for letter in seenLetters {
            var minRequired = maxInGuess[letter] ?? 0
            if (greenPositions[letter]?.count ?? 0) >= 2 {
                minRequired = max(minRequired, 2)
            }
            if minRequired >= 2 {
                constraints.doubled[letter] = minRequired
            }
        }

        return constraints
    }

    /// Filters `words` down to those consistent with `constraints`.
    /// Mirrors wordle.py's `filter_words`. Assumes every word in `words` is
    /// already lowercase and exactly 5 characters (true for `words.txt`).
    static func filter(words: [String], constraints: Constraints) -> [String] {
        // Pre-extract constraint pieces once outside the loop (avoids
        // repeated dictionary lookups per word, and reads closer to the
        // Python original which destructures `constraints` up front too).
        let green = constraints.green
        let yellow = constraints.yellow
        let black = constraints.black
        let doubled = constraints.doubled

        return words.filter { word in
            // Swift's String indexing by integer offset is O(n) because
            // strings are collections of grapheme clusters, not random
            // access arrays. Converting to `[Character]` once per word
            // gives O(1) indexed access for all the checks below.
            let chars = Array(word)
            guard chars.count == 5 else { return false }

            // 1) Green positions must match exactly (equivalent to the
            // regex anchor `^.....$` with green letters substituted in).
            for (position, requiredLetter) in green {
                guard chars.indices.contains(position), chars[position] == requiredLetter else {
                    return false
                }
            }

            // 2) Word must contain none of the black letters.
            for character in chars {
                if black.contains(character) {
                    return false
                }
            }

            // 3) Each yellow letter must be present somewhere in the word,
            // and must NOT appear at any of its excluded positions.
            for (letter, excludedPositions) in yellow {
                guard chars.contains(letter) else { return false }
                for position in excludedPositions {
                    if chars.indices.contains(position), chars[position] == letter {
                        return false
                    }
                }
            }

            // 4) Doubled letters must appear at least `minRequired` times.
            for (letter, minRequired) in doubled {
                let count = chars.filter { $0 == letter }.count
                if count < minRequired {
                    return false
                }
            }

            return true
        }
    }
}
