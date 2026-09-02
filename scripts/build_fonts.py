#!/usr/bin/env python3
"""Archivo değişken fontundan oyunun iki başlık kesitini üretir.

Neden değişken fontu doğrudan paketlemiyoruz: iOS değişken fontun adlandırılmış
örneklerini güvenilir biçimde açmıyor. Onun yerine istediğimiz genişlik/ağırlık
noktalarını sabitleyip iki statik TTF çıkarıyoruz.

Gerekenler:
    pip install fonttools
    curl -o /tmp/Archivo-var.ttf \
      'https://raw.githubusercontent.com/google/fonts/main/ofl/archivo/Archivo%5Bwdth,wght%5D.ttf'

Sonra:
    python3 scripts/build_fonts.py

Archivo, SIL Open Font License 1.1 ile lisanslı.
Lisans metni NotOnMyShift/Resources/Fonts/OFL.txt içinde durur ve silinmemelidir.
"""

import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "NotOnMyShift/Resources/Fonts"
SOURCE = Path("/tmp/Archivo-var.ttf")

# Zemin katın başlık sesi: sıkışık ama boğuk değil.
WIDTH = 79

CUTS = [
    {
        "file": "ArchivoCond-SemiBold.ttf",
        "weight": 600,
        "family": "Archivo Cond SemiBold",
        "postscript": "ArchivoCond-SemiBold",
    },
    {
        "file": "ArchivoCond-Medium.ttf",
        "weight": 500,
        "family": "Archivo Cond Medium",
        "postscript": "ArchivoCond-Medium",
    },
]

# Latin + Latin Ext A/B (Türkçe buradan), birleştirici işaretler, noktalama,
# para birimleri (₺ dahil), matematik işaretleri.
UNICODES = "U+0000-024F,U+0259,U+0300-036F,U+2000-206F,U+2070-209F,U+20A0-20BF,U+2116,U+2122,U+2212"

# Oyunda kullanılan Türkçe glifler — üretimden sonra doğrulanır.
TURKISH = "ığüşöçİĞÜŞÖÇıâÂ₺"


def set_names(font, family, postscript):
    """iOS PostScript adıyla arar; adlandırmayı tek bir aileye sabitliyoruz."""
    name = font["name"]
    for platform_id, encoding_id, language_id in ((3, 1, 0x409), (1, 0, 0)):
        for name_id, value in (
            (1, family),        # aile
            (2, "Regular"),     # alt aile
            (3, f"{family}; NotOnMyShift"),
            (4, family),        # tam ad
            (6, postscript),    # PostScript adı — kodda bunu kullanıyoruz
            (16, family),
            (17, "Regular"),
        ):
            name.setName(value, name_id, platform_id, encoding_id, language_id)


def build(cut):
    font = TTFont(SOURCE)
    instancer.instantiateVariableFont(
        font, {"wght": cut["weight"], "wdth": WIDTH}, inplace=True, updateFontNames=False
    )

    set_names(font, cut["family"], cut["postscript"])

    os2 = font["OS/2"]
    os2.usWeightClass = cut["weight"]
    os2.usWidthClass = 3            # condensed
    os2.fsSelection = (os2.fsSelection & ~0b1100001) | 0b1000000  # sadece REGULAR
    font["head"].macStyle = 0

    if "DSIG" in font:              # değişiklikten sonra imza geçersiz
        del font["DSIG"]

    options = subset.Options()
    options.layout_features = ["kern", "liga", "ccmp", "locl", "mark", "mkmk", "tnum", "case"]
    options.name_IDs = ["*"]
    options.name_legacy = True
    options.name_languages = ["*"]
    options.notdef_outline = True
    options.recalc_bounds = True
    options.drop_tables += ["FFTM"]
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=subset.parse_unicodes(UNICODES))
    subsetter.subset(font)

    target = OUT / cut["file"]
    font.save(target)
    return target


def verify(path, cut):
    font = TTFont(path)
    cmap = font.getBestCmap()
    missing = [c for c in TURKISH if ord(c) not in cmap]

    features = set()
    for tag in ("GSUB", "GPOS"):
        if tag in font:
            for record in font[tag].table.FeatureList.FeatureRecord:
                features.add(record.FeatureTag)

    postscript = font["name"].getDebugName(6)
    size_kb = path.stat().st_size / 1024

    ok = not missing and "tnum" in features and postscript == cut["postscript"]
    print(f"  {path.name:<28} {size_kb:6.1f} KB  PS={postscript}")
    print(f"    Türkçe eksik glif: {missing or 'yok'}")
    print(f"    tnum (tabular figür): {'var' if 'tnum' in features else 'YOK'}")
    return ok


def main():
    if not SOURCE.exists():
        sys.exit(f"Kaynak font yok: {SOURCE}\nDosya başındaki curl komutunu çalıştır.")
    OUT.mkdir(parents=True, exist_ok=True)

    print("Kesitler üretiliyor (wdth=%d):" % WIDTH)
    all_ok = True
    for cut in CUTS:
        path = build(cut)
        all_ok &= verify(path, cut)

    if not all_ok:
        sys.exit("\nDoğrulama başarısız — bu fontlar paketlenmemeli.")
    print("\nİki kesit de temiz.")


if __name__ == "__main__":
    main()
