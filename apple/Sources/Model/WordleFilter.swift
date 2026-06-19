//
//  WordleFilter.swift
//  WordleSolver
//
//  Swift port of the solver core in index.html (the canonical Wordle Solver):
//    - parseGuesses(guesses)            -> buildConstraints(from:)
//    - filterWords(words, constraints)  -> filter(words:constraints:)
//    - scenarioKey(constraints)         -> scenarioKey(_:)
//
//  This file is pure Foundation (no SwiftUI import) so the logic can be unit
//  tested in isolation — see Tests/WordleFilterTests.swift.
//
//  WHY index.html AND NOT wordle.py: the bot-suggestions feature keys every
//  saved suggestion by `scenarioKey(constraints)`. The committed
//  suggestions.json (and any file exported from the web PWA) was produced by
//  index.html, so this port must compute constraints AND serialize keys
//  byte-for-byte the way index.html does, or those suggestions would never
//  match. index.html's model differs from wordle.py's in two ways: black is
//  derived from black-colored tiles (not a separate string), and there is an
//  extra `maxCount` constraint.
//
//  NOTE: there is no longer a separate "black letters" text field/parameter
//  anywhere in this app. Black is purely derived from tiles the user has
//  tapped to the black color (tiles start black, so an untouched filled tile
//  already counts as a black guess at that letter/position) — see
//  `buildConstraints(from:)` below, which takes ONLY `guesses`.
//

import Foundation

/// Namespace for the solver's pure functions (a `struct` of `static` members).
struct WordleFilter {

    // MARK: - Build constraints

    /// Builds `Constraints` from the current guesses, mirroring index.html's
    /// `parseGuesses`.
    ///
    /// Only fully-typed rows participate: a guess with fewer than 5 letters is
    /// skipped entirely (matches `if (ls.length !== 5 || !ls.every(Boolean))
    /// continue;`). Black comes from black-colored tiles; a letter that is
    /// green/yellow anywhere is removed from the black set.
    static func buildConstraints(from guesses: [Guess]) -> Constraints {
        var constraints = Constraints()

        var confirmed: Set<Character> = []   // letters seen green or yellow
        var blacked: Set<Character> = []     // letters seen on a black tile

        // Per-guess records of (letter, state, position), only for complete
        // rows — the Swift analogue of index.html's `allData`.
        enum State { case green, yellow, black }
        var allData: [[(letter: Character, state: State, pos: Int)]] = []

        for guess in guesses {
            // Require all 5 positions filled; skip the row otherwise.
            let lettersLower: [Character] = (0..<5).compactMap { pos in
                guess.letter(at: pos).map { Character(String($0).lowercased()) }
            }
            guard lettersLower.count == 5 else { continue }

            var data: [(letter: Character, state: State, pos: Int)] = []
            for pos in 0..<5 {
                let letter = lettersLower[pos]
                switch guess.color(at: pos) {
                case .green:
                    constraints.green[pos] = letter
                    confirmed.insert(letter)
                    data.append((letter, .green, pos))
                case .yellow:
                    constraints.yellow[letter, default: []].append(pos)
                    confirmed.insert(letter)
                    data.append((letter, .yellow, pos))
                case .black:
                    blacked.insert(letter)
                    data.append((letter, .black, pos))
                }
            }
            allData.append(data)
        }

        // black = blacked letters that were never confirmed elsewhere.
        constraints.black = blacked.filter { !confirmed.contains($0) }

        // Same-guess black + confirmed: the black copy bounds the letter's
        // count (maxCount) and contributes a yellow position exclusion.
        for data in allData {
            var byLetter: [Character: [(state: State, pos: Int)]] = [:]
            for entry in data {
                byLetter[entry.letter, default: []].append((entry.state, entry.pos))
            }
            for (letter, occ) in byLetter {
                let confirmedHere = occ.filter { $0.state != .black }
                let blackHere = occ.filter { $0.state == .black }
                if !confirmedHere.isEmpty && !blackHere.isEmpty {
                    for hit in blackHere {
                        constraints.yellow[letter, default: []].append(hit.pos)
                    }
                    let mx = confirmedHere.count
                    if let existing = constraints.maxCount[letter] {
                        constraints.maxCount[letter] = min(existing, mx)
                    } else {
                        constraints.maxCount[letter] = mx
                    }
                }
            }
        }

        // Doubled letters: minimum required occurrences.
        var maxInGuess: [Character: Int] = [:]
        var greenPos: [Character: Set<Int>] = [:]
        for data in allData {
            var counts: [Character: Int] = [:]
            for entry in data {
                if entry.state != .black {
                    counts[entry.letter, default: 0] += 1
                }
                if entry.state == .green {
                    greenPos[entry.letter, default: []].insert(entry.pos)
                }
            }
            for (letter, n) in counts where n > (maxInGuess[letter] ?? 0) {
                maxInGuess[letter] = n
            }
        }
        for (letter, mx) in maxInGuess {
            let minReq = max(mx, (greenPos[letter]?.count ?? 0) >= 2 ? 2 : 0)
            if minReq >= 2 {
                constraints.doubled[letter] = minReq
            }
        }

        return constraints
    }

