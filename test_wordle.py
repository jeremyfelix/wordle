#!/usr/bin/env python3
"""
Comprehensive unit tests for wordle.py filtering logic.

Uses a carefully engineered test word set to avoid dependencies on words.txt.
"""

import re
import unittest
from wordle import parse_patterns, filter_words, build_filter_regex


# Seeded test word set designed to cover corner cases
TEST_WORDS = [
    # Single-letter words (baseline)
    'abide',  # a, b, i, d, e (no duplicates)
    'abate',  # has 'a' twice at different positions
    'attic',  # has 't' twice, 'a' once
    'alloy',  # has 'l' twice
    'allay',  # has 'l' twice and 'a' twice
    'abbey',  # has 'b' twice and 'e' twice
    'added',  # has 'a' and 'd' twice each
    'daddy',  # has 'd' three times
    'eerie',  # has 'e' three times
    'apple',  # has 'p' twice
    'attic',  # 't' twice, 'a' once - key test for doubled inference
    'batch',  # single instances, no duplicates
    'catch',  # single instances, no duplicates
    'cacti',  # has 'c' twice
    'attap',  # has 't' twice at positions 0,1
    'attar',  # has 't' twice and 'a' twice
    'tatty',  # has 't' three times, 'a' once
    'kitty',  # has 't' twice, 'k' and 'i' once
    'ditty',  # has 't' twice, 'd' once
    'motto',  # has 't' twice, 'o' twice, 'm' once
    'petty',  # has 't' twice, 'p' and 'e' once
    'putty',  # has 't' twice, 'p' and 'u' once
    'atone',  # 'a' once, no duplicates
    'alone',  # 'a' once, no duplicates
    'about',  # no duplicates
    'route',  # no duplicates
]


class TestParsePatterns(unittest.TestCase):
    """Tests for parse_patterns constraint inference."""

    def test_green_positions(self):
        """Test green tile (correct position) parsing."""
        constraints = parse_patterns(['A....'], '')
        self.assertEqual(constraints['green'], {0: 'a'})
        self.assertEqual(constraints['yellow'], {})

    def test_yellow_positions(self):
        """Test yellow tile (wrong position) parsing."""
        constraints = parse_patterns(['a....'], '')
        self.assertEqual(constraints['yellow'], {'a': [0]})
        self.assertEqual(constraints['green'], {})

    def test_black_letters(self):
        """Test black tile (not in word) parsing."""
        constraints = parse_patterns(['.....'], 'xyz')
        self.assertEqual(constraints['black'], {'x', 'y', 'z'})

    def test_mixed_pattern(self):
        """Test pattern with green, yellow, and black mixed."""
        constraints = parse_patterns(['A.b..'], 'xyz')
        self.assertEqual(constraints['green'], {0: 'a'})
        self.assertEqual(constraints['yellow'], {'b': [2]})
        self.assertEqual(constraints['black'], {'x', 'y', 'z'})

    def test_doubled_from_single_guess_multiple_colored(self):
        """Test doubled inference when letter appears twice in one guess."""
        # Pattern "..T.." has 't' colored once in one guess
        constraints = parse_patterns(['..T..'], '')
        self.assertNotIn('t', constraints['doubled'])

        # Pattern "..T.T" has 't' colored twice in one guess
        constraints = parse_patterns(['..T.T'], '')
        self.assertIn('t', constraints['doubled'])
        self.assertEqual(constraints['doubled']['t'], 2)

    def test_doubled_from_single_guess_three_times(self):
        """Test when letter appears three times in one guess."""
        constraints = parse_patterns(['T.T.T'], '')
        self.assertIn('t', constraints['doubled'])
        self.assertEqual(constraints['doubled']['t'], 3)

    def test_doubled_from_green_and_yellow(self):
        """Test doubled inference when letter is green in one position and
        yellow in another."""
        # Green 't' at position 0, yellow 't' at position 2
        constraints = parse_patterns(['T.t..'], '')
        self.assertIn('t', constraints['doubled'])
        self.assertEqual(constraints['doubled']['t'], 2)

    def test_doubled_from_green_twice(self):
        """Test doubled when letter is green at two different positions."""
        constraints = parse_patterns(['T.T..'], '')
        self.assertIn('t', constraints['doubled'])
        self.assertEqual(constraints['doubled']['t'], 2)

    def test_not_doubled_from_multiple_guesses_green_and_yellow(self):
        """Test no doubled inference when letter is green in one guess and
        yellow in another."""
        # First guess: t at position 0 (green)
        # Second guess: t at position 1 (yellow)
        # Green at position 0 AND yellow at position 1 -> does not imply 2
        # copies
        constraints = parse_patterns(['T....', '....t'], '')
        self.assertNotIn('t', constraints['doubled'])

    def test_not_doubled_from_multiple_guesses_yellow(self):
        """Test no doubled inference when letter is yellow in two guesses."""
        # First guess: t at position 0 (yellow)
        # Second guess: t at position 1 (yellow)
        # Yellow at position 0 AND yellow at position 1 -> does not imply 2
        # copies
        constraints = parse_patterns(['t....', '....t'], '')
        self.assertNotIn('t', constraints['doubled'])

    def test_doubled_from_multiple_guesses_green(self):
        """Test doubled inference when letter is green in two guesses at
        different positions."""
        # First guess: t at position 0 (green)
        # Second guess: t at position 1 (green)
        # Green at position 0 AND green at position 1 -> implies 2 copies
        constraints = parse_patterns(['T....', '....T'], '')
        self.assertIn('t', constraints['doubled'])
        self.assertEqual(constraints['doubled']['t'], 2)

    def test_not_doubled_from_multiple_guesses_green_same_position(self):
        """Test no doubled inference when letter is green in two guesses at
        the same position."""
        # First guess: t at position 1 (green)
        # Second guess: t at position 1 (green)
        # Green at position 0 AND green at position 1 -> implies 2 copies
        constraints = parse_patterns(['T....', 'Tr...'], '')
        self.assertNotIn('t', constraints['doubled'])

    def test_letter_in_yellow_two_positions_single_guess(self):
        """Test when letter appears as yellow in two positions within same
        guess."""
        # Pattern ".t.t." has 't' yellow at positions 1 and 3 in one guess
        constraints = parse_patterns(['.t.t.'], '')
        self.assertIn('t', constraints['doubled'])
        self.assertEqual(constraints['doubled']['t'], 2)

    def test_multiple_doubled_letters(self):
        """Test inference with multiple doubled letters."""
        # Green 'a' at positions 0 and 2 -> 'a' must appear at least twice
        constraints = parse_patterns(['A.A..'], '')
        self.assertIn('a', constraints['doubled'])
        # Yellow 'a' at position 1 comes after green
        # (but not before since 'a' is green at 0 and 2)

        # With two guesses: A.A.. and ...B.
        constraints = parse_patterns(['A.A..', '...B.'], '')
        self.assertIn('a', constraints['doubled'])
        self.assertEqual(constraints['doubled']['a'], 2)


