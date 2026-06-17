//
//  ResultsView.swift
//  WordleSolver
//
//  Shows the count + grid of remaining candidate words, mirroring
//  index.html's `#results` / `.results-bar` / `.word-grid` / `.word-chip`.
//
//  v1 scope note: this is read-only (no select/remove/import here — those
//  web-app features are explicitly future work, see apple/README.md
//  section 4).
//

import SwiftUI

struct ResultsView: View {
    let candidates: [String]

    /// Adaptive grid columns, similar to the CSS
    /// `grid-template-columns: repeat(auto-fill, minmax(82px, 1fr))`.
    private let columns = [GridItem(.adaptive(minimum: 82), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(candidates.count) word\(candidates.count == 1 ? "" : "s") found")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.wordleText)
                .padding(.vertical, 6)

            if candidates.isEmpty {
                Text("No words match these constraints yet.")
                    .font(.system(size: 13))
                    .foregroundColor(.wordleMuted)
                    .padding(.vertical, 12)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(candidates, id: \.self) { word in
                        Text(word.uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.wordleText)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.wordleSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.wordleBorder, lineWidth: 2)
                            )
                            .cornerRadius(6)
                    }
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        ResultsView(candidates: ["crane", "slate", "irate", "trace"])
            .padding()
    }
    .background(Color.wordleBackground)
}
