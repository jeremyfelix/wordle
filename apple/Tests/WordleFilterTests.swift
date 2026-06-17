//
//  WordleFilterTests.swift
//  WordleSolverTests
//
//  Port of test_wordle.py's TestParsePatterns / TestFilterWords /
//  TestEdgeCases suites onto the Swift `WordleFilter.buildConstraints` /
//  `WordleFilter.filter` functions.
//
//  MODULE NAME ASSUMPTION: `@testable import WordleSolver` below assumes
//  the Xcode app target (and therefore its module name) is named
//  "WordleSolver", as instructed in apple/README.md section 2. If you name
//  your Xcode project something else, change this line to match — it's the
//  one thing in this file that depends on a name choice made outside this
//  source tree.
//
//  NOT PORTED: test_wordle.py also has `test_word_too_short`,
//  `test_word_too_long`, and `test_invalid_character_in_pattern`, which
//  assert that `parse_patterns` raises `ValueError` for malformed pattern
//  STRINGS. The Swift app never parses pattern strings in production code —
//  `Guess` is built directly from UI state (5 fixed letter/color slots), so
//  there's no string format to validate and no equivalent error path to
//  test. Skipped intentionally, not by oversight.
//

import XCTest
@testable import WordleSolver

final class WordleFilterTests: XCTestCase {

    // MARK: - Seeded test word set (mirrors TEST_WORDS in test_wordle.py)

    // Kept as a plain array, including the duplicate "attic" entry that the
    // Python list also has (harmless — `filter` just operates on whatever
    // array it's given) for line-by-line fidelity with the original.
    private let testWords: [String] = [
        "abide",  // a, b, i, d, e (no duplicates)
        "abate",  // has 'a' twice at different positions
        "attic",  // has 't' twice, 'a' once
        "alloy",  // has 'l' twice
        "allay",  // has 'l' twice and 'a' twice
        "abbey",  // has 'b' twice and 'e' twice
        "added",  // has 'a' and 'd' twice each
        "daddy",  // has 'd' three times
        "eerie",  // has 'e' three times
        "apple",  // has 'p' twice
        "attic",  // duplicate entry, kept for fidelity with test_wordle.py
        "batch",  // single instances, no duplicates
        "catch",  // single instances, no duplicates
        "cacti",  // has 'c' twice
        "attap",  // has 't' twice at positions 0,1
        "attar",  // has 't' twice and 'a' twice
        "tatty",  // has 't' three times, 'a' once
        "kitty",  // has 't' twice, 'k' and 'i' once
        "ditty",  // has 't' twice, 'd' once
        "motto",  // has 't' twice, 'o' twice, 'm' once
        "petty",  // has 't' twice, 'p' and 'e' once
        "putty",  // has 't' twice, 'p' and 'u' once
        "atone",  // 'a' once, no duplicates
        "alone",  // 'a' once, no duplicates
        "about",  // no duplicates
        "route",  // no duplicates
    ]

    // MARK: - Test helper: pattern string -> Guess

    /// Converts a 5-character wordle.py-style pattern string into a `Guess`,
    /// purely so test bodies below can stay visually close to the Python
    /// originals (e.g. `"..at."`) and are easy to diff against
    /// test_wordle.py. This is a TEST-ONLY convenience — the shipped app
    /// never parses pattern strings; `Guess` values come directly from
    /// tapped tiles and typed text.
    ///
    /// - Uppercase letter = green tile.
    /// - Lowercase letter = yellow tile.
    /// - '.' = black/empty tile (no letter).
    private func makeGuess(_ pattern: String) -> Guess {
        precondition(pattern.count == 5, "Test pattern must be exactly 5 characters: \(pattern)")
        var guess = Guess()
        for (position, character) in pattern.enumerated() {
            if character == "." {
                continue
            } else if character.isUppercase {
                guess.letters[position] = Character(String(character).lowercased())
                guess.colors[position] = .green
            } else if character.isLowercase {
                guess.letters[position] = character
                guess.colors[position] = .yellow
            } else {
                preconditionFailure("Invalid test pattern character: \(character)")
            }
        }
        return guess
    }

    private func constraints(_ patterns: [String], black: String = "") -> Constraints {
        let guesses = patterns.map { makeGuess($0) }
        return WordleFilter.buildConstraints(from: guesses, blackLetters: black)
    }

    // MARK: - parse_patterns equivalents (TestParsePatterns)

