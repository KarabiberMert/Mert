#!/usr/bin/env python3
"""Maket üreticinin girdileri — hepsi kaynak dosyalardan okunur.

Sayıları elle kopyalamıyoruz: palet `Palette.swift`'ten, ölçüler
`FloorGeometry.swift`'ten, metinler `.lproj` dosyalarından, rakamlar
`balance.json`'dan geliyor. Kod değişince maket de değişir; sessizce
ayrılamaz.
"""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SUPPORT = ROOT / "NotOnMyShift/Support"
BUILDING = ROOT / "NotOnMyShift/Views/Building"


# --- Palet ---------------------------------------------------------------

def _hex_to_rgb(value):
    return ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)


def _blend(a, b, amount):
    t = min(max(amount, 0.0), 1.0)
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


class Palette:
    """`Palette.swift` içindeki tonlar ve `FloorPalette`'in karışımları."""

    def __init__(self):
        text = (SUPPORT / "Palette.swift").read_text()
        self.tones = {
            name: _hex_to_rgb(int(value, 16))
            for name, value in re.findall(r"static let (\w+Tone) = Tone\(0x([0-9A-Fa-f]+)\)", text)
        }
        # FloorPalette'in her alanı: mix(sıcak, soğuk)
        self._mixes = {}
        for name, expr in re.findall(r"var (\w+): Color \{ mix\((.+?)\) \}", text):
            warm, cool = self._split_arguments(expr)
            self._mixes[name] = (warm, cool)
        self._plain = dict(
            re.findall(r"static (?:let|var) (\w+): Color \{ Color\(\.(\w+)\) \}", text)
        )

    @staticmethod
    def _split_arguments(expr):
        """Üst seviyedeki virgülden ikiye böl — iç içe parantezleri koru."""
        depth = 0
        for index, char in enumerate(expr):
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
            elif char == "," and depth == 0:
                return expr[:index].strip(), expr[index + 1:].strip()
        raise ValueError(f"iki argüman bekleniyordu: {expr!r}")

    def _evaluate(self, expr):
        """`Palette.xTone`, `Tone(0x…)` ve `.blended(to:_:)` zincirini çöz."""
        expr = expr.strip()
        blended = re.match(r"^(.*)\.blended\(to: (.*), ([0-9.]+)\)$", expr)
        if blended:
            base = self._evaluate(blended.group(1))
            other = self._evaluate(blended.group(2))
            return _blend(base, other, float(blended.group(3)))
        literal = re.match(r"^Tone\(0x([0-9A-Fa-f]+)\)$", expr)
        if literal:
            return _hex_to_rgb(int(literal.group(1), 16))
        name = expr.removeprefix("Palette.")
        if name not in self.tones:
            raise KeyError(f"tanınmayan ton: {expr!r}")
        return self.tones[name]

    def tone(self, name):
        return self.tones[f"{name}Tone"]

    def floor(self, index, planned_floors):
        """`FloorPalette(floor:plannedFloors:)` ile aynı hesap."""
        top = max(1, planned_floors - 1)
        coolness = min(max(index / top, 0.0), 1.0)
        out = {}
        for name, (warm, cool) in self._mixes.items():
            out[name] = _blend(self._evaluate(warm), self._evaluate(cool), coolness)
        out["ownerApron"] = self.tone("mustard")
        out["coolness"] = coolness
        return out


# --- Ölçüler -------------------------------------------------------------

class Geometry:
    """`FloorGeometry.swift` içindeki 0..1 normalize sabitler."""

    def __init__(self):
        text = (BUILDING / "FloorGeometry.swift").read_text()
        self.groups = {}
        for block in re.finditer(r"(?:struct|enum)\s+(\w+)[^{]*\{(.*?)\n\}", text, re.S):
            name, body = block.group(1), block.group(2)
            values = {
                key: float(value)
                for key, value in re.findall(r"static let (\w+)(?::\s*CGFloat)?\s*=\s*([0-9.]+)", body)
            }
            self.groups[name] = values
        # Başka bir gruba işaret eden sabitler (InvestmentGeometry.shutterTop gibi)
        for block in re.finditer(r"(?:struct|enum)\s+(\w+)[^{]*\{(.*?)\n\}", text, re.S):
            name, body = block.group(1), block.group(2)
            # Büyük harfle başlayan tip adı: `0.0` gibi sayılar eşleşmesin.
            for key, group, field in re.findall(r"static let (\w+)\s*=\s*([A-Z]\w+)\.(\w+)", body):
                self.groups[name][key] = self.groups[group][field]

    def __call__(self, group, key):
        return self.groups[group][key]