    // MARK: - Filter

    /// Filters `words` down to those consistent with `constraints`.
    /// Mirrors index.html's `filterWords`. Assumes every word is already
    /// lowercase and exactly 5 characters (true for words.txt).
    static func filter(words: [String], constraints: Constraints) -> [String] {
        let green = constraints.green
        let yellow = constraints.yellow
        let black = constraints.black
        let doubled = constraints.doubled
        let maxCount = constraints.maxCount

        return words.filter { word in
            // O(1) indexed access (String integer-offset indexing is O(n)).
            let chars = Array(word)
            guard chars.count == 5 else { return false }

            // 1) Green positions match exactly.
            for (pos, requiredLetter) in green where chars[pos] != requiredLetter {
                return false
            }

            // 2) No black letters present.
            for character in chars where black.contains(character) {
                return false
            }

            // 3) Each yellow letter present, and not at any excluded position.
            for (letter, excludedPositions) in yellow {
                guard chars.contains(letter) else { return false }
                for pos in excludedPositions where chars[pos] == letter {
                    return false
                }
            }

            // 4) Doubled letters appear at least `minRequired` times.
            for (letter, minRequired) in doubled {
                if chars.filter({ $0 == letter }).count < minRequired { return false }
            }

            // 5) maxCount letters appear at most `maximum` times.
            for (letter, maximum) in maxCount {
                if chars.filter({ $0 == letter }).count > maximum { return false }
            }

            return true
        }
    }

    // MARK: - Scenario key

    /// Serializes `constraints` into the SAME string index.html's `scenarioKey`
    /// produces, so it can be used as the lookup key into the bot-suggestions
    /// dictionary (including files exported from the web PWA).
    ///
    /// The reference implementation is:
    /// ```js
    /// JSON.stringify({
    ///   g: Object.entries(green).map(([k,v]) => [+k, v]).sort((a,b)=>a[0]-b[0]),
    ///   y: Object.entries(yellow).map(([l,ps]) => [l, [...ps].sort((a,b)=>a-b)]).sort(),
    ///   b: [...black].sort(),
    ///   m: Object.entries(maxCount).sort(),
    /// })
    /// ```
    /// We build the string by hand (NOT JSONEncoder) so the key order
    /// (g, y, b, m), the lack of whitespace, and the array shapes match
    /// `JSON.stringify` exactly. `y` and `m` are sorted by letter, which is
    /// equivalent to JS's default tuple `.sort()` here because each yellow /
    /// maxCount letter key is unique and single-character.
    static func scenarioKey(_ c: Constraints) -> String {
        let g = c.green.keys.sorted()
            .map { pos in "[\(pos),\"\(c.green[pos]!)\"]" }
            .joined(separator: ",")

        let y = c.yellow.keys.sorted()
            .map { letter -> String in
                let ps = c.yellow[letter]!.sorted().map(String.init).joined(separator: ",")
                return "[\"\(letter)\",[\(ps)]]"
            }
            .joined(separator: ",")

        let b = c.black.sorted()
            .map { "\"\($0)\"" }
            .joined(separator: ",")

        let m = c.maxCount.keys.sorted()
            .map { letter in "[\"\(letter)\",\(c.maxCount[letter]!)]" }
            .joined(separator: ",")

        return "{\"g\":[\(g)],\"y\":[\(y)],\"b\":[\(b)],\"m\":[\(m)]}"
    }
}