    func testGreenPositions() {
        let c = constraints(["A...."])
        XCTAssertEqual(c.green, [0: "a"])
        XCTAssertTrue(c.yellow.isEmpty)
    }

    func testYellowPositions() {
        let c = constraints(["a...."])
        XCTAssertEqual(c.yellow, ["a": [0]])
        XCTAssertTrue(c.green.isEmpty)
    }

    func testBlackLetters() {
        let c = constraints(["....."], black: "xyz")
        XCTAssertEqual(c.black, Set("xyz"))
    }

    func testMixedPattern() {
        let c = constraints(["A.b.."], black: "xyz")
        XCTAssertEqual(c.green, [0: "a"])
        XCTAssertEqual(c.yellow, ["b": [2]])
        XCTAssertEqual(c.black, Set("xyz"))
    }

    func testDoubledFromSingleGuessMultipleColored() {
        // "..T.." has 't' colored once -> not doubled.
        let c1 = constraints(["..T.."])
        XCTAssertNil(c1.doubled["t"])

        // "..T.T" has 't' colored twice in one guess -> doubled = 2.
        let c2 = constraints(["..T.T"])
        XCTAssertEqual(c2.doubled["t"], 2)
    }

    func testDoubledFromSingleGuessThreeTimes() {
        let c = constraints(["T.T.T"])
        XCTAssertEqual(c.doubled["t"], 3)
    }

    func testDoubledFromGreenAndYellow() {
        // Green 't' at position 0, yellow 't' at position 2, SAME guess.
        let c = constraints(["T.t.."])
        XCTAssertEqual(c.doubled["t"], 2)
    }

    func testDoubledFromGreenTwice() {
        // Green 't' at two different positions, same guess.
        let c = constraints(["T.T.."])
        XCTAssertEqual(c.doubled["t"], 2)
    }

    func testNotDoubledFromYellowAcrossGuesses() {
        // 't' yellow at position 0 in guess 1, yellow at position 4 in
        // guess 2 -> does NOT imply 2 copies (each guess only colored it
        // once, and it was never green anywhere).
        let c = constraints(["t....", "....t"])
        XCTAssertNil(c.doubled["t"])
    }

    func testNotDoubledFromGreenAndYellowAcrossGuesses() {
        // Green 't' at position 0 in guess 1, yellow 't' at position 4 in
        // guess 2 -> does NOT imply 2 copies (max colored count within any
        // single guess is 1, and 't' is green at only 1 distinct position).
        let c = constraints(["T....", "....t"])
        XCTAssertNil(c.doubled["t"])
    }

    func testDoubledFromGreenTwiceAcrossGuesses() {
        // Green 't' at position 0 in guess 1, green 't' at position 4 in
        // guess 2 -> two DIFFERENT green positions across guesses -> 2.
        let c = constraints(["T....", "....T"])
        XCTAssertEqual(c.doubled["t"], 2)
    }

    func testNotDoubledFromGreenSamePositionAcrossGuesses() {
        // Green 't' at position 0 in both guesses -> same position both
        // times, so the accumulated green-position set has size 1 -> not
        // doubled.
        let c = constraints(["T....", "Tr..."])
        XCTAssertNil(c.doubled["t"])
    }

    func testYellowAtTwoPositionsSingleGuess() {
        // 't' yellow at positions 1 and 3, same guess -> doubled = 2.
        let c = constraints([".t.t."])
        XCTAssertEqual(c.doubled["t"], 2)
    }

    func testMultipleDoubledLetters() {
        // Green 'a' at positions 0 and 2 -> 'a' doubled.
        let c1 = constraints(["A.A.."])
        XCTAssertEqual(c1.doubled["a"], 2)

        // Adding a second guess with an unrelated green 'b' doesn't change
        // the 'a' inference.
        let c2 = constraints(["A.A..", "...B."])
        XCTAssertEqual(c2.doubled["a"], 2)
    }

    // MARK: - filter_words equivalents (TestFilterWords)

    func testFilterGreenPositions() {
        let c = constraints(["A...."])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        XCTAssertTrue(filtered.allSatisfy { $0.first == "a" })
        XCTAssertTrue(filtered.contains("abide"))
        XCTAssertTrue(filtered.contains("attic"))
    }

    func testFilterYellowPositions() {
        let c = constraints(["a...."])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        for word in filtered {
            XCTAssertTrue(word.contains("a"))
            XCTAssertNotEqual(Array(word)[0], "a")
        }
    }

