#!/usr/bin/env python3
"""Generate icon-192.png and icon-512.png using only Python stdlib."""
import struct, zlib

BG = (83, 141, 78)    # #538d4e  Wordle green
FG = (255, 255, 255)  # white letter

# Pixel-art W: 1=letter, 0=background (9 cols × 7 rows)
W_GLYPH = [
    [1,1,0,0,0,0,0,1,1],
    [1,1,0,0,0,0,0,1,1],
    [1,1,0,0,1,0,0,1,1],
    [1,1,0,1,1,1,0,1,1],
    [1,1,1,1,0,1,1,1,1],
    [1,1,1,0,0,0,1,1,1],
    [1,1,0,0,0,0,0,1,1],
]
GLYPH_COLS = len(W_GLYPH[0])
GLYPH_ROWS = len(W_GLYPH)


def pixel_color(x, y, size):
    pad = size // 8
    glyph_w = size - 2 * pad
    glyph_h = size - 2 * pad
    lx = x - pad
    ly = y - pad
    if lx < 0 or ly < 0 or lx >= glyph_w or ly >= glyph_h:
        return BG
    col = int(lx * GLYPH_COLS / glyph_w)
    row = int(ly * GLYPH_ROWS / glyph_h)
    col = min(col, GLYPH_COLS - 1)
    row = min(row, GLYPH_ROWS - 1)
    return FG if W_GLYPH[row][col] else BG


def make_png(size):
    def chunk(tag, data):
        crc = zlib.crc32(tag + data) & 0xffffffff
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', crc)

    raw = bytearray()
    for y in range(size):
        raw.append(0)  # PNG filter type None
        for x in range(size):
            raw += bytes(pixel_color(x, y, size))

    ihdr = struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0)
    return (
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', ihdr)
        + chunk(b'IDAT', zlib.compress(bytes(raw)))
        + chunk(b'IEND', b'')
    )


for size in [192, 512]:
    data = make_png(size)
    fname = f'icon-{size}.png'
    with open(fname, 'wb') as f:
        f.write(data)
    print(f'{fname}  {len(data):,} bytes')
