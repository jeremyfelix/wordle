//
//  FileDocuments.swift
//  WordleSolver
//
//  Tiny `FileDocument` wrapper types used by SwiftUI's `.fileExporter`
//  modifier (the native, cross-platform iOS/macOS equivalent of index.html's
//  "create a Blob + <a download> + click it" export trick). Each type here
//  is just a thin box around the data we already have (a `String` or
//  `Data`) — there's no real logic, just enough conformance to
//  `FileDocument` for SwiftUI's file-saving UI to work.
//
//  Beginner note: `FileDocument` is the protocol SwiftUI's document-based
//  file pickers use to read/write a file's contents. We don't need the
//  read side for export-only documents, but the protocol requires an
//  initializer anyway, so each type below has a (trivial, never actually
//  exercised for our export-only use) `init(configuration:)`.
//

import SwiftUI
import UniformTypeIdentifiers

/// Wraps a plain-text `String` for export via `.fileExporter`. Used for the
/// word-list "Save" button (exports `words.txt`).
struct PlainTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    static var writableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        self.text = String(data: data, encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

/// Wraps raw JSON `Data` for export via `.fileExporter`. Used for both the
/// suggestions export ("suggestions.json") and the combined backup export.
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
