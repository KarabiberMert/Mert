#!/usr/bin/env python3
"""Mağaza metinlerini karakter sınırlarına göre doğrular.

İki kaynak var:
  - `docs/app-store-metadata.md`  → App Store Connect alanları
  - `docs/app-store-screenshots.md` → ekran görüntüsü başlık ve alt satırları

Metni elle düzenle, sonra bunu çalıştır: yazılı karakter sayısını yeniden
hesaplar ve sınırı aşanı söyler.

    python3 scripts/check_store_copy.py
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOC = ROOT / "docs/app-store-metadata.md"
SHOTS = ROOT / "docs/app-store-screenshots.md"

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


# "| en-US | Başlık `29` | Alt satır `45` |"
SHOT_ROW = re.compile(
    r"^\|\s*(?P<lang>en-US|tr|es-ES)\s*\|"
    r"\s*(?P<head>.+?)\s*`(?P<head_len>\d+)`\s*\|"
    r"\s*(?P<sub>.+?)\s*`(?P<sub_len>\d+)`\s*\|\s*$",
    re.M,
)
# "| Dil | Başlık (≤32) | Alt satır (≤60) |"
SHOT_CAPS = re.compile(r"Başlık\s*\(≤(?P<head>\d+)\).*?Alt satır\s*\(≤(?P<sub>\d+)\)")


def check_screenshots():
    """Ekran görüntüsü metinleri. Sınırlar dosyanın kendi tablo başlığından."""
    if not SHOTS.exists():
        return [f"{SHOTS.relative_to(ROOT)} yok"]

    text = SHOTS.read_text(encoding="utf-8")
    caps = SHOT_CAPS.search(text)
    if caps is None:
        return ["ekran görüntüsü tablosunun başlığında sınır yazmıyor"]
    head_cap, sub_cap = int(caps.group("head")), int(caps.group("sub"))

    rows = list(SHOT_ROW.finditer(text))
    shots = len(re.findall(r"^##\s+\d+\.", text, re.M))
    print(f"\n{SHOTS.relative_to(ROOT)}: {shots} kare · {len(rows)} satır "
          f"(başlık ≤{head_cap}, alt ≤{sub_cap})")
    if not rows:
        return ["hiç ekran görüntüsü satırı bulunamadı"]

    problems = []
    for row in rows:
        for part, cap in (("head", head_cap), ("sub", sub_cap)):
            body = row.group(part)
            stated = int(row.group(f"{part}_len"))
            actual = len(body)
            where = f"{row.group('lang')} · {'başlık' if part == 'head' else 'alt satır'}"
            if actual > cap:
                problems.append(f"{where}: {actual}/{cap} — {actual - cap} fazla ({body!r})")
            if stated != actual:
                problems.append(f"{where}: yazıda {stated} ama metin {actual} karakter ({body!r})")

    if 3 * shots != len(rows):
        problems.append(f"{shots} kare için {len(rows)} satır var, 3 dil × {shots} = {3 * shots} olmalı")
    return problems


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
    return problems + check_screenshots()


if __name__ == "__main__":
    issues = main()
    if issues:
        print("\nSORUN:")
        for issue in issues:
            print(" -", issue)
        sys.exit(1)
    print("\nMağaza metinleri sınırların içinde.")
