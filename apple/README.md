# Wordle Solver — native SwiftUI app (macOS + iOS)

This `apple/` folder is a native Swift/SwiftUI port of the web app in the
repo root (`index.html`). It is **source code to assemble into an Xcode
project**, not a buildable Xcode project by itself — see section 1.

The filtering logic (green/yellow/black/doubled/maxCount-letter inference)
is a faithful, hand-ported copy of `index.html`'s `parseGuesses` and
`filterWords` functions — **`index.html`, not `wordle.py`, is the spec this
port follows**, since `index.html` is the version actually used day to day
and has both the `maxCount` constraint and the bot-suggestions feature that
`wordle.py` lacks. The UI mirrors the dark palette and layout of
`index.html`, including bot suggestions, word-list management, and
import/export (see section 4 for the full feature list).

## 1. Why this isn't already an `.xcodeproj`

Xcode and the Swift compiler only run on macOS. This port was written in a
Linux environment that has no Xcode and cannot compile or run Swift code —
every file here was written by careful, manual translation of the Python
logic and hand-checked SwiftUI patterns, **not verified by a compiler**.
Treat the first build in Xcode as the real correctness check, and expect to
fix a handful of small typos/syntax slips — see the "risks" list your
assistant reported alongside this README for the specific things to
double-check first.

Because no Xcode project file (`.xcodeproj`/`.xcworkspace`) exists yet, you
need to create one yourself and drag these files in. That's what section 2
walks through.

## 2. Setting up the Xcode project

You'll need a Mac with Xcode installed (free from the Mac App Store).

1. Open Xcode → **File → New → Project…**
2. Choose the **Multiplatform** tab, then the **App** template, and click
   Next.
3. Set:
   - **Product Name:** `WordleSolver` (this name matters — it becomes the
     app's module name, which `apple/Tests/WordleFilterTests.swift` assumes
     when it writes `@testable import WordleSolver`. If you pick a
     different name, update that one line in the test file to match.)
   - **Interface:** SwiftUI
   - **Language:** Swift
   - Leave "Include Tests" checked if available — it saves you the step of
     creating a test target manually in step 6.
4. Save it wherever you like on disk (e.g. next to this repo checkout, or
   anywhere else — it does not need to live inside the `wordle` git repo at
   all, since this `apple/` folder is just the source to copy in).
5. Xcode will have created its own starter `ContentView.swift` and an
   `@main` App file. **Delete those** (Move to Trash) — we're bringing in
   replacements with the same names from this folder.
6. In Finder, drag these folders from this repo's `apple/Sources/` into your
   Xcode project's navigator sidebar (drop them onto the top-level
   `WordleSolver` group/folder):
   - `Sources/Model/`
   - `Sources/Store/`
   - `Sources/Views/`

   When the "Choose options" sheet appears, make sure **"Copy items if
   needed"** is checked and the **WordleSolver app target** checkbox is
   checked (so the new `.swift` files actually get compiled into the app).
7. Drag `Sources/Resources/words.txt` AND `Sources/Resources/suggestions.json`
   into the project too, into any group (e.g. a new `Resources` group). In
   the same "Choose options" sheet, again confirm **"Copy items if
   needed"** and the **WordleSolver app target** checkbox are both checked
   — for BOTH files.
   - **This is the single most common setup mistake**: if `words.txt` or
     `suggestions.json` isn't checked into the app target's membership,
     `WordList.load()` / the bundled-suggestions loader in `GameStore` will
     silently return an empty array/dictionary (both are written to fail
     gracefully rather than crash) and the app will show "0 words found" or
     no bundled bot suggestions. If that happens, select the file in the
     navigator, open the **File Inspector** (right-hand panel, ⌥⌘1), and
     under "Target Membership" make sure **WordleSolver** is checked. You
     can also verify both files are listed under the app target's **Build
     Phases → Copy Bundle Resources**.
   - If you want the scenarioKey-parity unit tests (see section 3) to also
     verify against the real bundled file (rather than just their hardcoded
     literal-string assertions), add `suggestions.json` to the
     **WordleSolverTests** target's membership too — it's optional, the
     tests degrade gracefully if it's missing from the test bundle.
