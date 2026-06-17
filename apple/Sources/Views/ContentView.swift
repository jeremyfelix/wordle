//
//  ContentView.swift
//  WordleSolver
//
//  The main (and only) screen: header, scrollable list of guess rows, an
//  "Add Guess" button, a black-letters field, and the results list.
//  Mirrors the single-page layout of index.html (<header> + <main>).
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        ZStack {
            Color.wordleBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    guessRows

                    actionButtons

                    blackLettersField

                    Divider()
                        .background(Color.wordleBorder)

                    ResultsView(candidates: store.candidates)
                }
                .padding()
            }
        }
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("WORDLE SOLVER")
                .font(.system(size: 22, weight: .heavy))
                .tracking(1.5)
                .foregroundColor(.wordleText)
            Text("Tap tiles to cycle: ⬛ → 🟨 → 🟩 → ⬛")
                .font(.system(size: 13))
                .foregroundColor(.wordleMuted)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Guess rows

    private var guessRows: some View {
        // We iterate using each Guess's own `id` for stable identity (so
        // SwiftUI animates row insertion/removal correctly), and look the
        // row's data up by id rather than threading an index-based Binding
        // — see the design note at the top of GuessRowView.swift.
        VStack(spacing: 12) {
            ForEach(store.guesses) { guess in
                GuessRowView(
                    guess: guess,
                    onUpdate: { updated in store.updateGuess(updated) },
                    onDelete: { store.deleteGuess(id: guess.id) }
                )
            }
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button(action: { store.addGuess() }) {
                Text("+ Add Guess")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.wordleText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.wordleSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.wordleBorder, lineWidth: 1)
                    )
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Button(action: { store.reset() }) {
                Text("Clear")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.wordleText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.wordleSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.wordleBorder, lineWidth: 1)
                    )
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Black letters field

    private var blackLettersField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Black letters")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.wordleMuted)

            TextField("e.g. dukfiht", text: $store.blackLetters)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.wordleText)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.wordleSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.wordleBorder, lineWidth: 1)
                )
                .cornerRadius(6)
                // `.autocapitalization` only exists on iOS (UIKit-backed
                // text input). macOS's TextField has no such concept, so
                // this whole modifier must be compiled out there or the
                // multiplatform build fails.
                #if os(iOS)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                #endif
        }
    }
}

#Preview {
    // Note: in Xcode Previews, `GameStore()` loads words.txt from the
    // SAME bundle the preview runs in. Since Previews share the app
    // target's bundle, this works once words.txt has been added to
    // "Copy Bundle Resources" — see apple/README.md.
    ContentView()
        .environmentObject(GameStore())
}
