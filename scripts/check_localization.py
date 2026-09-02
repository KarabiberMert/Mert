#!/usr/bin/env python3
"""Dil dosyalarını Strings.swift ile karşılaştırır.

Kontroller:
  - Her dilde her anahtar var mı, fazlası var mı
  - Yer tutucular (%@, %lld) her dilde aynı mı
  - Para kalıbında {amount} duruyor mu
  - Sayı yereli geçerli bir tanımlayıcı mı
  - Türkçede yer tutucuya ek yapıştırılmış mı (ünlü uyumu tuzağı)

    python3 scripts/check_localization.py
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT = ROOT / "NotOnMyShift/Support/Strings.swift"
LPROJ = ROOT / "NotOnMyShift"
SOURCE_LANGUAGE = "en"

PLACEHOLDER = re.compile(r"%(?:\d+\$)?[@a-zA-Z]+")


def swift_keys():
    """Strings.swift içindeki anahtar → varsayılan metin."""
    text = SWIFT.read_text()
    out = {}
    for match in re.finditer(
        r'String\(localized:\s*"([^"]+)"\s*,\s*defaultValue:\s*"((?:[^"\\]|\\.)*)"', text
    ):
        out[match.group(1)] = match.group(2)
    return out


def strings_file(path):
    text = path.read_text()
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    out = {}
    for match in re.finditer(r'^\s*"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', text, re.M):
        out[match.group(1)] = match.group(2)
    return out


def placeholders(value):
    """Swift interpolasyonu (\\(x)) ile .strings yer tutucusunu aynı dile indir."""
    normalised = re.sub(r"\\\([^)]*\)", "%@", value)
    found = PLACEHOLDER.findall(normalised)
    # %lld ve %@ farklı türler ama sayısı ve sırası önemli; türü normalize et
    return ["%d" if p in ("%lld", "%d", "%ld") else p for p in found]


def main():
    swift = swift_keys()
    languages = sorted(p.name.removesuffix(".lproj") for p in LPROJ.glob("*.lproj"))
    if not languages:
        return ["hiç .lproj klasörü yok"]

    print(f"Strings.swift: {len(swift)} anahtar")
    print(f"Diller: {', '.join(languages)}\n")

    problems = []
    tables = {}

    for language in languages:
        path = LPROJ / f"{language}.lproj/Localizable.strings"
        if not path.exists():
            problems.append(f"{language}: Localizable.strings yok")
            continue
        table = strings_file(path)
        tables[language] = table

        missing = sorted(set(swift) - set(table))
        extra = sorted(set(table) - set(swift))
        print(f"{language:>3}: {len(table)} anahtar", end="")
        print(f" · eksik {len(missing)} · fazla {len(extra)}")
        for key in missing:
            problems.append(f"{language}: eksik anahtar '{key}'")
        for key in extra:
            problems.append(f"{language}: Strings.swift'te olmayan anahtar '{key}'")

    # Yer tutucu tutarlılığı — kaynak dile göre
    reference = tables.get(SOURCE_LANGUAGE, swift)
    for language, table in tables.items():
        for key, value in table.items():
            if key not in reference:
                continue
            expected = placeholders(reference[key])
            actual = placeholders(value)
            if expected != actual:
                problems.append(
                    f"{language}: '{key}' yer tutucuları uyuşmuyor "
                    f"({SOURCE_LANGUAGE}={expected} vs {language}={actual})"
                )

    # Swift varsayılanları kaynak dille aynı sayıda yer tutucu taşımalı.
    # Tür karşılaştırmıyoruz: Swift tarafında yer tutucu bir interpolasyon
    # (\(count)) ve türü ancak derleyici biliyor.
    for key, value in swift.items():
        source = tables.get(SOURCE_LANGUAGE, {}).get(key)
        if source is not None and len(placeholders(value)) != len(placeholders(source)):
            problems.append(
                f"{SOURCE_LANGUAGE}: '{key}' Swift varsayılanıyla yer tutucu sayısı farklı"
            )

    # Biçim anahtarlarına özel kontroller
    for language, table in tables.items():
        pattern = table.get("format.currencyPattern", "")
        if "{amount}" not in pattern:
            problems.append(f"{language}: format.currencyPattern içinde {{amount}} yok ({pattern!r})")
        locale_id = table.get("format.numberLocale", "")
        if not re.fullmatch(r"[a-z]{2}(_[A-Z]{2})?", locale_id):
            problems.append(f"{language}: format.numberLocale geçersiz ({locale_id!r})")
        for scale in ("e3", "e6", "e9", "e12", "e15"):
            if not table.get(f"format.scale.{scale}", "").strip():
                problems.append(f"{language}: format.scale.{scale} boş")

    # Türkçe ünlü uyumu tuzağı: yer tutucuya yapışık ek
    turkish = tables.get("tr", {})
    for key, value in turkish.items():
        if re.search(r"%(?:@|lld)[a-zçğıöşü]", value):
            problems.append(
                f"tr: '{key}' yer tutucuya ek yapıştırılmış — ünlü uyumu bozulur ({value!r})"
            )

    return problems


if __name__ == "__main__":
    issues = main()
    if issues:
        print("\nSORUN:")
        for issue in issues:
            print(" -", issue)
        sys.exit(1)
    print("\nDil dosyaları tutarlı.")
