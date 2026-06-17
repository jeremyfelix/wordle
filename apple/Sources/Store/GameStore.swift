//
//  GameStore.swift
//  WordleSolver
//
//  The single source of truth for app state: the list of guess rows, the
//  active word list (bundled or custom), hidden/removed words, bot
//  suggestions, and the currently-matching candidate words. This is an
//  `ObservableObject` so SwiftUI views can subscribe to it and automatically
//  redraw whenever something changes (beginner note: this is the standard
//  "ViewModel" piece of the MVVM pattern used throughout SwiftUI apps).
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
//  This file mirrors FOUR pieces of index.html state:
//    1. guesses                      (STORAGE_KEY     = 'wordle-guesses')
//    2. customWords / removed        (CUSTOM_KEY / REMOVED_KEY)
//    3. suggestions                  (SUGGESTIONS_KEY = 'wordle-suggestions')
//    4. a combined "backup" of all three, for easy migration between app
//       versions/devices (a feature index.html doesn't have, added here
//       because UserDefaults resets are rarer but exporting everything at
//       once is still useful when moving to a new device).
//

import Foundation
import Combine

@MainActor
final class GameStore: ObservableObject {

    // MARK: - Guesses

    /// All guess rows currently shown in the UI.
    @Published var guesses: [Guess] {
        didSet {
            recompute()
            persistGuesses()
        }
    }

    /// The words from the active dictionary (bundled or custom), minus
    /// hidden/removed words, still consistent with all current guesses.
    /// Recomputed automatically whenever `guesses`, `customWords`, or
    /// `removed` changes — never persisted itself, since it's derived.
    @Published private(set) var candidates: [String] = []

    // MARK: - Word list (Feature 1)

    /// The bundled default dictionary, loaded once at startup from
    /// words.txt. Never mutated after init.
    private let bundledWords: [String]

    /// A user-imported word list. `nil` means "using the bundled default
    /// list" (mirrors index.html's `USING_CUSTOM` / `CUSTOM_KEY`).
    @Published private(set) var customWords: [String]? {
        didSet {
            recompute()
            persistWordList()
        }
    }

    /// Words hidden from results via the "Remove" button (mirrors
    /// index.html's `REMOVED` Set). Lowercased.
    @Published private(set) var removed: Set<String> {
        didSet {
            recompute()
            persistWordList()
        }
    }

    /// True when a custom (imported) word list is active, false when using
    /// the bundled default. Mirrors index.html's `USING_CUSTOM`.
    var usingCustom: Bool { customWords != nil }

    /// The dictionary currently in effect: the custom list if one has been
    /// imported, otherwise the bundled default.
    private var activeDictionary: [String] { customWords ?? bundledWords }

    /// Word count shown in the word-list bar, e.g. "Custom list · 1,234
    /// words" or "12,972 words" — mirrors index.html's `updateListStatus`.
    var listStatusText: String {
        let count = activeDictionary.filter { !removed.contains($0) }.count
        let formatted = GameStore.thousands(count)
        return usingCustom ? "Custom list · \(formatted) words" : "\(formatted) words"
    }

    /// Number of words currently hidden — drives the "hidden bar" UI.
    var hiddenCount: Int { removed.count }

    /// Formats an integer with thousands separators, e.g. 12972 -> "12,972"
    /// (mirrors JavaScript's `Number.prototype.toLocaleString()`).
    private static func thousands(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? String(n)
    }

    /// Parses pasted/imported text into a word list: trim, lowercase, drop
    /// empty lines. Mirrors index.html's import-file handler. If the result
    /// is empty, this method does nothing (the caller — the import UI — is
    /// responsible for showing an alert, matching index.html's `alert('No
    /// words found...')`).
    func importWordList(_ text: String) {
        let words = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return }

