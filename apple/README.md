# Wordle Solver — native SwiftUI app (macOS + iOS)

This `apple/` folder is a native Swift/SwiftUI port of the web app in the
repo root (`index.html` + `wordle.py`). It is **source code to assemble into
an Xcode project**, not a buildable Xcode project by itself — see section 1.

The filtering logic (green/yellow/black/doubled-letter inference) is a
faithful, hand-ported copy of `wordle.py`'s `parse_patterns` and
`filter_words` functions. The UI mirrors the dark palette and layout of
`index.html`, scoped down to the core solver (see section 4 for what's
deliberately left out of this v1).

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
7. Drag `Sources/Resources/words.txt` into the project too, into any group
   (e.g. a new `Resources` group). In the same "Choose options" sheet,
   again confirm **"Copy items if needed"** and the **WordleSolver app
   target** checkbox are both checked.
   - **This is the single most common setup mistake**: if `words.txt`
     isn't checked into the app target's membership, `WordList.load()` will
     silently return an empty array (it's written to fail gracefully rather
     than crash) and the app will always show "0 words found." If that
     happens, select `words.txt` in the navigator, open the **File
     Inspector** (right-hand panel, ⌥⌘1), and under "Target Membership"
     make sure **WordleSolver** is checked. You can also verify it under the
     app target's **Build Phases → Copy Bundle Resources** list.
8. Drag `Tests/WordleFilterTests.swift` into your test target. If the
   project template already created a `WordleSolverTests` group/target, drop
   it there (make sure the **WordleSolverTests target**, not the app
   target, is checked in "Choose options"). If no test target exists yet,
   create one first via **File → New → Target… → Unit Testing Bundle**,
   then drag the file in afterward.

## 3. Running it

- **Run the tests:** press **Cmd+U** (or Product → Test). This runs
  `WordleFilterTests`, which exercises every constraint-inference and
  filtering rule ported from `test_wordle.py`. Since none of this code has
  been compiler-checked yet, do this *immediately* after assembling the
  project — it's the fastest way to catch any leftover typos.
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

## 4. What's in v1 vs. future work

**v1 (this port) is the core solver only:**
- Enter guesses as 5-letter words, tap tiles to mark them black/yellow/green.
- A separate "black letters" field for letters you know are absent.
- Live-updating list of remaining candidate words.
- State (guesses + black letters) is saved automatically via
  `UserDefaults`, so closing and reopening the app keeps your progress.

**Deliberately NOT ported (left for future work), matching what the task
scoped out of this port:**
- The "bot suggests a word" feature and `suggestions.json` persistence.
- Importing/exporting a custom word list (the app always uses the bundled
  `words.txt`).
- Hiding/removing words from future results ("Remove" button in the web UI).
- Haptic feedback on tile taps.
- A Share sheet / exporting results.

## 5. Cross-checking against the Python CLI

Since this is a hand-port that couldn't be compiler-verified here, it's
worth spot-checking the Swift app's results against the original Python CLI
for the same inputs. From the repo root:

```sh
python3 wordle.py --black "dukfiht" ".R.n." "..g.."
```

This is the example from `wordle.py`'s own docstring: two guesses (`DRUNK`
→ ⬛🟩⬛🟨⬛, `FIGHT` → ⬛⬛🟨⬛⬛) with black letters `dukfiht`. To reproduce
the same scenario in the app:

1. Add a guess row, type `RUNKD`... actually simpler: type **`DRUNK`**,
   then tap tiles so the colors read black, green, black, yellow, black
   (matching `.R.n.`).
2. Add a second guess row, type **`FIGHT`**, and set its colors to black,
   black, yellow, black, black (matching `..g..`).
3. In the "Black letters" field, type `dukfiht`.
4. The app's result count and word list should exactly match running the
   command above (use `python3 wordle.py --black "dukfiht" ".R.n." "..g.."`
   with no `--count` flag to see the full matching word list, sorted
   alphabetically — the Swift app's list isn't sorted by default, so compare
   the *set* of words, not the order).

If the two ever disagree, the bug is almost certainly in
`apple/Sources/Model/WordleFilter.swift` — re-read it side by side with
`parse_patterns`/`filter_words` in `wordle.py` at the repo root.
