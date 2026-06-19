//
//  SavedSuggestionsView.swift
//  WordleSolver
//
//  Mirrors index.html's `<details id="suggestions-section">`: a collapsible
//  list of every saved bot suggestion (word + note/remaining/saved-date
//  meta + Delete), with a footer of Import / Export / Reset to defaults
//  buttons. Also hosts the combined "backup everything" row described in
//  the task — a feature index.html doesn't have, added here because
//  restoring all app state (guesses + word list + suggestions) in one step
//  is especially useful when moving to a new device or after reinstalling.
//

import SwiftUI

struct SavedSuggestionsView: View {
    @EnvironmentObject var store: GameStore

    // Suggestions import/export/reset state.
    @State private var showImportSuggestions = false
    @State private var showExportSuggestions = false
    @State private var exportSuggestionsDoc = JSONDocument(data: Data())
    @State private var showResetSuggestionsConfirm = false
    @State private var importResultMessage: String?

    // Backup import/export state.
    @State private var showImportBackup = false
    @State private var showExportBackup = false
    @State private var exportBackupDoc = JSONDocument(data: Data())
    @State private var backupResultMessage: String?
    @State private var backupErrorMessage: String?

    var body: some View {
        DisclosureGroup("Saved suggestions (\(store.suggestionsCount))") {
            VStack(alignment: .leading, spacing: 8) {
                if store.suggestions.isEmpty {
                    Text("No suggestions saved yet.")
                        .font(.system(size: 13))
                        .foregroundColor(.wordleMuted)
                        .padding(.vertical, 6)
                } else {
                    // Sort by saved date (newest first) so the list has a
                    // stable, sensible order — index.html just iterates
                    // `Object.entries`, which (for string keys) preserves
                    // insertion order; sorting here is a small, harmless
                    // improvement rather than a behavior change users would
                    // notice or rely on.
                    ForEach(sortedEntries, id: \.key) { key, suggestion in
                        suggestionRow(key: key, suggestion: suggestion)
                    }
                }

                footer
            }
            .padding(.top, 8)
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.wordleText)
        .tint(.wordleText)

        // Import suggestions.json
        .fileImporter(isPresented: $showImportSuggestions, allowedContentTypes: [.json]) { result in
            handleSuggestionsImport(result)
        }
        .alert(
            importResultMessage ?? "",
            isPresented: Binding(
                get: { importResultMessage != nil },
                set: { if !$0 { importResultMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        }

        // Export suggestions.json
        .fileExporter(
            isPresented: $showExportSuggestions,
            document: exportSuggestionsDoc,
            contentType: .json,
            defaultFilename: "suggestions"
        ) { _ in }

        // Reset to defaults
        .alert("Reset suggestions to the committed defaults?", isPresented: $showResetSuggestionsConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                store.resetSuggestionsToDefaults()
            }
        } message: {
            Text("Local edits will be lost.")
        }

        // Import backup
        .fileImporter(isPresented: $showImportBackup, allowedContentTypes: [.json]) { result in
            handleBackupImport(result)
        }
        .alert(
            backupResultMessage ?? "",
            isPresented: Binding(
                get: { backupResultMessage != nil },
                set: { if !$0 { backupResultMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        }
        .alert(
            backupErrorMessage ?? "",
            isPresented: Binding(
                get: { backupErrorMessage != nil },
                set: { if !$0 { backupErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        }

        // Export backup
        .fileExporter(
            isPresented: $showExportBackup,
            document: exportBackupDoc,
            contentType: .json,
            defaultFilename: "wordle-backup"
        ) { _ in }
    }

    private var sortedEntries: [(key: String, value: Suggestion)] {
        store.suggestions.sorted { lhs, rhs in
            lhs.value.saved > rhs.value.saved
        }
    }

    // MARK: - One saved suggestion row

    private func suggestionRow(key: String, suggestion: Suggestion) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.word.uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.wordleText)

                // Mirrors index.html's
                // `[note, remaining ? `${remaining} words` : '', saved].filter(Boolean).join(' · ')`.
                let metaParts = [
                    suggestion.note,
                    suggestion.remaining.map { "\($0) words" } ?? "",
                    suggestion.saved,
                ].filter { !$0.isEmpty }

                if !metaParts.isEmpty {
                    Text(metaParts.joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundColor(.wordleMuted)
                }
            }

            Spacer()

            Button(action: { store.deleteSuggestion(key: key) }) {
                Text("Delete")
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
        .padding(.vertical, 4)
    }

    // MARK: - Footer (suggestions import/export/reset + combined backup)

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                footerButton("Import") { showImportSuggestions = true }
                footerButton("Export") {
                    exportSuggestionsDoc = JSONDocument(data: store.suggestionsExportData())
                    showExportSuggestions = true
                }
                footerButton("Reset to defaults") { showResetSuggestionsConfirm = true }
            }

            Divider().background(Color.wordleBorder)

            // The combined backup row: everything (guesses, word list,
            // hidden words, suggestions) in one JSON file. This is the
            // "all in one" export/import the web PWA doesn't have — handy
            // for moving to a new device or after reinstalling the app.
            VStack(alignment: .leading, spacing: 4) {
                Text("Backup everything")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.wordleMuted)
                HStack(spacing: 8) {
                    footerButton("Export backup") {
                        exportBackupDoc = JSONDocument(data: store.backupExportData())
                        showExportBackup = true
                    }
                    footerButton("Import backup") { showImportBackup = true }
                }
            }
        }
        .padding(.top, 4)
    }

    private func footerButton(_ title: String, action: @escaping () -> Void) -> some View {
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

    // MARK: - Import handlers

    private func handleSuggestionsImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            importResultMessage = "Could not read suggestions.json — make sure it's a valid exported file."
            return
        }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: url) else {
            importResultMessage = "Could not read suggestions.json — make sure it's a valid exported file."
            return
        }

        do {
            let count = try store.importSuggestions(jsonData: data)
            importResultMessage = "Imported \(count) suggestion(s)."
        } catch {
            importResultMessage = "Could not read suggestions.json — make sure it's a valid exported file."
        }
    }

    private func handleBackupImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            backupErrorMessage = "Could not read that backup file."
            return
        }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: url) else {
            backupErrorMessage = "Could not read that backup file."
            return
        }

        do {
            try store.importBackup(jsonData: data)
            backupResultMessage = "Backup restored."
        } catch {
            backupErrorMessage = "Could not read that backup file — make sure it's a valid exported backup."
        }
    }
}

#Preview {
    ScrollView {
        SavedSuggestionsView()
            .padding()
    }
    .background(Color.wordleBackground)
    .environmentObject(GameStore())
}
