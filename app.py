#!/usr/bin/env python3
"""
Wordle Solver web app — uses only Python stdlib (http.server + json).
Run: python3 app.py [port]   (default port: 5000)
"""

import json
import os
import re
import sys
import tempfile
from collections import defaultdict
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlparse

WORDS_FILE = Path(__file__).parent / 'words.txt'
TEMPLATE   = Path(__file__).parent / 'templates' / 'index.html'


# ── Word filtering logic ───────────────────────────────────────────────────────

def parse_guesses(guesses):
    green            = {}
    yellow           = defaultdict(list)
    black            = set()
    max_count        = {}
    letter_confirmed = set()
    letter_blacked   = set()
    all_guess_data   = []

    for guess in guesses:
        letters = [l.lower() for l in guess.get('letters', [])]
        colors  = guess.get('colors', [])
        if len(letters) != 5 or not all(letters):
            continue

        guess_data = []
        for pos, (letter, color) in enumerate(zip(letters, colors)):
            if color == 'green':
                green[pos] = letter
                letter_confirmed.add(letter)
                guess_data.append((letter, 'green', pos))
            elif color == 'yellow':
                yellow[letter].append(pos)
                letter_confirmed.add(letter)
                guess_data.append((letter, 'yellow', pos))
            else:
                letter_blacked.add(letter)
                guess_data.append((letter, 'black', pos))
        all_guess_data.append(guess_data)

    for letter in letter_blacked - letter_confirmed:
        black.add(letter)

    # When a letter appears as both confirmed (green/yellow) and black in the same
    # guess, the black occurrence tells us the word has no more than the confirmed
    # count of that letter. We also derive a position exclusion for each black hit.
    for guess_data in all_guess_data:
        by_letter = defaultdict(list)
        for letter, state, pos in guess_data:
            by_letter[letter].append((state, pos))
        for letter, occ in by_letter.items():
            confirmed_here = [(s, p) for s, p in occ if s != 'black']
            black_here     = [(s, p) for s, p in occ if s == 'black']
            if confirmed_here and black_here:
                for _, pos in black_here:
                    yellow[letter].append(pos)
                mx = len(confirmed_here)
                if letter not in max_count or mx < max_count[letter]:
                    max_count[letter] = mx

    doubled         = {}
    max_in_guess    = defaultdict(int)
    green_positions = defaultdict(set)

    for guess in all_guess_data:
        counts = defaultdict(int)
        for letter, state, pos in guess:
            if state in ('green', 'yellow'):
                counts[letter] += 1
            if state == 'green':
                green_positions[letter].add(pos)
        for letter, cnt in counts.items():
            if cnt > max_in_guess[letter]:
                max_in_guess[letter] = cnt

    for letter, max_single in max_in_guess.items():
        min_req = max_single
        if len(green_positions[letter]) >= 2:
            min_req = max(min_req, 2)
        if min_req >= 2:
            doubled[letter] = min_req

    return {'green': green, 'yellow': dict(yellow), 'black': black,
            'doubled': doubled, 'max_count': max_count}


def filter_words(words, c):
    pat = list('.....')
    for pos, letter in c['green'].items():
        pat[pos] = letter
    regex = re.compile('^' + ''.join(pat) + '$')

    result = []
    for word in words:
        if not regex.match(word):
            continue
        if any(ch in c['black'] for ch in word):
            continue
        ok = True
        for letter, excl in c['yellow'].items():
            if letter not in word or any(word[p] == letter for p in excl):
                ok = False
                break
        if not ok:
            continue
        for letter, mn in c['doubled'].items():
            if word.count(letter) < mn:
                ok = False
                break
        if not ok:
            continue
        for letter, mx in c.get('max_count', {}).items():
            if word.count(letter) > mx:
                ok = False
                break
        if ok:
            result.append(word)
    return result


def load_words():
    return [w.strip().lower() for w in WORDS_FILE.read_text().splitlines() if w.strip()]


# ── HTTP handler ───────────────────────────────────────────────────────────────

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f'  {self.address_string()} {fmt % args}')

    def send_json(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', len(body))
        self.end_headers()
        self.wfile.write(body)

    def send_html(self, html: bytes, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', len(html))
        self.end_headers()
        self.wfile.write(html)

    def read_json_body(self):
        length = int(self.headers.get('Content-Length', 0))
        return json.loads(self.rfile.read(length))

    def do_GET(self):
        path = urlparse(self.path).path
        if path in ('/', '/index.html'):
            self.send_html(TEMPLATE.read_bytes())
        else:
            self.send_html(b'Not found', 404)

    def do_POST(self):
        path = urlparse(self.path).path

        if path == '/api/filter':
            data    = self.read_json_body()
            guesses = data.get('guesses', [])
            words   = load_words()
            has_input = any(any(l for l in g.get('letters', [])) for g in guesses)
            if not has_input:
                return self.send_json({'words': sorted(words), 'count': len(words)})
            constraints = parse_guesses(guesses)
            filtered    = filter_words(words, constraints)
            self.send_json({'words': sorted(filtered), 'count': len(filtered)})

        elif path == '/api/remove':
            data      = self.read_json_body()
            to_remove = {w.lower() for w in data.get('words', [])}
            words     = load_words()
            remaining = [w for w in words if w not in to_remove]
            removed   = len(words) - len(remaining)
            tmp_fd, tmp_path = tempfile.mkstemp(dir=WORDS_FILE.parent, text=True)
            try:
                with os.fdopen(tmp_fd, 'w') as f:
                    f.write('\n'.join(remaining) + '\n')
                os.replace(tmp_path, WORDS_FILE)
            except Exception:
                try:
                    os.unlink(tmp_path)
                except OSError:
                    pass
                raise
            self.send_json({'removed': removed, 'remaining': len(remaining)})

        else:
            self.send_html(b'Not found', 404)


# ── Entry point ────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5000
    server = HTTPServer(('0.0.0.0', port), Handler)
    print(f'Wordle Solver running at  http://localhost:{port}/')
    print('Press Ctrl-C to stop.')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nStopped.')