8. Drag `Tests/WordleFilterTests.swift` into your test target. If the
   project template already created a `WordleSolverTests` group/target, drop
   it there (make sure the **WordleSolverTests target**, not the app
   target, is checked in "Choose options"). If no test target exists yet,
   create one first via **File → New → Target… → Unit Testing Bundle**,
   then drag the file in afterward.

## 3. Running it

- **Run the tests:** press **Cmd+U** (or Product → Test). This runs
  `WordleFilterTests`, which exercises every constraint-inference and
  filtering rule (ported from `test_wordle.py` and updated for the
  black-tiles + `maxCount` model), plus two `scenarioKey` PARITY tests that
  assert byte-identical output against literal keys taken straight from
  the committed `suggestions.json` — these are the most important tests in
  the suite, since they're what guarantees bot suggestions (including ones
  exported from the web PWA) actually match up in this app.

- **Run the logic tests WITHOUT Xcode (Linux / CI / fast loop):** the
  pure-Foundation core ships with a Swift Package Manager manifest
  (`apple/Package.swift`), so you can build and test it on any platform with
  a Swift toolchain — no Mac required:

  ```sh
  cd apple && swift test
  ```

  This compiles only `Sources/Model` (the SwiftUI-free solver core) and runs
  the same 31-test suite. The SwiftUI UI (`Sources/Views`) and state
  container (`Sources/Store`) need Apple's frameworks, so they're built by
  the Xcode project above, not by SwiftPM. The core + tests have been
  compiler-verified this way with Swift 6.1.2 on Linux (31/31 passing); the
  UI layer still needs a first build in Xcode on a Mac.
- **Run on your Mac:** at the top of the Xcode window, pick the **"My Mac"**
  destination from the scheme/destination dropdown, then press **Cmd+R**.
  The app should launch as a normal resizable macOS window.
- **Run in the iOS Simulator:** switch the destination dropdown to any
  iPhone simulator (e.g. "iPhone 15") and press Cmd+R again. No extra setup
  needed — simulators don't require code signing.
- **Run on a physical iPhone:** plug the iPhone in (or pair it wirelessly),
  select it from the destination dropdown, and press Cmd+R.
  - The first time, Xcode will ask you to sign in with an Apple ID under
    **Xcode → Settings → Accounts**, and to set a **Team** for the
    WordleSolver target under the project's **Signing & Capabilities** tab.
  - With a **free Apple ID** (no paid enrollment), this works for personal
    use, but the app's signature expires after about a week — after that
    you just re-run from Xcode (Cmd+R) once to re-sign and reinstall it; no
    data is lost.
  - With the **paid Apple Developer Program ($99/year)**, signing lasts a
    full year instead of a week, and you additionally unlock TestFlight
    (distributing builds to others without USB-connecting their phones) and
    submitting to the App Store. Not required just to use the app yourself.

## 4. Features

This port now mirrors index.html's full feature set, not just the core
filtering logic:

- **Core solver**: enter guesses as 5-letter words, tap tiles to mark them
  black/yellow/green (⬛ → 🟨 → 🟩 → ⬛). There is **no separate "black
  letters" field** — that was a v1 simplification that has been removed.
  Black is now expressed exactly like a real Wordle guess: every tile
  starts black, and a tile you never touch (or tap back around to black)
  IS the "this letter is absent" signal. This matches index.html's actual
  model (`parseGuesses` derives `black` from tile `data-color`, not from a
  free-text field) and is also just a more natural gesture.