class TestFilterWords(unittest.TestCase):
    """Tests for filter_words constraint enforcement."""

    def test_filter_green_positions(self):
        """Test filtering by green position constraints."""
        constraints = parse_patterns(['A....'], '')
        filtered = filter_words(TEST_WORDS, constraints)
        # All words starting with 'a'
        self.assertTrue(all(w[0] == 'a' for w in filtered))
        self.assertIn('abide', filtered)
        self.assertIn('attic', filtered)

    def test_filter_yellow_positions(self):
        """Test filtering by yellow position constraints."""
        constraints = parse_patterns(['a....'], '')
        filtered = filter_words(TEST_WORDS, constraints)
        # All words containing 'a' but not at position 0
        for word in filtered:
            self.assertIn('a', word)
            self.assertNotEqual(word[0], 'a')

    def test_filter_black_letters(self):
        """Test filtering by black letter constraints."""
        constraints = parse_patterns(['.....'], 'xyz')
        filtered = filter_words(TEST_WORDS, constraints)
        # No words should contain x, y, or z
        for word in filtered:
            self.assertNotIn('x', word)
            self.assertNotIn('y', word)
            self.assertNotIn('z', word)

    def test_filter_doubled_letters_required(self):
        """Test filtering words that must have doubled letters."""
        # Pattern with 't' green at position 2 and yellow at position 3
        # This forces 't' to appear at least twice (green + yellow)
        constraints = parse_patterns(['..T.t'], '')
        filtered = filter_words(TEST_WORDS, constraints)
        # All filtered words must have at least 2 't's
        for word in filtered:
            self.assertGreaterEqual(word.count('t'), 2)
        # 'attic' has 't' twice, should be included
        self.assertIn('attic', filtered)
        # 'batch' has no 't', should be excluded
        self.assertNotIn('batch', filtered)
        # 'catch' has one 't', should be excluded
        self.assertNotIn('catch', filtered)

    def test_filter_both_green_and_yellow(self):
        """Test constraint with both green and yellow tiles."""
        # Green 'a' at position 0, yellow 't' (not at position 2)
        constraints = parse_patterns(['A.t..'], '')
        filtered = filter_words(TEST_WORDS, constraints)
        for word in filtered:
            self.assertEqual(word[0], 'a')
            self.assertIn('t', word)
            self.assertNotEqual(word[2], 't')

    def test_filter_yellow_excludes_position(self):
        """Test that yellow letter is excluded from specific positions."""
        constraints = parse_patterns(['.a...'], '')
        filtered = filter_words(TEST_WORDS, constraints)
        for word in filtered:
            self.assertIn('a', word)
            self.assertNotEqual(word[1], 'a')

    def test_filter_complex_scenario_1(self):
        """Test complex scenario: green + yellow + black."""
        # Green 'a' at position 0
        # Yellow 't' (not at position 2)
        # Black letters: b, c, d, e
        constraints = parse_patterns(['A.t..'], 'bcde')
        filtered = filter_words(TEST_WORDS, constraints)
        for word in filtered:
            self.assertEqual(word[0], 'a')
            self.assertIn('t', word)
            self.assertNotEqual(word[2], 't')
            self.assertNotIn('b', word)
            self.assertNotIn('c', word)
            self.assertNotIn('d', word)
            self.assertNotIn('e', word)

    def test_filter_excluding_all_words(self):
        """Test constraint that excludes all TEST_WORDS."""
        # Pattern requiring 'z' which is not in TEST_WORDS
        constraints = parse_patterns(['Z....'], '')
        filtered = filter_words(TEST_WORDS, constraints)
        self.assertEqual(len(filtered), 0)

    def test_filter_no_constraints(self):
        """Test with no constraints returns all words."""
        constraints = parse_patterns(['.....'], '')
        filtered = filter_words(TEST_WORDS, constraints)
        self.assertEqual(len(filtered), len(TEST_WORDS))

    def test_user_reported_issue(self):
        """
        Test the user's reported issue: `attic` should appear with patterns
        `..at.` and `ta..t` when black letters are 'slero'.

        The word `attic`:
        - Does NOT start with 't' (so passes `ta..t` with 'a' at position 1)
        - Has 'a' at position 0 (passes `.a...`)
        - Has 't' at positions 2 and 3 (passes `..t.t`)
        - Has no black letters (s, l, e, r, o)
        - Has exactly 2 't's (meets the doubled requirement inferred from
        pattern)
        """
        constraints = parse_patterns(['..at.', 'ta..t'], 'slero')

        # Verify constraints are correct
        self.assertNotIn(
            'a', constraints['doubled']
        )  # 'a' appears once per guess, not twice in one
        self.assertIn(
            't', constraints['doubled']
        )  # 't' inferred as required from pattern matching
        self.assertGreaterEqual(constraints['doubled']['t'], 2)

        filtered = filter_words(TEST_WORDS, constraints)
        self.assertIn('attic', filtered)
        self.assertIn('attap', filtered)
        self.assertNotIn('batch', filtered)
        self.assertNotIn('catch', filtered)


