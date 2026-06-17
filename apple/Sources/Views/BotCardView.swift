//
//  BotCardView.swift
//  WordleSolver
//
//  Mirrors index.html's `#bot-card`: shown only when there is a "scenario"
//  (at least one fully-typed 5-letter guess row). It has three mutually
//  exclusive states, exactly like the web version's `#bot-view` /
//  `#bot-empty` / `#bot-form`:
//    - a recorded suggestion exists  -> show the word + note + Edit/Delete
//    - no suggestion recorded yet    -> show "+ Record"
//    - the add/edit form is open     -> word + note text fields + Save/Cancel
//

import SwiftUI

struct BotCardView: View {
    @EnvironmentObject var store: GameStore

    /// Whether the add/edit form is currently open. Local UI state — the
    /// store only knows about saved suggestions, not in-progress edits.
    @State private var isEditing = false
    @State private var wordInput = ""
    @State private var noteInput = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        // index.html only renders the card at all when LAST_CONSTRAINTS
        // exists, i.e. there's a current scenario.
        if store.hasScenario {
            VStack(alignment: .leading, spacing: 8) {
                if isEditing {
                    formRow
                } else if let suggestion = store.currentSuggestion {
                    suggestionRow(suggestion)
                } else {
                    emptyRow
                }
            }
            .padding(10)
            .background(Color.wordleSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.wordleBorder, lineWidth: 1)
            )
            .cornerRadius(8)
            // Reset the form's open/closed state whenever the scenario
            // itself changes (a different guess row became complete), so
            // we don't show a stale edit form for a different scenario.
            .onChange(of: store.currentScenarioKey) { _, _ in
                isEditing = false
            }
        }
    }

    // MARK: - "Bot suggests" row

    private func suggestionRow(_ suggestion: Suggestion) -> some View {
        let alreadyUsed = store.isWordAlreadyUsed(suggestion.word)

        return HStack(spacing: 10) {
            Text("Bot suggests")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.wordleMuted)

            Button(action: {
                guard !alreadyUsed else { return }
                store.insertSuggestedWordIntoGuess(suggestion.word)
            }) {
                Text(suggestion.word.uppercased())
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(alreadyUsed ? .wordleMuted : .wordleGreen)
                    .strikethrough(alreadyUsed)
            }
            .buttonStyle(.plain)
            .disabled(alreadyUsed)

            if !suggestion.note.isEmpty {
                Text(suggestion.note)
                    .font(.system(size: 12))
                    .foregroundColor(.wordleMuted)
                    .lineLimit(1)
            }

            Spacer()

            barButton("Edit") { openForm(prefill: suggestion) }
            barButton("Delete") { showDeleteConfirm = true }
        }
        .alert("Delete this suggestion?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteCurrentSuggestion()
            }
        }
    }

    // MARK: - "No suggestion" row

    private var emptyRow: some View {
        HStack {
            Text("No bot suggestion recorded")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.wordleMuted)
            Spacer()
            barButton("+ Record") { openForm(prefill: nil) }
        }
    }

    // MARK: - Add/edit form

    private var formRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("WORD", text: $wordInput)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.wordleText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.wordleBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.wordleBorder, lineWidth: 1)
                    )
                    .cornerRadius(6)
                    .frame(width: 100)
                    #if os(iOS)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    #endif
                    .onChange(of: wordInput) { _, newValue in
                        let cleaned = String(newValue.uppercased().filter { $0.isLetter }.prefix(5))
                        if cleaned != newValue { wordInput = cleaned }
                    }

                TextField("Note (optional)", text: $noteInput)
                    .font(.system(size: 13))
                    .foregroundColor(.wordleText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.wordleBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.wordleBorder, lineWidth: 1)
                    )
                    .cornerRadius(6)
            }

            HStack(spacing: 8) {
                barButtonPrimary("Save") {
                    guard wordInput.count == 5 else { return }
                    store.recordSuggestion(word: wordInput, note: noteInput)
                    isEditing = false
                }
                .disabled(wordInput.count != 5)

                barButton("Cancel") { isEditing = false }
            }
        }
    }

    // MARK: - Helpers

    private func openForm(prefill: Suggestion?) {
        wordInput = (prefill?.word ?? "").uppercased()
        noteInput = prefill?.note ?? ""
        isEditing = true
    }

    private func barButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.wordleText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.wordleBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.wordleBorder, lineWidth: 1)
                )
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func barButtonPrimary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.wordleText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.wordleGreen)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BotCardView()
        .padding()
        .background(Color.wordleBackground)
        .environmentObject(GameStore())
}
