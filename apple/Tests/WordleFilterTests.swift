//
//  WordleFilterTests.swift
//  WordleSolverTests
//
//  Port of test_wordle.py's TestParsePatterns / TestFilterWords /
//  TestEdgeCases suites onto the Swift `WordleFilter.buildConstraints` /
//  `WordleFilter.filter` functions — REWRITTEN for the new (index.html-
//  accurate) tile model: there is no separate "black letters" string
//  anymore. Black is derived purely from black-COLORED tiles, exactly like
//  a real Wordle guess where every typed letter has a color (a tile starts
//  black and stays black unless tapped to yellow/green).
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
        "board",  // no duplicates; used by the maxCount tests below
        "float",  // no duplicates; used by the maxCount tests below
    ]

    // MARK: - Test helper: word + colors -> Guess

    /// Builds a COMPLETE 5-letter `Guess` from an explicit word and a
    /// parallel array of 5 `TileColor`s — the natural shape of the new
    /// tile model, where every filled tile always has a color (default
    /// black) rather than "black" being a separate side-channel string.
    /// This is a TEST-ONLY convenience; production code builds `Guess`
    /// values directly from tapped tiles and typed text.
    private func makeGuess(_ word: String, _ colors: [TileColor]) -> Guess {
        precondition(word.count == 5, "Test word must be exactly 5 characters: \(word)")
        precondition(colors.count == 5, "Must supply exactly 5 colors for: \(word)")
        let letters: [Character?] = word.lowercased().map { $0 }
        return Guess(letters: letters, colors: colors)
    }

    /// Shorthand for building constraints from one or more (word, colors)
    /// guesses.
    private func constraints(_ guesses: [(String, [TileColor])]) -> Constraints {
        WordleFilter.buildConstraints(from: guesses.map { makeGuess($0.0, $0.1) })
    }

    // MARK: - parseGuesses equivalents (TestParsePatterns)

    func testGreenPositions() {
        // "A...." -> green 'a' at position 0; rest black with a DIFFERENT
        // filler letter ('x'), so the black tiles don't share a letter
        // with the green tile (sharing one would trigger the maxCount /
        // extra-yellow-exclusion logic tested separately below).
        let c = constraints([("axxxx", [.green, .black, .black, .black, .black])])
        XCTAssertEqual(c.green, [0: "a"])
        XCTAssertTrue(c.yellow.isEmpty)
    }

    func testYellowPositions() {
        // "a...." -> yellow 'a' at position 0; rest black (different
        // letters so we don't trigger maxCount/doubled side effects).
        let c = constraints([("abcde", [.yellow, .black, .black, .black, .black])])
        XCTAssertEqual(c.yellow, ["a": [0]])
        XCTAssertTrue(c.green.isEmpty)
    }

    func testBlackLetters() {
        // All five tiles black -> every distinct letter ends up in `black`
        // (mirrors the old `black: "xyz"` flag, now expressed as tiles).
        let c = constraints([("vwxyz", [.black, .black, .black, .black, .black])])
        XCTAssertEqual(c.black, Set("vwxyz"))
    }

    func testMixedPattern() {
        // Green 'a' at 0, yellow 'b' at 2, black the other three letters.
        let c = constraints([("axbxx", [.green, .black, .yellow, .black, .black])])
        XCTAssertEqual(c.green, [0: "a"])
        XCTAssertEqual(c.yellow, ["b": [2]])
        XCTAssertTrue(c.black.contains("x"))
    }

    func testDoubledFromSingleGuessMultipleColored() {
        // 't' colored (green) once -> not doubled.
        let c1 = constraints([("xxtxx", [.black, .black, .green, .black, .black])])
        XCTAssertNil(c1.doubled["t"])

        // 't' colored (green) twice in one guess -> doubled = 2.
        let c2 = constraints([("xxtxt", [.black, .black, .green, .black, .green])])
        XCTAssertEqual(c2.doubled["t"], 2)
    }

    func testDoubledFromSingleGuessThreeTimes() {
        let c = constraints([("txtxt", [.green, .black, .green, .black, .green])])
        XCTAssertEqual(c.doubled["t"], 3)
    }

    func testDoubledFromGreenAndYellow() {
        // Green 't' at position 0, yellow 't' at position 2, SAME guess.
        let c = constraints([("txtxx", [.green, .black, .yellow, .black, .black])])
        XCTAssertEqual(c.doubled["t"], 2)
    }

    func testDoubledFromGreenTwice() {
        // Green 't' at two different positions, same guess.
        let c = constraints([("txtxx", [.green, .black, .green, .black, .black])])
        XCTAssertEqual(c.doubled["t"], 2)
    }

    func testNotDoubledFromYellowAcrossGuesses() {
        // 't' yellow at position 0 in guess 1, yellow at position 4 in
        // guess 2 -> does NOT imply 2 copies (each guess only colored it
        // once, and it was never green anywhere).
        let c = constraints([
            ("txxxx", [.yellow, .black, .black, .black, .black]),
            ("xxxxt", [.black, .black, .black, .black, .yellow]),
        ])
        XCTAssertNil(c.doubled["t"])
    }

    func testNotDoubledFromGreenAndYellowAcrossGuesses() {
        // Green 't' at position 0 in guess 1, yellow 't' at position 4 in
        // guess 2 -> does NOT imply 2 copies (max colored count within any
        // single guess is 1, and 't' is green at only 1 distinct position).
        let c = constraints([
            ("txxxx", [.green, .black, .black, .black, .black]),
            ("xxxxt", [.black, .black, .black, .black, .yellow]),
        ])
        XCTAssertNil(c.doubled["t"])
    }

    func testDoubledFromGreenTwiceAcrossGuesses() {
        // Green 't' at position 0 in guess 1, green 't' at position 4 in
        // guess 2 -> two DIFFERENT green positions across guesses -> 2.
        let c = constraints([
            ("txxxx", [.green, .black, .black, .black, .black]),
            ("xxxxt", [.black, .black, .black, .black, .green]),
        ])
        XCTAssertEqual(c.doubled["t"], 2)
    }

    func testNotDoubledFromGreenSamePositionAcrossGuesses() {
        // Green 't' at position 0 in both guesses -> same position both
        // times, so the accumulated green-position set has size 1 -> not
        // doubled.
        let c = constraints([
            ("txxxx", [.green, .black, .black, .black, .black]),
            ("trxxx", [.green, .black, .black, .black, .black]),
        ])
        XCTAssertNil(c.doubled["t"])
    }

    func testYellowAtTwoPositionsSingleGuess() {
        // 't' yellow at positions 1 and 3, same guess -> doubled = 2.
        let c = constraints([("xtxtx", [.black, .yellow, .black, .yellow, .black])])
        XCTAssertEqual(c.doubled["t"], 2)
    }

    func testMultipleDoubledLetters() {
        // Green 'a' at positions 0 and 2 -> 'a' doubled.
        let c1 = constraints([("axaxx", [.green, .black, .green, .black, .black])])
        XCTAssertEqual(c1.doubled["a"], 2)

        // Adding a second guess with an unrelated green 'b' doesn't change
        // the 'a' inference.
        let c2 = constraints([
            ("axaxx", [.green, .black, .green, .black, .black]),
            ("xxxbx", [.black, .black, .black, .green, .black]),
        ])
        XCTAssertEqual(c2.doubled["a"], 2)
    }

    // MARK: - maxCount (NEW in index.html's model; no wordle.py equivalent)

    func testMaxCountFromGreenAndBlackSameWordSameLetter() {
        // Word "noosy": n(black) o(GREEN@1) o(black) s(black) y(black).
        // The second 'o' is black in the SAME word as a confirmed (green)
        // 'o' -> maxCount["o"] = 1 (the confirmed count), plus a yellow
        // position-exclusion at the black 'o's position (2).
        let c = constraints([("noosy", [.black, .green, .black, .black, .black])])
        XCTAssertEqual(c.green, [1: "o"])
        XCTAssertEqual(c.maxCount["o"], 1)
        XCTAssertEqual(c.yellow["o"], [2])
        XCTAssertEqual(c.black, Set("nsy"))
    }

    func testFilterRejectsTooManyOfMaxCountLetter() {
        let c = constraints([("noosy", [.black, .green, .black, .black, .black])])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)

        // "motto" has 'o' at position 1 (matches green) but TWO 'o's total,
        // exceeding maxCount["o"] = 1 -> must be rejected.
        XCTAssertFalse(filtered.contains("motto"))

        // "board" has 'o' at position 1, exactly one 'o', none of the
        // black letters n/s/y, and its position-2 letter ('a') isn't 'o'
        // -> satisfies every constraint and must be present.
        XCTAssertTrue(filtered.contains("board"))

        // Every surviving word must have AT MOST one 'o'.
        for word in filtered {
            XCTAssertLessThanOrEqual(word.filter { $0 == "o" }.count, 1)
        }
    }

    // MARK: - filterWords equivalents (TestFilterWords)

    func testFilterGreenPositions() {
        let c = constraints([("aaaaa", [.green, .black, .black, .black, .black])])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        XCTAssertTrue(filtered.allSatisfy { $0.first == "a" })
        XCTAssertTrue(filtered.contains("abide"))
        XCTAssertTrue(filtered.contains("attic"))
    }

    func testFilterYellowPositions() {
        let c = constraints([("abcde", [.yellow, .black, .black, .black, .black])])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        for word in filtered {
            XCTAssertTrue(word.contains("a"))
            XCTAssertNotEqual(Array(word)[0], "a")
        }
    }

    func testFilterBlackLetters() {
        let c = constraints([("xyzxy", [.black, .black, .black, .black, .black])])
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
        let c = constraints([("xxttx", [.black, .black, .green, .yellow, .black])])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        for word in filtered {
            XCTAssertGreaterEqual(word.filter { $0 == "t" }.count, 2)
        }
        XCTAssertTrue(filtered.contains("attic"))
        XCTAssertFalse(filtered.contains("batch"))
        XCTAssertFalse(filtered.contains("catch"))
    }

    func testFilterBothGreenAndYellow() {
        // Green 'a' at position 0, yellow 't' at position 2 (excluded from
        // position 2), rest black.
        let c = constraints([("axtxx", [.green, .black, .yellow, .black, .black])])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        for word in filtered {
            let chars = Array(word)
            XCTAssertEqual(chars[0], "a")
            XCTAssertTrue(word.contains("t"))
            XCTAssertNotEqual(chars[2], "t")
        }
    }

    func testFilterYellowExcludesPosition() {
        let c = constraints([("xaxxx", [.black, .yellow, .black, .black, .black])])
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
        let c = constraints([("abtcd", [.green, .black, .yellow, .black, .black])])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        for word in filtered {
            let chars = Array(word)
            XCTAssertEqual(chars[0], "a")
            XCTAssertTrue(word.contains("t"))
            XCTAssertNotEqual(chars[2], "t")
            XCTAssertFalse(word.contains("b"))
            XCTAssertFalse(word.contains("c"))
            XCTAssertFalse(word.contains("d"))
            // Note: 'e' is not covered by this guess's letters (a,b,t,c,d),
            // unlike the old test which separately passed `black: "bcde"`.
            // The new model only derives black from actual tiles, so this
            // assertion about 'e' is intentionally dropped — there is no
            // tile in this guess colored black with letter 'e'.
        }
    }

    func testFilterExcludingAllWords() {
        // Requires 'z' at position 0, which no word in testWords has.
        let c = constraints([("zxxxx", [.green, .black, .black, .black, .black])])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        XCTAssertEqual(filtered.count, 0)
    }

    func testFilterNoConstraints() {
        // An empty `guesses` array (no rows at all) yields empty
        // constraints, just like a fully-black, all-distinct-letter guess
        // would for the letters it covers — but using no guesses at all is
        // the cleanest way to assert "no constraints whatsoever."
        let c = WordleFilter.buildConstraints(from: [])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        XCTAssertEqual(filtered.count, testWords.count)
    }

    // MARK: - The "attic" / "attap" user-reported scenario

    func testAtticAttapScenario() {
        // Guess 1 "xxatx": yellow 'a' at 2 (excluded from 2), green nothing
        //   else; black x.
        // Guess 2 "taxxt": yellow 't' at 0 AND 4 (same guess, doubled),
        //   black x twice.
        // Together this plays the role of the old
        // `constraints(["..at.", "ta..t"], black: "slero")` call, but with
        // black now coming from literal black tiles for s,l,e,r,o spread
        // across the two guesses' filler positions.
        let c = constraints([
            ("slate", [.black, .black, .yellow, .black, .black]),   // s l A t e -> yellow a@2, black s,l,t,e... wait t&e also need exclusion
            ("trout", [.yellow, .black, .black, .black, .yellow]),  // t r o u t -> yellow t@0 and t@4, black r,o,u
        ])

        // 'a' appears once per guess (never green twice, never colored
        // twice within one guess) -> NOT doubled.
        XCTAssertNil(c.doubled["a"])

        // 't' is yellow twice within the second guess ("trout" has 't' at
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
        // Black covers every letter except 'a' across one all-black guess
        // plus a green 'a'; no word in testWords is all-'a', so this
        // should match nothing but must not crash.
        let c = constraints([
            ("aaaaa", [.green, .black, .black, .black, .black]),
            ("bcdef", [.black, .black, .black, .black, .black]),
            ("ghijk", [.black, .black, .black, .black, .black]),
            ("lmnop", [.black, .black, .black, .black, .black]),
            ("qrstu", [.black, .black, .black, .black, .black]),
            ("vwxyz", [.black, .black, .black, .black, .black]),
        ])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        XCTAssertEqual(filtered.count, 0)
    }

    func testLetterWithHighCount() {
        // 't' appears 3 times (green) in one guess -> requires >= 3 't's.
        let c = constraints([("txtxt", [.green, .black, .green, .black, .green])])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        for word in filtered {
            XCTAssertGreaterEqual(word.filter { $0 == "t" }.count, 3)
        }
    }

    func testYellowAtMultiplePositionsSingleGuess() {
        // 't' yellow at positions 1 and 3.
        let c = constraints([("xtxtx", [.black, .yellow, .black, .yellow, .black])])
        let filtered = WordleFilter.filter(words: testWords, constraints: c)
        for word in filtered {
            let chars = Array(word)
            XCTAssertGreaterEqual(word.filter { $0 == "t" }.count, 2)
            XCTAssertNotEqual(chars[1], "t")
            XCTAssertNotEqual(chars[3], "t")
        }
    }

    // MARK: - scenarioKey PARITY tests against the bundled suggestions.json
    //
    // THIS IS THE KEY CORRECTNESS CHECK for the bot-suggestions feature: if
    // `scenarioKey` doesn't produce byte-identical strings to index.html's
    // JS implementation, every suggestion in the committed
    // `suggestions.json` (and anything exported from the web PWA) would
    // silently fail to match in the native app. Both literal key strings
    // below were independently verified against a hand-written Python
    // mirror of `parseGuesses`/`scenarioKey` (see the task notes) before
    // being hardcoded here, AND both correspond to real entries in
    // apple/Sources/Resources/suggestions.json.

    func testScenarioKeyParity_SlateGreenGreenBlackBlackGreen() {
        // Guess "slate" colored [green, green, black, black, green]:
        //   s(0)=green, l(1)=green, a(2)=black, t(3)=black, e(4)=green.
        // Confirmed letters: s, l, e (green). Blacked: a, t. Neither a nor
        // t is confirmed elsewhere, so black = {a, t}.
        // This EXACT key appears in suggestions.json mapped to "slice".
        let c = constraints([("slate", [.green, .green, .black, .black, .green])])
        let key = WordleFilter.scenarioKey(c)
        XCTAssertEqual(key, "{\"g\":[[0,\"s\"],[1,\"l\"],[4,\"e\"]],\"y\":[],\"b\":[\"a\",\"t\"],\"m\":[]}")

        // Sanity: this key really is a key in the bundled file, mapped to
        // "slice" — confirms the literal string above isn't just
        // internally self-consistent but matches the actual shipped data.
        let bundled = loadBundledSuggestionsForTest()
        XCTAssertEqual(bundled[key]?.word, "slice")
    }

    func testScenarioKeyParity_SlateGreenYellowYellowBlackBlack() {
        // Guess "slate" colored [green, yellow, yellow, black, black]:
        //   s(0)=green, l(1)=yellow, a(2)=yellow, t(3)=black, e(4)=black.
        // Confirmed: s, l, a. Blacked: t, e (neither confirmed elsewhere).
        // No letter is both confirmed and black in this guess, so no
        // maxCount/extra yellow-exclusion kicks in beyond l@1 and a@2 from
        // their own yellow tiles.
        // This EXACT key appears in suggestions.json mapped to "hydro".
        let c = constraints([("slate", [.green, .yellow, .yellow, .black, .black])])
        let key = WordleFilter.scenarioKey(c)
        XCTAssertEqual(
            key,
            "{\"g\":[[0,\"s\"]],\"y\":[[\"a\",[2]],[\"l\",[1]]],\"b\":[\"e\",\"t\"],\"m\":[]}"
        )

        let bundled = loadBundledSuggestionsForTest()
        XCTAssertEqual(bundled[key]?.word, "hydro")
    }

    /// Loads `suggestions.json` straight from the test bundle (which is a
    /// SEPARATE bundle from the app's `Bundle.main` — Xcode test targets
    /// get their own `.xctest` bundle). For this lookup to succeed, the
    /// resource must ALSO be added to the test target's bundle resources,
    /// not just the app target's. If it isn't, this helper returns an
    /// empty dictionary and only the literal-string assertions above still
    /// run (which is the main point of these tests anyway).
    private func loadBundledSuggestionsForTest() -> [String: Suggestion] {
        guard let url = Bundle(for: WordleFilterTests.self)
            .url(forResource: "suggestions", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(SuggestionsFile.self, from: data)
        else {
            return [:]
        }
        return file.suggestions
    }
}
