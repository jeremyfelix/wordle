//
//  WordListBarView.swift
//  WordleSolver
//
//  Mirrors index.html's `.list-bar`: shows the active word-list status
//  ("12,972 words" or "Custom list · 340 words") plus three controls:
//  "Reset list" (only visible when a custom list is active), "Import" (pick
//  a .txt file to replace the dictionary), and "Save" (export the active
//  list, minus hidden words, as a .txt file).
//

import SwiftUI
import UniformTypeIdentifiers

struct WordListBarView: View {
    @EnvironmentObject var store: GameStore

    // Drives the `.fileImporter`/`.fileExporter` sheets. SwiftUI's file
    // pickers are presented via a boolean (or optional-item) binding rather
    // than being pushed imperatively, so each picker gets its own @State
    // flag here.
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var exportDocument = PlainTextDocument(text: "")

    // Alerts (mirrors index.html's `alert(...)` / `confirm(...)` calls,
    // which don't exist natively in SwiftUI — `.alert` is the equivalent).
    @State private var showResetConfirm = false
    @State private var showImportEmptyAlert = false
    @State private var showImportErrorAlert = false

    var body: some View {
        HStack(spacing: 10) {
            Text(store.listStatusText)
                .font(.system(size: 13))
                .foregroundColor(.wordleMuted)

            Spacer()

            if store.usingCustom {
                barButton("Reset list") {
                    showResetConfirm = true
                }
            }

            barButton("Import") {
                showImporter = true
            }

            barButton("Save") {
                // index.html exports `active.join('\n') + '\n'`.
                let text = store.activeWordsForExport().joined(separator: "\n") + "\n"
                exportDocument = PlainTextDocument(text: text)
                showExporter = true
            }
        }
        .padding(.vertical, 4)

        // "Reset list" confirmation — matches index.html's confirm() text.
        .alert("Reset to the default word list?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                store.resetToDefaultList()
            }
        } message: {
            Text("This clears hidden words and the custom list.")
        }

        // Import (.txt -> importWordList).
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.plainText, .text]) { result in
            switch result {
            case .success(let url):
                importWords(from: url)
            case .failure:
                showImportErrorAlert = true
            }
        }
        .alert("No words found in the selected file.", isPresented: $showImportEmptyAlert) {
            Button("OK", role: .cancel) {}
        }
        .alert("Could not read that file.", isPresented: $showImportErrorAlert) {
            Button("OK", role: .cancel) {}
        }

        // Save (.txt export of the active dictionary).
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .plainText,
            defaultFilename: "words"
        ) { _ in
            // Nothing to do on success/failure — index.html doesn't show a
            // confirmation for this export either.
        }
    }

    /// Small reusable "outline" style button to match the rest of the app's
    /// secondary-action buttons (Add Guess / Clear / etc).
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

    /// Reads the picked file's contents and hands them to the store.
    /// `startAccessingSecurityScopedResource`/`stopAccessingSecurityScopedResource`
    /// is required on iOS to read a URL handed back by a file picker that
    /// points outside the app's sandbox (harmless no-op on macOS for
    /// locations the app already has access to).
    private func importWords(from url: URL) {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
        }

        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            showImportErrorAlert = true
            return
        }

        let words = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if words.isEmpty {
            showImportEmptyAlert = true
            return
        }

        store.importWordList(text)
    }
}

#Preview {
    WordListBarView()
        .padding()
        .background(Color.wordleBackground)
        .environmentObject(GameStore())
}
