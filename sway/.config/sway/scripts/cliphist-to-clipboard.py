#!/usr/bin/env python3
"""Read cliphist-decoded bytes from stdin, normalize, and push to wl-copy.

Handles:
  - UTF-16 (LE/BE, with or without BOM) → UTF-8 text/plain
  - PNG/JPEG/GIF/WEBP → image/* with correct MIME
  - Everything else → pass through (prefer text/plain if valid UTF-8)
"""

from __future__ import annotations

import subprocess
import sys


def is_utf16_le_text(data: bytes) -> bool:
    if len(data) < 4 or len(data) % 2 != 0:
        return False
    sample = data[: min(len(data), 400)]
    pairs = len(sample) // 2
    if pairs == 0:
        return False
    odd_nulls = sum(1 for i in range(1, len(sample), 2) if sample[i] == 0)
    even_nulls = sum(1 for i in range(0, len(sample), 2) if sample[i] == 0)
    # Typical ASCII/Latin stored as UTF-16-LE: high byte is 0
    return (odd_nulls / pairs) >= 0.7 and (even_nulls / pairs) <= 0.25


def is_utf16_be_text(data: bytes) -> bool:
    if len(data) < 4 or len(data) % 2 != 0:
        return False
    sample = data[: min(len(data), 400)]
    pairs = len(sample) // 2
    if pairs == 0:
        return False
    even_nulls = sum(1 for i in range(0, len(sample), 2) if sample[i] == 0)
    odd_nulls = sum(1 for i in range(1, len(sample), 2) if sample[i] == 0)
    return (even_nulls / pairs) >= 0.7 and (odd_nulls / pairs) <= 0.25


def detect_image_mime(data: bytes) -> str | None:
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if data[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if data[:6] in (b"GIF87a", b"GIF89a"):
        return "image/gif"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    if data[:2] == b"BM":
        return "image/bmp"
    return None


def normalize(data: bytes) -> tuple[bytes, str]:
    if not data:
        return data, "text/plain;charset=utf-8"

    img = detect_image_mime(data)
    if img:
        return data, img

    # UTF-16 with BOM
    if data.startswith(b"\xff\xfe"):
        return data.decode("utf-16-le").encode("utf-8"), "text/plain;charset=utf-8"
    if data.startswith(b"\xfe\xff"):
        return data.decode("utf-16-be").encode("utf-8"), "text/plain;charset=utf-8"

    # UTF-16 without BOM (common for some browser / Electron copies)
    if is_utf16_le_text(data):
        try:
            text = data.decode("utf-16-le")
            # Drop trailing NULs sometimes present
            text = text.rstrip("\x00")
            return text.encode("utf-8"), "text/plain;charset=utf-8"
        except UnicodeDecodeError:
            pass
    if is_utf16_be_text(data):
        try:
            text = data.decode("utf-16-be").rstrip("\x00")
            return text.encode("utf-8"), "text/plain;charset=utf-8"
        except UnicodeDecodeError:
            pass

    # Valid UTF-8 text?
    try:
        data.decode("utf-8")
        return data, "text/plain;charset=utf-8"
    except UnicodeDecodeError:
        pass

    return data, "application/octet-stream"


def main() -> int:
    data = sys.stdin.buffer.read()
    out, mime = normalize(data)

    try:
        subprocess.run(
            ["wl-copy", "--type", mime],
            input=out,
            check=True,
        )
    except FileNotFoundError:
        print("wl-copy not found", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as e:
        print(f"wl-copy failed: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
