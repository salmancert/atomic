#!/usr/bin/env python3
"""Generates the app icon: a broken orbit around a dark core.

Pure standard library so it runs anywhere, and checked in alongside the PNG it
produces so the icon can be regenerated rather than hand-edited.
"""
import math
import struct
import sys
import zlib

SIZE = 1024
BG_TOP = (18, 24, 38)
BG_BOTTOM = (36, 52, 84)
RING = (94, 214, 190)
ACCENT = (255, 138, 96)


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def pixel(x, y):
    cx = cy = SIZE / 2
    dx, dy = x - cx, y - cy
    distance = math.hypot(dx, dy)
    angle = math.degrees(math.atan2(dy, dx)) % 360

    colour = lerp(BG_TOP, BG_BOTTOM, y / SIZE)

    # Orbit, with a gap where the atom broke out: the habit loop, interrupted.
    outer, inner = SIZE * 0.36, SIZE * 0.30
    if inner <= distance <= outer and not (288 <= angle <= 342):
        colour = RING

    # The core.
    if distance <= SIZE * 0.11:
        colour = ACCENT

    # The atom that escaped the loop.
    if math.hypot(x - cx * 1.47, y - cy * 0.53) <= SIZE * 0.055:
        colour = ACCENT

    return colour


def main(path):
    rows = bytearray()
    for y in range(SIZE):
        rows.append(0)  # filter type: none
        for x in range(SIZE):
            rows.extend(pixel(x, y))

    def chunk(kind, payload):
        data = kind + payload
        return struct.pack(">I", len(payload)) + data + struct.pack(">I", zlib.crc32(data))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    png += chunk(b"IEND", b"")

    with open(path, "wb") as handle:
        handle.write(png)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
