//
//  TileView.swift
//  WordleSolver
//
//  A single Wordle tile (one letter position in one guess row). Tapping a
//  filled tile cycles its color black -> yellow -> green -> black, mirroring
//  index.html's `onTileClick` / `.tile[data-letter] { cursor:pointer }`.
//
//  This file also defines the dark color palette shared by every view, as a
//  `Color` extension. It lives here (rather than in the Model layer) because
//  Model files deliberately avoid importing SwiftUI — see WordleFilter.swift.
//

import SwiftUI

// MARK: - Palette

// Hex values copied directly from index.html's `:root` CSS variables, so
// the native app looks the same as the web version.
extension Color {
    /// `--c-black: #3a3a3c` — a filled "black" (absent-letter) tile.
    static let wordleBlack = Color(red: 0x3a / 255, green: 0x3a / 255, blue: 0x3c / 255)
    /// `--c-yellow: #b59f3b`
    static let wordleYellow = Color(red: 0xb5 / 255, green: 0x9f / 255, blue: 0x3b / 255)
    /// `--c-green: #538d4e`
    static let wordleGreen = Color(red: 0x53 / 255, green: 0x8d / 255, blue: 0x4e / 255)
    /// `--c-bg: #121213` — the screen background.
    static let wordleBackground = Color(red: 0x12 / 255, green: 0x12 / 255, blue: 0x13 / 255)
    /// `--c-surface: #1a1a1b` — cards, inputs, empty tiles.
    static let wordleSurface = Color(red: 0x1a / 255, green: 0x1a / 255, blue: 0x1b / 255)
    /// `--c-border: #3a3a3c` — same hex as wordleBlack, used for borders.
    static let wordleBorder = Color(red: 0x3a / 255, green: 0x3a / 255, blue: 0x3c / 255)
    /// `--c-text: #ffffff`
    static let wordleText = Color.white
    /// `--c-muted: #818384`
    static let wordleMuted = Color(red: 0x81 / 255, green: 0x83 / 255, blue: 0x84 / 255)
}

extension TileColor {
    /// The SwiftUI color a filled tile of this color should show.
    var swiftUIColor: Color {
        switch self {
        case .black: return .wordleBlack
        case .yellow: return .wordleYellow
        case .green: return .wordleGreen
        }
    }
}

// MARK: - TileView

struct TileView: View {
    /// The letter shown on this tile, or nil if the position is still empty.
    let letter: Character?
    /// The tile's current color (only visually meaningful once `letter` is
    /// set — see body below).
    let color: TileColor
    /// Called when the user taps a FILLED tile (empty tiles don't respond
    /// to taps, matching the web app, which only makes tiles `cursor:
    /// pointer` once they have a letter).
    let onTap: () -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 6) // matches CSS --radius: 6px
            .fill(letter == nil ? Color.wordleSurface : color.swiftUIColor)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(letter == nil ? Color.wordleBorder : color.swiftUIColor, lineWidth: 2)
            )
            .overlay(
                Text(letter.map { String($0).uppercased() } ?? "")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.wordleText)
            )
            .frame(width: 48, height: 48)
            .onTapGesture {
                // Only filled tiles cycle color, matching the web app.
                guard letter != nil else { return }
                onTap()
            }
    }
}

#Preview {
    HStack(spacing: 6) {
        TileView(letter: nil, color: .black, onTap: {})
        TileView(letter: "a", color: .black, onTap: {})
        TileView(letter: "b", color: .yellow, onTap: {})
        TileView(letter: "c", color: .green, onTap: {})
    }
    .padding()
    .background(Color.wordleBackground)
}
