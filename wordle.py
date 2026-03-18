#!/usr/bin/env python3
"""
Wordle word filter: Takes guesses with tile colors and filters words.txt to
remaining solutions.

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
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from collections import defaultdict


def parse_patterns(patterns: list[str], black_letters: str) -> dict:
    """
    Parse guess patterns into constraints.

    Returns:
    {
        'green': {position: letter, ...},  # position -> required letter
        'yellow': {letter: [excluded_positions, ...], ...},  # letter -> list
            of bad positions
        'black': set(),  # letters definitely not in word
        'doubled': {letter: min_required, ...},  # 'letter': minimum required
            occurrences (int)
    }
    """
    green = {}
    yellow = defaultdict(list)
    black = set(black_letters)
    all_guesses = []

    # Parse each pattern
    for pattern in patterns:
        if len(pattern) != 5:
            raise ValueError(f'Pattern must be 5 characters: {pattern}')

        guess_letters: list[tuple[str | None, str, int]] = []
        for pos, char in enumerate(pattern):
            if char.isupper():
                # Green tile
                guess_letters.append((char.lower(), 'green', pos))
                green[pos] = char.lower()
            elif char.islower():
                # Yellow tile
                guess_letters.append((char, 'yellow', pos))
                yellow[char].append(pos)
            elif char == '.':
                # Black tile (unknown letter, possibly in --black)
                guess_letters.append((None, 'black', pos))
            else:
                raise ValueError(f'Invalid pattern character: {char}')

        all_guesses.append(guess_letters)

    # Infer doubled letter constraints (minimum required occurrences)
    doubled = {}
    letter_data: defaultdict[str | None, dict[str, set]] = defaultdict(
        lambda: {'green_pos': set(), 'yellow_pos': set()}
    )

    # Collect per-guess counts: maximum number of colored occurrences of a
    # letter seen within any single guess. This (rather than summing across
    # guesses) avoids inferring duplicates when the same letter was colored in
    # different guesses but only one copy exists.
    max_in_guess: defaultdict[str | None, int] = defaultdict(int)

    for guess in all_guesses:
        counts: defaultdict[str, int] = defaultdict(int)
        for letter, state, pos in guess:
            if letter:
                if state == 'green':
                    letter_data[letter]['green_pos'].add(pos)
                elif state == 'yellow':
                    letter_data[letter]['yellow_pos'].add(pos)
                if state in ('green', 'yellow'):
                    counts[letter] += 1

        for letter, cnt in counts.items():
            if cnt > max_in_guess[letter]:
                max_in_guess[letter] = cnt

    # For each letter, determine the minimum required occurrences. We require
    # multiple copies only when:
    #  - a single guess showed multiple colored copies of the letter (e.g. two
    #    't's in one guess), or
    #  - the letter appears green in multiple positions (across guesses).
    for letter in set(list(letter_data.keys()) + list(max_in_guess.keys())):
        max_single = max_in_guess.get(letter, 0)
        green_pos = letter_data[letter]['green_pos']

        min_required = max_single
        if len(green_pos) >= 2:
            min_required = max(min_required, 2)

        if min_required >= 2:
            doubled[letter] = min_required

    return {
        'green': green,
        'yellow': dict(yellow),
        'black': black,
        'doubled': doubled,
    }


def build_filter_regex(constraints: dict) -> str:
    """
    Build a regex pattern that matches words satisfying all constraints.

    Strategy:
    1. Start with 5-character anchor: ^.....$
    2. For green positions, lock in the letter
    3. For yellow positions, put . (will be checked separately)
    """
    green = constraints['green']
    pattern = list('.....')

    # Place green letters
    for pos, letter in green.items():
        pattern[pos] = letter

    return '^' + ''.join(pattern) + '$'


def filter_words(words: list[str], constraints: dict) -> list[str]:
    """
    Filter words based on constraints.
    """
    yellow = constraints['yellow']
    black = constraints['black']
    doubled = constraints['doubled']

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
            # If constraint is an integer, it's the minimum required
            # occurrences
            if isinstance(constraint, int):
                if count < constraint:
                    valid = False
                    break
            elif constraint == 'required':
                if count < 2:
                    valid = False
                    break
            elif constraint == 'only_once':
                if count > 1:
                    valid = False
                    break

        if not valid:
            continue

        filtered.append(word)

    return filtered


def prune_words(words: list[str], words_file: Path) -> None:
    """
    Use fzf to select words to remove from words.txt.
    """
    if not words:
        print('No words to prune.')
        return

    # Create a temporary list of words to select from
    words_str = '\n'.join(sorted(words, reverse=True))

    try:
        # Open fzf with multi-select
        result = subprocess.run(
            ['fzf', '--no-sort', '--multi', '--preview', 'echo {}'],
            input=words_str,
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        print(
            'Error: fzf not found. Install fzf to use the prune option.',
            file=sys.stderr,
        )
        sys.exit(1)

    # If user cancelled, return
    if result.returncode != 0:
        print('Cancelled.')
        return

    selected_words = set(
        word.strip()
        for word in result.stdout.strip().split('\n')
        if word.strip()
    )

    if not selected_words:
        print('No words selected.')
        return

    # Show confirmation
    print(f'\nWords to prune ({len(selected_words)}):')
    for word in sorted(selected_words):
        print(f'  - {word}')

    # Ask for confirmation
    response = input('\nProceed with pruning? (y/N): ').strip().lower()
    if response not in ['yes', 'y']:
        print('Cancelled.')
        return

    # Read all words from file
    with open(words_file, 'r', encoding='utf-8') as f:
        all_words = [line.strip().lower() for line in f if line.strip()]

    # Remove selected words
    remaining_words = [w for w in all_words if w not in selected_words]

    # Write back to file safely using a temporary file
    temp_fd, temp_path = tempfile.mkstemp(dir=words_file.parent, text=True)
    try:
        with os.fdopen(temp_fd, 'w', encoding='utf-8') as f:
            for word in remaining_words:
                f.write(word + '\n')
        # Move temp file to final location
        os.replace(temp_path, words_file)
    except Exception:
        # Clean up temp file if something went wrong
        try:
            os.unlink(temp_path)
        except OSError:
            pass
        raise

    print(f'\nPruned {len(selected_words)} words.')
    print(f'{len(remaining_words)} words remaining in words.txt')


def main():
    parser = argparse.ArgumentParser(
        description='Filter Wordle words based on guess results.',
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
        '--black',
        type=str,
        default='',
        help='Letters that returned black tiles (space/comma-separated or as'
        ' one string)',
    )
    parser.add_argument(
        '--count',
        action='store_true',
        help='Show only the count of remaining words',
    )
    parser.add_argument(
        '--prune',
        action='store_true',
        help='Use fzf to select non-solution words to remove from words.txt',
    )
    parser.add_argument(
        'patterns', nargs='+', help='Guess patterns (5 characters each)'
    )

    args = parser.parse_args()

    # Load words
    words_file = Path(__file__).parent / 'words.txt'
    if not words_file.exists():
        print(f'Error: {words_file} not found', file=sys.stderr)
        sys.exit(1)

    with open(words_file, 'r', encoding='utf-8') as f:
        words = [line.strip().lower() for line in f if line.strip()]

    try:
        constraints = parse_patterns(args.patterns, args.black)
    except ValueError as e:
        print(f'Error: {e}', file=sys.stderr)
        sys.exit(1)

    filtered = filter_words(words, constraints)

    if args.prune:
        prune_words(filtered, words_file)
    elif args.count:
        print(len(filtered))
    else:
        for word in sorted(filtered):
            print(word)


if __name__ == '__main__':
    main()