- **Live-updating results**: the candidate list recomputes as you type/tap,
  with no separate "Filter Words" button (index.html has one; this app
  doesn't need it since SwiftUI re-renders automatically on state change).
- **Word-list management** (`WordListBarView`): shows the active word
  count ("12,972 words" or "Custom list · 340 words"). "Import" loads a
  `.txt` file (one word per line) as a custom dictionary, replacing the
  bundled list. "Save" exports the active dictionary (minus hidden words)
  as `.txt`. "Reset list" (shown only while a custom list is active)
  restores the bundled default and clears hidden words.
- **Hide/remove words** (`ResultsView`): tap word chips to select them,
  then "Remove (N)" hides them from all future results (with a confirm
  alert). A "N words hidden · Reset hidden" bar appears whenever any words
  are hidden.
- **Bot suggestions** (`BotCardView`, `GameStore`): once at least one guess
  row is fully filled in (5/5 letters, any colors), a "Bot suggests" card
  appears above the results grid. It shows a previously recorded
  suggestion for that exact scenario (if any), with tap-to-insert (fills
  the first empty guess row, or adds a new one), Edit, and Delete. If no
  suggestion is recorded yet, "+ Record" opens a small form (5-letter word
  + optional note).
- **Saved suggestions** (`SavedSuggestionsView`): a collapsible "Saved
  suggestions (N)" list of every recorded suggestion, each with its note /
  remaining-candidate-count / saved-date and a Delete button. Footer
  buttons: Import (`.json`), Export (`.json`), and Reset to defaults
  (drops local edits, reloads only the committed `suggestions.json`).
- **Combined backup** (also in `SavedSuggestionsView`'s footer): "Export
  backup" / "Import backup" save/restore EVERYTHING in one JSON file —
  guesses, custom word list, hidden words, and suggestions together. This
  doesn't exist in the web PWA (there, each piece is exported separately);
  it's the most convenient way to move all your data to a new device or
  after reinstalling.
- All state (guesses, word-list customization, suggestions) is saved
  automatically via `UserDefaults`, so closing and reopening the app keeps
  your progress.

### Suggestions are compatible with the web PWA

`suggestions.json` entries are keyed by `WordleFilter.scenarioKey(_:)`,
which is built to produce the EXACT same string as index.html's JS
`scenarioKey()` function — same key order (`g`, `y`, `b`, `m`), same array
shapes, no extra whitespace. This means a `suggestions.json` file exported
from the web app's "Export" button can be imported here (via the "Saved
suggestions" → Import button) and every suggestion will match up with the
right scenario, byte-for-byte. See the scenarioKey parity tests in
`Tests/WordleFilterTests.swift` for two literal, hand-verified examples.

**Still not ported (genuinely out of scope, unlike the rest of this list):**
- Haptic feedback on tile taps.
- A Share sheet for results.

## 5. Cross-checking against index.html (NOT wordle.py)

Since this is a hand-port that couldn't be compiler-verified here, it's
worth spot-checking the Swift app's results against the web app for the
same inputs. **Compare against `index.html` running in a browser, not
`wordle.py`/the CLI** — the two reference implementations differ slightly:
`wordle.py` has a separate `--black` flag and no `maxCount` concept,
whereas `index.html` (and this Swift port) derive black purely from
black-colored tiles and add the `maxCount` constraint (see the comment at
the top of `WordleFilter.swift` for exactly why). There is no longer a
"black letters" field in this app to even map onto `--black`.

To spot-check a scenario:

1. Open `index.html` in a browser (from the repo root, e.g. `python3 -m
   http.server` then visit it, or just open the file directly).
2. Enter the same guesses with the same tile colors in both the browser
   and the Swift app (tap tiles to cycle black → yellow → green → black in
   both — they use the identical gesture).
3. The result count and word list should match exactly (the Swift app's
   list isn't sorted by default, so compare the *set* of words, not the
   order).
4. As an extra cross-check specifically for the bot-suggestions feature:
   export `suggestions.json` from the web app's "Saved suggestions" →
   Export button, and import it into the Swift app's "Saved suggestions" →
   Import button. Every suggestion should land on the exact same scenario
   in both apps — if any suggestion seems to "disappear" (not show up for
   the matching guesses) after import, `WordleFilter.scenarioKey` has
   drifted from index.html's `scenarioKey()` and needs to be re-diffed
   against it.

If results ever disagree, the bug is almost certainly in
`apple/Sources/Model/WordleFilter.swift` — re-read it side by side with
`parseGuesses`/`filterWords`/`scenarioKey` in `index.html`'s `<script>`
block at the repo root.
