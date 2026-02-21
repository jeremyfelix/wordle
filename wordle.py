#!/usr/bin/env python3
"""
Wordle word filter: Takes guesses with tile colors and filters words.txt to remaining solutions.

Usage:
    python3 wordle.py --black "letters" pattern1 pattern2 ...

Pattern format (5 characters):
    - Uppercase letter = GREEN tile (correct position)
    - Lowercase letter = YELLOW tile (wrong position, but in word)
    - . = BLACK tile (letter not in word, or black in --black flag)

Examples:
    # DRUNK returned ⬛🟩⬛🟨⬛ (D=⬛, R=🟩, U=⬛, N=🟨, K=⬛)
    # FIGHT returned ⬛⬛🟨⬛⬛ (F=⬛, I=⬛, G=🟨, H=⬛, T=⬛)
    python3 wordle.py --black "dukfiht" ".R.n." "..g.."
"""

import argparse
import re
import sys
from pathlib import Path
from collections import defaultdict


def parse_patterns(patterns: list[str], black_letters: str) -> dict:
    """
    Parse guess patterns into constraints.

    Returns:
        {
            'green': {position: letter, ...},  # position -> required letter
            'yellow': {letter: [excluded_positions, ...], ...},  # letter -> list of bad positions
            'black': set(),  # letters definitely not in word
            'doubled': {letter: constraint, ...},  # 'letter': 'required' | 'only_once'
        }
    """
    green = {}
    yellow = defaultdict(list)
    black = set(black_letters)
    all_guesses = []

    # Parse each pattern
    for pattern in patterns:
        if len(pattern) != 5:
            raise ValueError(f"Pattern must be 5 characters: {pattern}")

        guess_letters = []
        for pos, char in enumerate(pattern):
            if char.isupper():
                # Green tile
                guess_letters.append((char.lower(), "green", pos))
                green[pos] = char.lower()
            elif char.islower():
                # Yellow tile
                guess_letters.append((char, "yellow", pos))
                yellow[char].append(pos)
            elif char == ".":
                # Black tile (unknown letter, possibly in --black)
                guess_letters.append((None, "black", pos))
            else:
                raise ValueError(f"Invalid pattern character: {char}")

        all_guesses.append(guess_letters)

    # Infer doubled letter constraints
    doubled = {}
    letter_data = defaultdict(
        lambda: {"green_pos": set(), "yellow_pos": set()}
    )

    # Collect all positions for each letter state
    for guess in all_guesses:
        for letter, state, pos in guess:
            if letter:
                if state == "green":
                    letter_data[letter]["green_pos"].add(pos)
                elif state == "yellow":
                    letter_data[letter]["yellow_pos"].add(pos)

    # Analyze doubled letters
    for letter, data in letter_data.items():
        green_pos = data["green_pos"]
        yellow_pos = data["yellow_pos"]

        if len(green_pos) >= 2:
            # Letter appears green at 2+ different positions -> definitely has 2+ copies
            doubled[letter] = "required"
        elif len(green_pos) >= 1 and len(yellow_pos) >= 1:
            # Letter appears green at one position AND yellow at another -> has 2+ copies
            doubled[letter] = "required"
        # Note: Yellow at multiple positions doesn't necessarily mean 2+ copies
        # (the letter could be at a third position). So we don't infer from that.

    return {
        "green": green,
        "yellow": dict(yellow),
        "black": black,
        "doubled": doubled,
    }


def build_filter_regex(constraints: dict) -> str:
    """
    Build a regex pattern that matches words satisfying all constraints.

    Strategy:
    1. Start with 5-character anchor: ^.....$
    2. For green positions, lock in the letter
    3. For yellow positions, put . (will be checked separately)
    """
    green = constraints["green"]
    pattern = list(".....")

    # Place green letters
    for pos, letter in green.items():
        pattern[pos] = letter

    return "^" + "".join(pattern) + "$"


def filter_words(words: list[str], constraints: dict) -> list[str]:
    """
    Filter words based on constraints.
    """
    yellow = constraints["yellow"]
    black = constraints["black"]
    doubled = constraints["doubled"]

    regex = build_filter_regex(constraints)
    pattern = re.compile(regex)

    filtered = []

    for word in words:
        # Check basic regex (length + green positions)
        if not pattern.match(word):
            continue

        # Check: no black letters
        if any(c in black for c in word):
            continue

        # Check: yellow letters present and not in excluded positions
        valid = True
        for letter, excluded_positions in yellow.items():
            if letter not in word:
                valid = False
                break

            # Ensure letter is not at any excluded position
            for pos in excluded_positions:
                if word[pos] == letter:
                    valid = False
                    break

            if not valid:
                break

        if not valid:
            continue

        # Check doubled letter constraints
        for letter, constraint in doubled.items():
            count = word.count(letter)
            if constraint == "required" and count < 2:
                valid = False
                break
            elif constraint == "only_once" and count > 1:
                valid = False
                break

        if not valid:
            continue

        filtered.append(word)

    return filtered


def main():
    parser = argparse.ArgumentParser(
        description="Filter Wordle words based on guess results.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Pattern format (5 characters per pattern):
  - Uppercase = GREEN tile (correct position)
  - Lowercase = YELLOW tile (in word, wrong position)
  - . = BLACK tile (not in word)

Example (two guesses):
  $ python3 wordle.py --black "dukfiht" ".R.n." "..g.."
  
  This filters for words where:
    - No d, u, k, f, i, h, t (black letters)
    - Position 1 is 'r' (green from DRUNK)
    - Contains 'n' but not at position 3 (yellow from DRUNK)
    - Contains 'g' but not at position 2 (yellow from FIGHT)
        """,
    )
    parser.add_argument(
        "--black",
        type=str,
        default="",
        help="Letters that returned black tiles (space/comma-separated or as one string)",
    )
    parser.add_argument(
        "--count", action="store_true", help="Show only the count of remaining words"
    )
    parser.add_argument(
        "patterns", nargs="+", help="Guess patterns (5 characters each)"
    )

    args = parser.parse_args()

    # Load words
    words_file = Path(__file__).parent / "words.txt"
    if not words_file.exists():
        print(f"Error: {words_file} not found", file=sys.stderr)
        sys.exit(1)

    with open(words_file, "r", encoding="utf-8") as f:
        words = [line.strip().lower() for line in f if line.strip()]

    try:
        constraints = parse_patterns(args.patterns, args.black)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    filtered = filter_words(words, constraints)

    if args.count:
        print(len(filtered))
    else:
        for word in sorted(filtered):
            print(word)


if __name__ == "__main__":
    main()