        customWords = words
        removed = []
    }

    /// Resets to the bundled default list, clearing both the custom list
    /// and hidden words (mirrors index.html's "Reset list" button, which
    /// clears CUSTOM_KEY and REMOVED_KEY together).
    func resetToDefaultList() {
        customWords = nil
        removed = []
    }

    /// Hides the given words from future results (mirrors index.html's
    /// "Remove (N)" button). Words are lowercased before storing, since
    /// `removed` is compared against the (already-lowercase) dictionary.
    func hideWords(_ words: Set<String>) {
        for word in words {
            removed.insert(word.lowercased())
        }
    }

    /// Clears all hidden words (mirrors index.html's "Reset hidden" button).
    func resetHidden() {
        removed = []
    }

    /// The active dictionary minus hidden words, sorted — used for the
    /// "Save" (export) button. Mirrors index.html's
    /// `WORDS.filter(w => !REMOVED.has(w))`.
    func activeWordsForExport() -> [String] {
        activeDictionary.filter { !removed.contains($0) }.sorted()
    }

    // MARK: - Suggestions (Feature 2)

    /// All saved bot suggestions, keyed by `WordleFilter.scenarioKey`.
    /// Mirrors index.html's `SUGGESTIONS` object.
    @Published private(set) var suggestions: [String: Suggestion] {
        didSet {
            persistSuggestions()
        }
    }

    /// The constraints for the current set of guesses, recomputed whenever
    /// `guesses` changes (see `recompute()`). `nil` when no guess row is
    /// fully filled in yet — index.html only computes/shows a scenario
    /// after a "Filter Words" click; this app filters live, so the
    /// equivalent condition is "at least one complete 5-letter row exists."
    @Published private(set) var currentConstraints: Constraints?

    /// `true` once at least one guess row has all 5 letters filled in —
    /// this is what controls whether the bot card is shown at all,
    /// mirroring index.html's `showBotCard`'s `if (!LAST_CONSTRAINTS)` guard.
    var hasScenario: Bool { currentConstraints != nil }

    /// The scenario key for the current guesses, or `nil` if there's no
    /// complete guess row yet.
    var currentScenarioKey: String? {
        guard let constraints = currentConstraints else { return nil }
        return WordleFilter.scenarioKey(constraints)
    }

    /// Number of candidates remaining for the current scenario (mirrors
    /// index.html's `LAST_REMAINING`).
    var currentRemaining: Int { candidates.count }

    /// The bot's suggestion for the current scenario, if one has been
    /// recorded.
    var currentSuggestion: Suggestion? {
        guard let key = currentScenarioKey else { return nil }
        return suggestions[key]
    }

    /// Total number of saved suggestions, for the "Saved suggestions (N)"
    /// disclosure title.
    var suggestionsCount: Int { suggestions.count }

    /// Records (saves or overwrites) a suggestion for the CURRENT scenario.
    /// Mirrors index.html's `saveSuggestion`. No-ops if there's no current
    /// scenario or the word isn't exactly 5 letters (the UI is expected to
    /// validate before calling this, but we guard defensively too).
    func recordSuggestion(word: String, note: String) {
        guard let key = currentScenarioKey else { return }
        let cleanedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard cleanedWord.count == 5 else { return }

        suggestions[key] = Suggestion(
            word: cleanedWord,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            remaining: currentRemaining,
            saved: GameStore.todayISO()
        )
    }

    /// Deletes the suggestion for an arbitrary key (used by the saved-
    /// suggestions list, where the row may not be the current scenario).
    func deleteSuggestion(key: String) {
        suggestions.removeValue(forKey: key)
    }

    /// Deletes the suggestion for the CURRENT scenario, if any (used by the
    /// bot card's "Delete" button).
    func deleteCurrentSuggestion() {
        guard let key = currentScenarioKey else { return }
        deleteSuggestion(key: key)
    }

    /// Drops all local edits and reloads only the bundled defaults
    /// (mirrors index.html's "Reset to defaults" button).
    func resetSuggestionsToDefaults() {
        suggestions = GameStore.loadBundledSuggestions()
    }

    /// Mirrors index.html's bot-word-display click handler: fills the
    /// suggested word into the first completely-empty guess row, or appends
    /// a new row if none is empty. Letters are stored lowercase; the new/
    /// filled row's colors are reset to all-black (a freshly typed guess is
    /// unconfirmed, same as `createRow`'s default).
    func insertSuggestedWordIntoGuess(_ word: String) {
        let letters: [Character?] = word.lowercased().map { $0 }
        guard letters.count == 5 else { return }

        if let emptyIndex = guesses.firstIndex(where: { $0.isEmpty }) {
            guesses[emptyIndex].letters = letters
            guesses[emptyIndex].colors = Array(repeating: .black, count: 5)
        } else {
            guesses.append(Guess(letters: letters, colors: Array(repeating: .black, count: 5)))
        }
    }

    /// True if some guess row already contains exactly this word — used to
    /// disable/dim the bot word so it can't be inserted twice in a row,
    /// mirroring index.html's `.used` class check.
    func isWordAlreadyUsed(_ word: String) -> Bool {
        let target = word.lowercased()
        return guesses.contains { guess in
            String(guess.letters.compactMap { $0 }).lowercased() == target
        }
    }

    // MARK: - Import / export (Feature 3)

    /// Decodes an exported suggestions.json payload and merges it OVER the
    /// current suggestions (imported wins per key — it's the authoritative
    /// export, matching index.html's `{ ...SUGGESTIONS, ...data.suggestions
    /// }`). Returns the number of suggestions in the imported file. Throws
    /// if the data isn't a valid `SuggestionsFile`.
    @discardableResult
    func importSuggestions(jsonData: Data) throws -> Int {
        let file = try JSONDecoder().decode(SuggestionsFile.self, from: jsonData)
        suggestions = suggestions.merging(file.suggestions) { _, imported in imported }
        return file.suggestions.count
    }

    /// Encodes the current suggestions as pretty JSON, for the "Export"
    /// button. Mirrors index.html's `{ version: 1, suggestions: SUGGESTIONS
    /// }`.
    func suggestionsExportData() -> Data {
        let file = SuggestionsFile(version: 1, suggestions: suggestions)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(file)) ?? Data()
    }

    // MARK: - Combined backup (Feature 3)

    /// Everything needed to fully restore app state on another device/after
    /// reinstalling — guesses, word list customization, and suggestions all
    /// in one file. This is the "all in one" backup the web PWA doesn't
    /// have (there, each piece is exported separately).
    struct BackupFile: Codable {
        var version: Int
        var guesses: [Guess]
        var customWords: [String]?
        var removed: [String]
        var suggestions: [String: Suggestion]
    }

    /// Builds and encodes a full backup of guesses + word list + hidden
    /// words + suggestions, as pretty JSON.
    func backupExportData() -> Data {
        let file = BackupFile(
            version: 1,
            guesses: guesses,
            customWords: customWords,
            removed: Array(removed).sorted(),
            suggestions: suggestions
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(file)) ?? Data()
    }

    /// Restores ALL state from a previously-exported backup file, then
    /// recomputes candidates. Throws if the data isn't a valid
    /// `BackupFile`.
    func importBackup(jsonData: Data) throws {
        let file = try JSONDecoder().decode(BackupFile.self, from: jsonData)
        guesses = file.guesses.isEmpty ? [Guess()] : file.guesses
        customWords = file.customWords
        removed = Set(file.removed)
        suggestions = file.suggestions
        // `guesses`'s didSet already calls recompute(), but customWords/
        // removed's didSet calls it again too — redundant but harmless,
        // and guarantees `candidates` reflects every piece we just changed
        // regardless of property-observer ordering above.
        recompute()
    }

    // MARK: - Guess row editing

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
    /// app's "Clear" button. (Note: index.html's "Clear" only clears
    /// guesses, not the word list or suggestions — same here.)
    func reset() {
        guesses = [Guess()]
    }

    // MARK: - Init

    private static let guessesStorageKey = "wordle.gamestate.v1"
    private static let wordListStorageKey = "wordle.wordlist.v1"
    private static let suggestionsStorageKey = "wordle.suggestions.v1"

    /// What gets encoded to JSON for the guesses persistence key.
    private struct GuessesState: Codable {
        var guesses: [Guess]
    }

    /// What gets encoded to JSON for the word-list persistence key.
    private struct WordListState: Codable {
        var customWords: [String]?
        var removed: [String]
    }

    init() {
        // Load the bundled dictionary first; this doesn't depend on any
        // persisted state.
        self.bundledWords = WordList.load()

        // Restore guesses, or start with a single empty row (matches the
        // web app's `loadState()` fallback of `addRow()`).
        if let saved = GameStore.loadGuesses() {
            self.guesses = saved.guesses.isEmpty ? [Guess()] : saved.guesses
        } else {
            self.guesses = [Guess()]
        }

        // Restore word-list customization.
        if let saved = GameStore.loadWordList() {
            self.customWords = saved.customWords
            self.removed = Set(saved.removed)
        } else {
            self.customWords = nil
            self.removed = []
        }

        // Restore suggestions, merging bundled defaults underneath any
        // locally-saved edits (mirrors index.html's `initSuggestions`:
        // local storage is read first, then the bundled/fetched file is
        // merged in as the base with local values winning per key).
        let bundled = GameStore.loadBundledSuggestions()
        let local = GameStore.loadLocalSuggestions() ?? [:]
        self.suggestions = bundled.merging(local) { _, localValue in localValue }

        // `didSet` does not fire for a property's own initial assignment
        // inside `init`, so we compute candidates/currentConstraints once
        // explicitly here to make sure the UI has correct data as soon as
        // the store exists.
        recompute()

        // Persist the merged suggestions immediately, mirroring
        // index.html's `localStorage.setItem(SUGGESTIONS_KEY, ...)` right
        // after the merge in `initSuggestions`.
        persistSuggestions()
    }

    // MARK: - Recompute

    /// Recomputes `currentConstraints` and `candidates` from the current
    /// guesses + active word list (bundled or custom) + hidden words.
    ///
    /// `currentConstraints` is `nil` whenever no guess row is completely
    /// filled in (5/5 letters) — see `WordleFilter.buildConstraints`, which
    /// skips incomplete rows entirely when building constraints, and the
    /// doc comment on `hasScenario` above for why that's the right "is
    /// there a scenario yet" signal for this app's live-filtering UI.
    private func recompute() {
        let hasCompleteRow = guesses.contains { guess in
            (0..<5).allSatisfy { guess.letter(at: $0) != nil }
        }

        let constraints = WordleFilter.buildConstraints(from: guesses)
        currentConstraints = hasCompleteRow ? constraints : nil

        let available = activeDictionary.filter { !removed.contains($0) }
        candidates = WordleFilter.filter(words: available, constraints: constraints)
    }

    // MARK: - Persistence: guesses

    private func persistGuesses() {
        let state = GuessesState(guesses: guesses)
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: GameStore.guessesStorageKey)
    }

    private static func loadGuesses() -> GuessesState? {
        guard let data = UserDefaults.standard.data(forKey: guessesStorageKey) else { return nil }
        return try? JSONDecoder().decode(GuessesState.self, from: data)
    }

    // MARK: - Persistence: word list

    private func persistWordList() {
        let state = WordListState(customWords: customWords, removed: Array(removed).sorted())
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: GameStore.wordListStorageKey)
    }

    private static func loadWordList() -> WordListState? {
        guard let data = UserDefaults.standard.data(forKey: wordListStorageKey) else { return nil }
        return try? JSONDecoder().decode(WordListState.self, from: data)
    }

    // MARK: - Persistence: suggestions

    private func persistSuggestions() {
        guard let data = try? JSONEncoder().encode(suggestions) else { return }
        UserDefaults.standard.set(data, forKey: GameStore.suggestionsStorageKey)
    }

    /// Locally-saved suggestion edits only (no bundled defaults) — the
    /// Swift analogue of index.html reading `localStorage[SUGGESTIONS_KEY]`
    /// at the top of `initSuggestions`.
    private static func loadLocalSuggestions() -> [String: Suggestion]? {
        guard let data = UserDefaults.standard.data(forKey: suggestionsStorageKey) else { return nil }
        return try? JSONDecoder().decode([String: Suggestion].self, from: data)
    }

    /// Loads the committed `suggestions.json` from the app bundle. Returns
    /// an empty dictionary (not a crash) if the resource is missing or
    /// malformed — same "fail soft" philosophy as `WordList.load()`.
    private static func loadBundledSuggestions() -> [String: Suggestion] {
        guard let url = Bundle.main.url(forResource: "suggestions", withExtension: "json") else {
            #if DEBUG
            print("GameStore: could not find suggestions.json in Bundle.main. " +
                  "Did you add it to the app target's 'Copy Bundle Resources' build phase?")
            #endif
            return [:]
        }
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(SuggestionsFile.self, from: data) else {
            #if DEBUG
            print("GameStore: found suggestions.json at \(url) but could not decode it.")
            #endif
            return [:]
        }
        return file.suggestions
    }

    /// Today's date as "yyyy-MM-dd", matching index.html's
    /// `new Date().toISOString().slice(0, 10)`.
    private static func todayISO() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}
