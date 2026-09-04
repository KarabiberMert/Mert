#!/usr/bin/env python3
"""Mağaza metinlerini App Store Connect sınırlarına göre doğrular.

Kaynak `docs/app-store-metadata.md`. Metni elle düzenle, sonra bunu çalıştır:
başlıktaki karakter sayısını yeniden hesaplar ve sınırı aşanı söyler.

    python3 scripts/check_store_copy.py
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOC = ROOT / "docs/app-store-metadata.md"

# App Store Connect alan sınırları.
LIMITS = {
    "App Name": 30,
    "Subtitle": 30,
    "Promotional Text": 170,
    "Keywords": 100,
    "Description": 4000,
    "What's New": 4000,
}

# "### Alt başlık (Subtitle) — 25/30" + ardından gelen ``` bloğu
SECTION = re.compile(
    r"^###\s+(?P<label>.+?)\s+—\s+(?P<used>\d+)/(?P<cap>\d+)\s*$\n\n```\n(?P<body>.*?)\n```",
    re.M | re.S,
)


def limit_for(label):
    """Başlıktaki İngilizce alan adına göre sınırı bul."""
    for field, cap in LIMITS.items():
        if field.lower() in label.lower():
            return field, cap
    return None, None


def main():
    if not DOC.exists():
        return [f"{DOC.relative_to(ROOT)} yok"]

    text = DOC.read_text(encoding="utf-8")
    # Dil başlıkları "İsim — kod" biçiminde; diğer ## bölümleri sayılmasın.
    locales = [h for h in re.findall(r"^##\s+(.+?)\s*$", text, re.M) if "—" in h]
    sections = list(SECTION.finditer(text))

    print(f"{DOC.relative_to(ROOT)}: {len(sections)} alan")
    if not sections:
        return ["hiç alan bulunamadı — başlık biçimi '### Ad (Field) — 12/30' olmalı"]

    problems = []
    for match in sections:
        label = match.group("label")
        stated = int(match.group("used"))
        stated_cap = int(match.group("cap"))
        body = match.group("body")
        actual = len(body)

        field, cap = limit_for(label)
        if field is None:
            problems.append(f"'{label}': tanınmayan alan, sınırı bilinmiyor")
            continue

        flag = " "
        if actual > cap:
            problems.append(f"'{label}': {actual}/{cap} — {actual - cap} karakter fazla")
            flag = "!"
        if stated != actual:
            problems.append(f"'{label}': başlıkta {stated} yazıyor ama metin {actual} karakter")
            flag = "!"
        if stated_cap != cap:
            problems.append(f"'{label}': başlıktaki sınır {stated_cap}, doğrusu {cap}")
            flag = "!"

        # Anahtar kelimelerde boşluk karakter israfıdır; virgül yeter.
        if field == "Keywords":
            if " " in body:
                problems.append(f"'{label}': anahtar kelimelerde boşluk var, karakter israfı")
            words = [w for w in body.split(",") if w]
            if len(words) != len(set(words)):
                problems.append(f"'{label}': aynı anahtar kelime iki kez yazılmış")

        print(f"{flag} {label:<34} {actual:>5}/{cap}")

    print(f"\nDiller: {len(locales)}")
    return problems


if __name__ == "__main__":
    issues = main()
    if issues:
        print("\nSORUN:")
        for issue in issues:
            print(" -", issue)
        sys.exit(1)
    print("Mağaza metinleri sınırların içinde.")
