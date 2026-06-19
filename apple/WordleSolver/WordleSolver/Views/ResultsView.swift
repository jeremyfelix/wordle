//
//  ResultsView.swift
//  WordleSolver
//
//  Shows the bot card, the results bar (count + Select All + Remove), the
//  hidden-words bar, and the grid of remaining candidate words — mirroring
//  index.html's `#results` / `.results-bar` / `#hidden-bar` / `#bot-card` /
//  `.word-grid` / `.word-chip` all together, since in index.html they're
//  all inside the same `#results` container.
//
//  Word chips are tappable to select/deselect (matching `.word-chip` +
//  `.selected` in index.html); selected chips can be hidden via "Remove
//  (N)", which excludes them from all future results.
//

import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var store: GameStore

    /// Currently selected (highlighted) words in the grid, by lowercase
    /// word. Local UI state — selection is never persisted, matching
    /// index.html (refreshing the page clears `.selected` classes too).
    @State private var selected: Set<String> = []

    @State private var showRemoveConfirm = false

    /// Adaptive grid columns, similar to the CSS
    /// `grid-template-columns: repeat(auto-fill, minmax(82px, 1fr))`.
    private let columns = [GridItem(.adaptive(minimum: 82), spacing: 8)]

    private var candidates: [String] { store.candidates }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            resultsBar

            if store.hiddenCount > 0 {
                hiddenBar
            }

            BotCardView()

            if candidates.isEmpty {
                Text("No words match these constraints yet.")
                    .font(.system(size: 13))
                    .foregroundColor(.wordleMuted)
                    .padding(.vertical, 12)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(candidates, id: \.self) { word in
                        wordChip(word)
                    }
                }
            }
        }
        // Selection doesn't carry over once the candidate set itself
        // changes (e.g. a new letter typed) — matches index.html, which
        // rebuilds `.word-chip` elements from scratch on every filter.
        .onChange(of: candidates) { _, _ in
            selected = []
        }
    }

    // MARK: - Results bar

    private var resultsBar: some View {
        HStack(spacing: 10) {
            Text("\(candidates.count) word\(candidates.count == 1 ? "" : "s") found")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.wordleText)

            Spacer()

            barButton(allSelected ? "Deselect All" : "Select All") {
                if allSelected {
                    selected = []
                } else {
                    selected = Set(candidates)
                }
            }

            Button(action: { showRemoveConfirm = true }) {
                Text("Remove (\(selected.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selected.isEmpty ? Color.wordleMuted.opacity(0.4) : Color.red.opacity(0.8))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty)
        }
        .padding(.vertical, 6)
        .alert(
            "Hide \(selected.count) word\(selected.count == 1 ? "" : "s")?",
            isPresented: $showRemoveConfirm
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Hide", role: .destructive) {
                store.hideWords(selected)
                selected = []
            }
        } message: {
            Text("They'll be excluded from future filter results.")
        }
    }

    private var allSelected: Bool {
        !candidates.isEmpty && selected.count == candidates.count
    }

    // MARK: - Hidden bar

    private var hiddenBar: some View {
        HStack {
            Text("\(store.hiddenCount) word\(store.hiddenCount == 1 ? "" : "s") hidden")
                .font(.system(size: 13))
                .foregroundColor(.wordleMuted)
            Spacer()
            barButton("Reset hidden") {
                store.resetHidden()
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Word chip

    private func wordChip(_ word: String) -> some View {
        let isSelected = selected.contains(word)
        return Text(word.uppercased())
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.wordleText)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.wordleGreen.opacity(0.35) : Color.wordleSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.wordleGreen : Color.wordleBorder, lineWidth: 2)
            )
            .cornerRadius(6)
            .onTapGesture {
                if isSelected {
                    selected.remove(word)
                } else {
                    selected.insert(word)
                }
            }
    }

    // MARK: - Shared small button style

    private func barButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.wordleText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
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

#Preview {
    ScrollView {
        ResultsView()
            .padding()
    }
    .background(Color.wordleBackground)
    .environmentObject(GameStore())
}