class TestBuildFilterRegex(unittest.TestCase):
    """Tests for regex construction."""

    def test_regex_with_green_letters(self):
        """Test regex matches green positions correctly."""
        constraints = parse_patterns(['A.B..'], '')
        regex_pattern = build_filter_regex(constraints)
        # Should match words starting with 'a' and 'b' at position 2

        pattern = re.compile(regex_pattern)
        self.assertTrue(pattern.match('aabcd'))
        self.assertFalse(pattern.match('baacd'))

    def test_regex_no_green_letters(self):
        """Test regex with no green constraints."""
        constraints = parse_patterns(['a.b..'], '')
        regex_pattern = build_filter_regex(constraints)

        pattern = re.compile(regex_pattern)
        # Should match any 5-letter word
        self.assertTrue(pattern.match('abcde'))
        self.assertTrue(pattern.match('zzzzz'))


class TestEdgeCases(unittest.TestCase):
    """Tests for edge cases and boundary conditions."""

    def test_all_same_letter(self):
        """Test word with all same letters."""
        constraints = parse_patterns(['A....'], 'bcdefghijklmnopqrstuvwxyz')
        # 'aaaaa' would match if in TEST_WORDS, but it's not
        # This just verifies the logic doesn't crash
        filtered = filter_words(TEST_WORDS, constraints)
        # Should have no words since no word in TEST_WORDS is all 'a'
        self.assertEqual(len(filtered), 0)

    def test_letter_with_high_count(self):
        """Test word with letter appearing 3+ times."""
        # Pattern with 't' appearing 3 times in one guess
        constraints = parse_patterns(['T.T.T'], '')
        filtered = filter_words(TEST_WORDS, constraints)
        # Only 'tatty' and 'eerie' etc. with 3+ of same letter
        for word in filtered:
            self.assertGreaterEqual(word.count('t'), 3)

    def test_yellow_at_multiple_positions_single_guess(self):
        """Test yellow constraint at multiple positions within one guess."""
        # 't' yellow at positions 1 and 3
        constraints = parse_patterns(['.t.t.'], '')
        filtered = filter_words(TEST_WORDS, constraints)
        for word in filtered:
            # 't' must be in the word twice, but not at positions 1 or 3
            self.assertGreaterEqual(word.count('t'), 2)
            self.assertNotEqual(word[1], 't')
            self.assertNotEqual(word[3], 't')

    def test_word_too_short(self):
        """Test that non-5-letter patterns raise error."""
        with self.assertRaises(ValueError):
            parse_patterns(['abcd'], '')

    def test_word_too_long(self):
        """Test that non-5-letter patterns raise error."""
        with self.assertRaises(ValueError):
            parse_patterns(['abcdef'], '')

    def test_invalid_character_in_pattern(self):
        """Test that invalid characters raise error."""
        with self.assertRaises(ValueError):
            parse_patterns(['ab#de'], '')


if __name__ == '__main__':
    unittest.main()
