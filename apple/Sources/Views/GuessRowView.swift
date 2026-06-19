//
//  GuessRowView.swift
//  WordleSolver
//
//  One row in the guess list: 5 tiles + a delete button + a text field used
//  to type the 5-letter word for that row, mirroring index.html's
//  `.guess-row` (tiles + `.word-input`).
//
//  Design note: this view keeps its own `@State private var localGuess`
//  copy of the `Guess` it was given, and calls `onUpdate` every time it
//  changes something. This "local state + callback" pattern is simpler and
//  safer here than threading a `Binding<Guess>` all the way from the store's
//  array, because rows can be deleted while others are being edited — using
//  a stable `id`-based callback (`onDelete`) avoids any index-out-of-range
//  issues that array-index bindings could hit mid-edit.
//

import SwiftUI

struct GuessRowView: View {
    /// Called whenever this row's letters or colors change, with the
    /// updated `Guess` to save back into the store.
    var onUpdate: (Guess) -> Void
    /// Called when the user taps the "x" delete button for this row.
    var onDelete: () -> Void

    @State private var localGuess: Guess

    /// What the text field shows: the row's letters joined into a single
    /// uppercase string (matches index.html's `.word-input` which always
    /// displays uppercase via `text-transform: uppercase` + its own
    /// uppercasing in JS).
    @State private var wordText: String

    init(guess: Guess, onUpdate: @escaping (Guess) -> Void, onDelete: @escaping () -> Void) {
        self._localGuess = State(initialValue: guess)
        self._wordText = State(initialValue: GuessRowView.text(for: guess))
        self.onUpdate = onUpdate
        self.onDelete = onDelete
    }

    private static func text(for guess: Guess) -> String {
        String(guess.letters.compactMap { $0 }).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { position in
                        TileView(
                            letter: localGuess.letter(at: position),
                            color: localGuess.color(at: position),
                            onTap: { cycleColor(at: position) }
                        )
                    }
                }

                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .foregroundColor(.wordleMuted)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove guess")
            }

            TextField("Type guess word…", text: $wordText)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.wordleText)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.wordleSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.wordleBorder, lineWidth: 1)
                )
                .cornerRadius(6)
                #if os(iOS)
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)
                #endif
                .onChange(of: wordText) { _, newValue in
                    applyTypedWord(newValue)
                }
        }
    }

    /// Cycles the color of a single filled tile (black -> yellow -> green ->
    /// black), then reports the change upward. Matches `onTileClick` in
    /// index.html.
    private func cycleColor(at position: Int) {
        guard localGuess.letter(at: position) != nil else { return }
        localGuess.colors[position] = localGuess.colors[position].next
        onUpdate(localGuess)
    }

    /// Parses the free-typed text back into up to 5 letters, matching
    /// index.html's `syncInputToTiles`:
    ///   - strip non-letters, uppercase, clamp to 5 characters.
    ///   - if a position's letter actually CHANGED, reset that tile's color
    ///     back to black (a new letter is an unconfirmed guess again, so any
    ///     previously-set color would be stale/misleading).
    private func applyTypedWord(_ rawText: String) {
        let cleaned = String(rawText.uppercased().filter { $0.isLetter }.prefix(5))
        if cleaned != rawText {
            // Keep the visible text field in sync with the cleaned version
            // (avoids an infinite update loop since this assignment is
            // idempotent once cleaned).
            wordText = cleaned
        }

        // `cleaned` is at most 5 characters (already clamped above), so
        // converting to an array gives simple, safe indexed access.
        let cleanedChars = Array(cleaned)
        let newLetters: [Character?] = (0..<5).map { index in
            guard cleanedChars.indices.contains(index) else { return nil }
            return Character(String(cleanedChars[index]).lowercased())
        }

        for position in 0..<5 {
            let previous = localGuess.letters[position]
            let next = newLetters[position]
            localGuess.letters[position] = next
            if next != previous {
                localGuess.colors[position] = .black
            }
        }

        onUpdate(localGuess)
    }
}

#Preview {
    GuessRowView(
        guess: {
            var g = Guess()
            g.letters = ["c", "r", "a", "n", "e"]
            g.colors = [.black, .green, .yellow, .black, .black]
            return g
        }(),
        onUpdate: { _ in },
        onDelete: {}
    )
    .padding()
    .background(Color.wordleBackground)
}