# --- Metinler ------------------------------------------------------------

def strings(language):
    """Bir dilin `Localizable.strings` tablosu."""
    path = ROOT / f"NotOnMyShift/{language}.lproj/Localizable.strings"
    text = re.sub(r"/\*.*?\*/", "", path.read_text(), flags=re.S)
    table = {}
    for key, value in re.findall(r'^\s*"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', text, re.M):
        table[key] = value.replace('\\"', '"').replace("\\n", "\n")
    return table


def balance():
    return json.loads((ROOT / "NotOnMyShift/Resources/balance.json").read_text())


# --- Para biçimi ---------------------------------------------------------

# `Money.number` yereli ondalık ayracı için kullanıyor; burada aynı sonucu
# küçük bir tabloyla veriyoruz (Foundation yok).
_DECIMAL = {"en_US": ".", "tr_TR": ",", "es_ES": ","}
_THRESHOLDS = [(1e15, "format.scale.e15"), (1e12, "format.scale.e12"),
               (1e9, "format.scale.e9"), (1e6, "format.scale.e6"), (1e3, "format.scale.e3")]


def _fraction(digits, value, separator):
    """`Money.fraction`: sabit hane, gruplama yok."""
    return f"{value:.{digits}f}".replace(".", separator)


def money(amount, table, precise=False):
    """`Money.text` / `Money.preciseText` ile aynı sonucu verir.

    Kural motorun kendisiyle aynı: 100'ün altında bir hane ondalık, üstünde
    tam sayı; kısaltma gövdeye boşluksuz eklenir; simge ve yeri kalıptan gelir.
    """
    separator = _DECIMAL.get(table.get("format.numberLocale", ""), ".")
    pattern = table.get("format.currencyPattern", "{amount}")
    magnitude = abs(amount)
    sign = "-" if amount < 0 else ""

    if precise and magnitude < 100:
        return sign + pattern.replace("{amount}", _fraction(1, magnitude, separator))

    for size, key in _THRESHOLDS:
        if magnitude >= size:
            scaled = magnitude / size
            body = (_fraction(1, scaled, separator) if scaled < 100
                    else _fraction(0, int(scaled), separator))
            return sign + pattern.replace("{amount}", body + table.get(key, ""))

    return sign + pattern.replace("{amount}", _fraction(0, int(magnitude), separator))


# --- Süre biçimi ---------------------------------------------------------

# `DurationText` bunu `Duration.UnitsFormatStyle(width: .wide)`'a bırakıyor.
# Burada aynı sonucu veren küçük bir tablo — tekil/çoğul dahil.
_UNITS = {
    "en_US": {"minute": ("minute", "minutes"), "hour": ("hour", "hours"), "day": ("day", "days")},
    "tr_TR": {"minute": ("dakika", "dakika"), "hour": ("saat", "saat"), "day": ("gün", "gün")},
    "es_ES": {"minute": ("minuto", "minutos"), "hour": ("hora", "horas"), "day": ("día", "días")},
}


def duration(seconds, table):
    """"30 minutes" · "30 dakika" · "30 minutos"."""
    units = _UNITS.get(table.get("format.numberLocale", ""), _UNITS["en_US"])
    for size, key in ((86400, "day"), (3600, "hour"), (60, "minute")):
        if seconds >= size:
            count = int(seconds // size)
            singular, plural = units[key]
            return f"{count} {singular if count == 1 else plural}"
    return f"{int(seconds)} {units['minute'][1]}"


if __name__ == "__main__":
    palette = Palette()
    geometry = Geometry()
    print(f"ton: {len(palette.tones)} · karışım: {len(palette._mixes)}")
    print("zemin kat paleti:", {k: v for k, v in list(palette.floor(0, 8).items())[:4]})
    print("üst kat paleti  :", {k: v for k, v in list(palette.floor(3, 8).items())[:4]})
    print("ölçü grupları:", {k: len(v) for k, v in geometry.groups.items()})
    for language in ("en", "tr", "es"):
        table = strings(language)
        print(f"{language}: {len(table)} anahtar · 4 → {money(4, table)} · "
              f"1234 → {money(1234, table)} · {money(1_250_000, table)} · "
              f"oran {money(1.38, table, precise=True)} · "
              f"{duration(1800, table)} · {duration(3600, table)}")
