//
//  WordList.swift
//  WordleSolver
//
//  Loads the dictionary of valid 5-letter words bundled with the app, ported
//  from wordle.py's:
//      with open(words_file, 'r', encoding='utf-8') as f:
//          words = [line.strip().lower() for line in f if line.strip()]
//

import Foundation

struct WordList {

    /// Loads `words.txt` from the app's bundle and returns one lowercase,
    /// trimmed word per line, skipping blank lines.
    ///
    /// IMPORTANT SETUP STEP (the #1 beginner gotcha for this project):
    /// `Bundle.main` only finds `words.txt` if the file has been added to
    /// the app target's "Copy Bundle Resources" build phase in Xcode. Just
    /// having the file inside the `Sources/Resources` folder on disk is NOT
    /// enough — Xcode has to be told to copy it into the built app. See
    /// apple/README.md section 2 for the exact steps. (We deliberately use
    /// `Bundle.main` here, NOT `Bundle.module` — `Bundle.module` is only
    /// generated for Swift Package Manager targets that declare resources
    /// in Package.swift; this project is a plain Xcode app target, so
    /// `Bundle.main` is the correct API.)
    ///
    /// If the resource can't be found or read, this returns an empty array
    /// rather than crashing, so a misconfigured bundle just shows "0 words
    /// found" instead of taking down the whole app — easier to debug than a
    /// crash on launch.
    static func load() -> [String] {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "txt") else {
            #if DEBUG
            print("WordList.load(): could not find words.txt in Bundle.main. " +
                  "Did you add it to the app target's 'Copy Bundle Resources' build phase?")
            #endif
            return []
        }

        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            #if DEBUG
            print("WordList.load(): found words.txt at \(url) but could not read it as UTF-8 text.")
            #endif
            return []
        }

        return contents
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }
}