    func testFilterBlackLetters() {
        let c = constraints(["....."], black: "xyz")
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        for word in filtered {
            XCTAssertFalse(word.contains("x"))
            XCTAssertFalse(word.contains("y"))
            XCTAssertFalse(word.contains("z"))
        }
    }

    func testFilterDoubledLettersRequired() {
        // Green 't' at position 2, yellow 't' at position 3, same guess ->
        // forces 't' to appear at least twice.
        let c = constraints(["..T.t"])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        for word in filtered {
            XCTAssertGreaterEqual(word.filter { $0 == "t" }.count, 2)
        }
        XCTAssertTrue(filtered.contains("attic"))
        XCTAssertFalse(filtered.contains("batch"))
        XCTAssertFalse(filtered.contains("catch"))
    }

    func testFilterBothGreenAndYellow() {
        // Green 'a' at position 0, yellow 't' (excluded from position 2).
        let c = constraints(["A.t.."])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        for word in filtered {
            let chars = Array(word)
            XCTAssertEqual(chars[0], "a")
            XCTAssertTrue(word.contains("t"))
            XCTAssertNotEqual(chars[2], "t")
        }
    }

    func testFilterYellowExcludesPosition() {
        let c = constraints([".a..."])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        for word in filtered {
            let chars = Array(word)
            XCTAssertTrue(word.contains("a"))
            XCTAssertNotEqual(chars[1], "a")
        }
    }

    func testFilterComplexScenario1() {
        // Green 'a' at position 0; yellow 't' excluded from position 2;
        // black letters b, c, d, e.
        let c = constraints(["A.t.."], black: "bcde")
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        for word in filtered {
            let chars = Array(word)
            XCTAssertEqual(chars[0], "a")
            XCTAssertTrue(word.contains("t"))
            XCTAssertNotEqual(chars[2], "t")
            XCTAssertFalse(word.contains("b"))
            XCTAssertFalse(word.contains("c"))
            XCTAssertFalse(word.contains("d"))
            XCTAssertFalse(word.contains("e"))
        }
    }

    func testFilterExcludingAllWords() {
        // Requires 'z' at position 0, which no word in testWords has.
        let c = constraints(["Z...."])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        XCTAssertEqual(filtered.count, 0)
    }

    func testFilterNoConstraints() {
        let c = constraints(["....."])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        XCTAssertEqual(filtered.count, testWords.count)
    }

    // MARK: - The "attic" / "attap" user-reported scenario

    func testAtticAttapScenario() {
        // Patterns "..at." and "ta..t", black letters "slero".
        let c = constraints(["..at.", "ta..t"], black: "slero")

        // 'a' appears once per guess (never green twice, never colored
        // twice within one guess) -> NOT doubled.
        XCTAssertNil(c.doubled["a"])

        // 't' is yellow twice within the second guess ("ta..t" has 't' at
        // position 0 AND position 4) -> doubled, >= 2.
        XCTAssertNotNil(c.doubled["t"])
        XCTAssertGreaterEqual(c.doubled["t"] ?? 0, 2)

        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        XCTAssertTrue(filtered.contains("attic"))
        XCTAssertTrue(filtered.contains("attap"))
        XCTAssertFalse(filtered.contains("batch"))
        XCTAssertFalse(filtered.contains("catch"))
    }

    // MARK: - Edge cases (TestEdgeCases)

    func testAllSameLetter() {
        // Black covers every letter except 'a'; green 'a' at position 0.
        // No word in testWords is all-'a', so this should match nothing
        // but must not crash.
        let c = constraints(["A...."], black: "bcdefghijklmnopqrstuvwxyz")
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        XCTAssertEqual(filtered.count, 0)
    }

    func testLetterWithHighCount() {
        // 't' appears 3 times (green) in one guess -> requires >= 3 't's.
        let c = constraints(["T.T.T"])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        for word in filtered {
            XCTAssertGreaterEqual(word.filter { $0 == "t" }.count, 3)
        }
    }

    func testYellowAtMultiplePositionsSingleGuess() {
        // 't' yellow at positions 1 and 3.
        let c = constraints([".t.t."])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        for word in filtered {
            let chars = Array(word)
            XCTAssertGreaterEqual(word.filter { $0 == "t" }.count, 2)
            XCTAssertNotEqual(chars[1], "t")
            XCTAssertNotEqual(chars[3], "t")
        }
    }
}
