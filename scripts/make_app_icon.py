#!/usr/bin/env python3
"""1024x1024 uygulama ikonunu üretir.

Üçüncü parti bağımlılık yok — PNG'yi elle kodluyoruz. İkonu değiştirmek
isteyince bu dosyayı düzenleyip tekrar çalıştır:

    python3 scripts/make_app_icon.py

Palet zemin kat paletidir: emaye mavi zemin, hardal kupa, boyalı duvar buharı.
"""

import math
import struct
import zlib
from pathlib import Path

SIZE = 1024
SS = 3  # süper örnekleme: kenarlar yumuşasın diye 3x çizip küçültüyoruz

ENAMEL = (0x1D, 0x5B, 0x79)
MUSTARD = (0xD9, 0xA4, 0x41)
WALL = (0xE9, 0xE4, 0xD6)
PISTACHIO = (0x4C, 0x7A, 0x55)


def blend(dst, src, alpha):
    return tuple(round(d + (s - d) * alpha) for d, s in zip(dst, src))


def build():
    n = SIZE * SS
    px = [[ENAMEL for _ in range(n)] for _ in range(n)]

    def unit(x, y):
        """Piksel merkezini 0..1 aralığına taşı."""
        return ((x + 0.5) / n, (y + 0.5) / n)

    for y in range(n):
        for x in range(n):
            u, v = unit(x, y)

            # Tabak
            if 0.732 <= v <= 0.768 and 0.20 <= u <= 0.80:
                px[y][x] = WALL
                continue

            # Kulp: sağda halka
            dx, dy = u - 0.705, v - 0.545
            r = (dx * dx + dy * dy) ** 0.5
            if 0.088 <= r <= 0.132 and u > 0.66:
                px[y][x] = MUSTARD
                continue

            # Kupa gövdesi: yukarıdan aşağı daralan yamuk
            if 0.40 <= v <= 0.735:
                t = (v - 0.40) / (0.735 - 0.40)
                half = 0.225 - 0.045 * t
                if abs(u - 0.47) <= half:
                    # Üstteki krema bandı
                    px[y][x] = WALL if v < 0.445 else MUSTARD
                    continue

            # Buhar: iki dalgalı şerit
            if 0.15 <= v <= 0.355:
                for phase, cx in ((0.0, 0.405), (math.pi, 0.535)):
                    wave = cx + 0.032 * math.sin(v * 17.5 + phase)
                    if abs(u - wave) <= 0.019:
                        px[y][x] = blend(ENAMEL, WALL, 0.55)
                        break

    # 3x -> 1x küçültme (kutu filtresi)
    out = bytearray()
    for y in range(SIZE):
        out.append(0)  # filtre baytı
        for x in range(SIZE):
            r = g = b = 0
            for sy in range(SS):
                row = px[y * SS + sy]
                for sx in range(SS):
                    c = row[x * SS + sx]
                    r += c[0]
                    g += c[1]
                    b += c[2]
            k = SS * SS
            out += bytes((r // k, g // k, b // k))
    return bytes(out)


def chunk(tag, data):
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def write_png(path, raw):
    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    Path(path).write_bytes(png)
    return len(png)


if __name__ == "__main__":
    target = Path(__file__).resolve().parent.parent / (
        "NotOnMyShift/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    )
    size = write_png(target, build())
    print(f"{target} yazıldı ({size} bayt)")
