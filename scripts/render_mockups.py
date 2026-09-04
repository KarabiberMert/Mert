#!/usr/bin/env python3
"""Mağaza kareleri için oyun ekranı maketleri üretir.

**Bu gerçek bir ekran görüntüsü değil.** Konteynerde Swift ve simülatör yok;
burada üretilen kareler kompozisyonu görmek ve mağaza çerçevesini hazırlamak
içindir. Mağazaya yüklenecek görüntüler Xcode'da gerçek uygulamadan alınmalı.

Yine de maket uydurma değil: ölçüler `FloorGeometry.swift`'ten, palet
`Palette.swift`'ten, metinler `.lproj` dosyalarından, rakamlar
`balance.json`'dan, tipografi paketteki Archivo kesitlerinden geliyor.

    python3 scripts/render_mockups.py            # üç dil, altı kare
    python3 scripts/render_mockups.py --lang tr  # tek dil
"""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import mockup_sources as src

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build/mockups"
FONTS = ROOT / "NotOnMyShift/Resources/Fonts"
# Gövde metni sistem fontu; burada yerine geçen en yakın açık font.
BODY_FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

# iPhone 6,9" — mantıksal nokta ve mağazanın istediği piksel.
POINTS = (440, 956)
SCALE = 3
SAFE_TOP, SAFE_BOTTOM = 59, 34

PALETTE = src.Palette()
GEO = src.Geometry()
BALANCE = src.balance()
PLANNED_FLOORS = BALANCE["building"]["paletteFloors"]


def g(group, key):
    return GEO(group, key)


class Canvas:
    """Mantıksal noktayla çizen tuval. Ölçek tek yerde uygulanır."""

    def __init__(self, width, height, background):
        self.scale = SCALE
        self.image = Image.new("RGB", (width * SCALE, height * SCALE), background)
        self.draw = ImageDraw.Draw(self.image)
        self._fonts = {}

    def font(self, kind, size):
        key = (kind, round(size, 1))
        if key not in self._fonts:
            files = {
                "display": FONTS / "ArchivoCond-SemiBold.ttf",
                "money": FONTS / "ArchivoCond-SemiBold.ttf",
                "label": FONTS / "ArchivoCond-Medium.ttf",
                "body": BODY_FONT,
            }
            self._fonts[key] = ImageFont.truetype(str(files[kind]), max(1, int(size * SCALE)))
        return self._fonts[key]

    def rect(self, box, fill=None, outline=None, width=1, radius=0):
        x0, y0, x1, y1 = (v * self.scale for v in box)
        if radius:
            self.draw.rounded_rectangle(
                [x0, y0, x1, y1], radius=radius * self.scale,
                fill=fill, outline=outline, width=max(1, int(width * self.scale)),
            )
        else:
            self.draw.rectangle([x0, y0, x1, y1], fill=fill, outline=outline,
                                width=max(1, int(width * self.scale)))

    def ellipse(self, box, fill=None):
        self.draw.ellipse([v * self.scale for v in box], fill=fill)

    def text(self, position, body, kind, size, fill, anchor="la", max_width=None):
        font = self.font(kind, size)
        if max_width is not None:
            while size > 6 and self.width(body, kind, size) > max_width:
                size -= 0.5
                font = self.font(kind, size)
        self.draw.text([v * self.scale for v in position], body, font=font, fill=fill, anchor=anchor)
        return size

    def width(self, body, kind, size):
        box = self.draw.textbbox((0, 0), body, font=self.font(kind, size))
        return (box[2] - box[0]) / self.scale


# --- Kat bandı (FloorScene'in aynısı) ------------------------------------

class Band:
    """Bir kat bandının kutusu. `FloorGeometry` ile aynı dönüşümler."""

    def __init__(self, x0, y0, x1, y1):
        self.x0, self.y0, self.x1, self.y1 = x0, y0, x1, y1
        self.w = x1 - x0
        self.h = y1 - y0

    def x(self, v): return self.x0 + self.w * v
    def y(self, v): return self.y0 + self.h * v
    def hh(self, v): return self.h * v
    def box(self, a, b, c, d): return (self.x(a), self.y(b), self.x(c), self.y(d))

    def unit(self, index, count):
        total = max(1, count)
        left = self.x(g("FloorGeometry", "interiorLeft"))
        span = self.w * (g("FloorGeometry", "interiorRight") - g("FloorGeometry", "interiorLeft"))
        width = span / total
        return Unit(self, left + width * min(max(index, 0), total - 1), width)


class Unit:
    def __init__(self, band, min_x, width):
        self.band, self.min_x, self.w = band, min_x, width

    def x(self, v): return self.min_x + self.w * v
    def y(self, v): return self.band.y(v)
    def box(self, a, b, c, d): return (self.x(a), self.y(b), self.x(c), self.y(d))

    @staticmethod
    def slot_center(index, count):
        left, right = g("UnitGeometry", "slotLeft"), g("UnitGeometry", "slotRight")
        if count <= 0:
            return (left + right) / 2
        step = (right - left) / count
        return left + step * (index + 0.5)


SKIN = [(0xDE, 0xB2, 0x8D), (0xC4, 0x94, 0x70), (0xEE, 0xCD, 0xB0), (0xAC, 0x7C, 0x5C)]


def draw_figure(c, band, unit, center_x, apron, skin, scale=1.0):
    """Tezgâhın arkasındaki kişi. Dikey ölçüler banttan, yatay hücreden."""
    body_h = band.hh(g("FloorGeometry", "figureBodyHeight")) * scale
    body_w = body_h * g("FloorGeometry", "figureWidthRatio")
    head_r = band.hh(g("FloorGeometry", "figureHeadRatio")) * scale * 0.5
    feet = band.y(g("FloorGeometry", "floorY"))
    cx = unit.x(center_x)
    c.rect((cx - body_w / 2, feet - body_h, cx + body_w / 2, feet), fill=apron,
           radius=body_w * 0.32)
    c.ellipse((cx - head_r, feet - body_h - head_r * 1.7, cx + head_r, feet - body_h + head_r * 0.3),
              fill=skin)


def draw_floor_band(c, band, palette, sector, unit_count, is_ground, staff, owner, table):
    """`FloorScene.drawBack` + kadro + `drawFront`."""
    fg = lambda k: g("FloorGeometry", k)
    # Duvar ve kabuk
    c.rect(band.box(0, 0, 1, 1), fill=palette["frame"])
    c.rect(band.box(fg("interiorLeft"), fg("slabBottom"), fg("interiorRight"), 1),
           fill=palette["wall"])
    if is_ground:
        # Tente: fistolu, döşemenin yerine geçer.
        c.rect(band.box(0, fg("slabTop"), 1, fg("awningBottom")), fill=palette["frame"])
        stripes = int(g("FloorGeometry", "awningStripes"))
        step = band.w / stripes
        for i in range(stripes):
            if i % 2:
                c.rect((band.x0 + step * i, band.y(fg("slabTop")),
                        band.x0 + step * (i + 1), band.y(fg("awningBottom"))),
                       fill=palette["frameDeep"])
    else:
        c.rect(band.box(0, fg("slabTop"), 1, fg("slabBottom")), fill=palette["frame"])

    # Çini lambri
    c.rect(band.box(fg("interiorLeft"), fg("tileTop"), fg("interiorRight"), fg("tileBottom")),
           fill=palette["tileField"])
    c.rect((band.x(fg("interiorLeft")), band.y(fg("tileTop")),
            band.x(fg("interiorRight")), band.y(fg("tileTop")) + band.hh(0.012)),
           fill=palette["tileEdge"])

    # Tabela — metin dil dosyasından, göründüğü hâliyle.
    plate = band.box(0.045, fg("signTop"), 0.46, fg("signBottom"))
    c.rect(plate, fill=palette["sign"], radius=band.hh(0.035))
    inset = band.hh(0.030)
    c.rect((plate[0] + inset, plate[1] + inset, plate[2] - inset, plate[3] - inset),
           outline=palette["signText"], width=band.hh(0.016), radius=band.hh(0.018))
    sign_text = table.get(f"sector.{sector}.sign", sector.upper())
    c.text(((plate[0] + plate[2]) / 2, (plate[1] + plate[3]) / 2), sign_text,
           "display", band.hh(0.135), palette["signText"], anchor="mm",
           max_width=(plate[2] - plate[0] - inset * 2) * 0.86)

    # Zemin
    c.rect(band.box(fg("interiorLeft"), fg("floorY"), fg("interiorRight"), fg("bandBottom")),
           fill=palette["ground"])

    # Hücreler: bölme + duvar demirbaşı
    for index in range(max(1, unit_count)):
        unit = band.unit(index, unit_count)
        if index > 0:
            c.rect((unit.x(-0.012), unit.y(fg("tileTop")), unit.x(0.012), unit.y(fg("bandBottom"))),
                   fill=palette["frameDeep"])
        draw_wall_fitting(c, band, unit, palette, sector)

    # Kadro
    capacity = max(1, int(band.unit(0, unit_count).w / g("FloorGeometry", "pointsPerFigure")) - 1)
    visible = min(staff, capacity)
    owner_in_row = owner and (visible < capacity or staff == 0)
    total = max(1, visible + (1 if owner_in_row else 0))
    for index in range(max(1, unit_count)):
        unit = band.unit(index, unit_count)
        for slot in range(visible):
            draw_figure(c, band, unit, Unit.slot_center(slot, total),
                        palette["apron"] if slot % 2 == 0 else palette["apronAlt"],
                        SKIN[slot % len(SKIN)])
        if owner_in_row and index == 0:
            draw_figure(c, band, unit, Unit.slot_center(visible, total),
                        palette["ownerApron"], SKIN[0])

    # Tezgâh ve üstündekiler
    for index in range(max(1, unit_count)):
        unit = band.unit(index, unit_count)
        ug = lambda k: g("UnitGeometry", k)
        c.rect(unit.box(ug("counterLeft"), fg("counterTop"), ug("counterRight"), fg("floorY")),
               fill=palette["counter"])
        c.rect(unit.box(ug("counterLeft"), fg("counterTop"), ug("counterRight"),
                        fg("counterSlabBottom")), fill=palette["counterTop"])
        draw_counter_fitting(c, band, unit, palette, sector)


def draw_wall_fitting(c, band, unit, palette, sector):
    """`SectorFittings` — kata kimliğini veren iki çizimden duvarda olanı."""
    fg = lambda k: g("FloorGeometry", k)
    left, right = g("UnitGeometry", "fittingLeft"), g("UnitGeometry", "fittingRight")
    if sector == "coffee":
        for row in range(2):
            top = fg("tileTop") + 0.045 + row * 0.085
            c.rect(unit.box(left, top, right, top + 0.020), fill=palette["fixtureDeep"])
            for cup in range(3):
                span = (right - left) / 3
                cx = left + span * (cup + 0.5)
                c.rect(unit.box(cx - span * 0.22, top - 0.045, cx + span * 0.22, top),
                       fill=palette["signText"], radius=band.hh(0.010))
    else:
        c.rect(unit.box(left, fg("tileTop") + 0.030, right, fg("tileBottom") - 0.010),
               fill=palette["fixture"], radius=band.hh(0.020))
        for shelf in range(2):
            top = fg("tileTop") + 0.075 + shelf * 0.075
            c.rect(unit.box(left + 0.02, top, right - 0.02, top + 0.030),
                   fill=palette["fixtureDeep"])


def draw_counter_fitting(c, band, unit, palette, sector):
    """Tezgâhın üstündeki parça: espresso makinesi ya da somunlar."""
    fg = lambda k: g("FloorGeometry", k)
    top = fg("counterTop")
    if sector == "coffee":
        c.rect(unit.box(0.16, top - 0.115, 0.42, top), fill=palette["fixture"],
               radius=band.hh(0.014))
        c.rect(unit.box(0.20, top - 0.075, 0.38, top - 0.048), fill=palette["fixtureDeep"])
        c.rect(unit.box(0.46, top - 0.070, 0.56, top), fill=palette["fixtureDeep"],
               radius=band.hh(0.010))
    else:
        for loaf in range(3):
            x = 0.14 + loaf * 0.16
            c.rect(unit.box(x, top - 0.055, x + 0.12, top), fill=palette["counterShade"],
                   radius=band.hh(0.022))


def draw_investment_band(c, band, palette, sector, is_ground, table):
    """`FloorScene.drawInvestment` — kepenk inik, tabela yerinde."""
    fg = lambda k: g("FloorGeometry", k)
    ig = lambda k: g("InvestmentGeometry", k)
    c.rect(band.box(0, 0, 1, 1), fill=palette["frame"])
    c.rect(band.box(fg("interiorLeft"), fg("slabBottom"), fg("interiorRight"), 1),
           fill=palette["wall"])
    c.rect(band.box(0, fg("slabTop"), 1, fg("slabBottom")), fill=palette["frame"])

    shutter = band.box(ig("shutterLeft"), ig("shutterTop"), ig("shutterRight"), ig("shutterBottom"))
    c.rect(shutter, fill=palette["fixture"])
    slats = max(2, int(ig("shutterSlats")))
    step = (shutter[3] - shutter[1]) / slats
    for index in range(1, slats):
        y = shutter[1] + step * index
        c.rect((shutter[0], y - band.hh(0.006), shutter[2], y + band.hh(0.006)),
               fill=palette["fixtureDeep"])
    c.rect(shutter, outline=palette["fixtureDeep"], width=band.hh(0.010))

    plate = band.box(0.045, fg("signTop"), 0.46, fg("signBottom"))
    c.rect(plate, fill=palette["sign"], radius=band.hh(0.035))
    inset = band.hh(0.030)
    c.rect((plate[0] + inset, plate[1] + inset, plate[2] - inset, plate[3] - inset),
           outline=palette["signText"], width=band.hh(0.016), radius=band.hh(0.018))
    c.text(((plate[0] + plate[2]) / 2, (plate[1] + plate[3]) / 2),
           table.get(f"sector.{sector}.sign", sector.upper()), "display",
           band.hh(0.135), palette["signText"], anchor="mm",
           max_width=(plate[2] - plate[0] - inset * 2) * 0.86)

    c.rect(band.box(fg("interiorLeft"), fg("floorY"), fg("interiorRight"), fg("bandBottom")),
           fill=palette["ground"])
    c.rect(band.box(ig("plaqueLeft"), ig("plaqueTop"), ig("plaqueRight"), ig("plaqueBottom")),
           fill=PALETTE.tone("mustard"), outline=palette["frameDeep"],
           width=band.hh(0.008), radius=band.hh(0.018))


def draw_roof_band(c, band, palette, table):
    """`RoofBandView` — alçak ofis kutusu, kapı levhası ve şerit cam."""
    rg = lambda k: g("RoofGeometry", k)
    c.rect(band.box(rg("interiorLeft"), rg("capBottom"), rg("interiorRight"), rg("baseBottom")),
           fill=palette["wall"])
    c.rect(band.box(0, rg("capTop"), 1, rg("capBottom")), fill=palette["frame"])
    c.rect(band.box(0, rg("baseTop"), 1, rg("baseBottom")), fill=palette["frameDeep"])

    strip = band.box(rg("glassLeft"), rg("glassTop"), rg("glassRight"), rg("glassBottom"))
    c.rect(strip, fill=palette["tileField"])
    panes = max(1, int(rg("panes")))
    step = (strip[2] - strip[0]) / panes
    for index in range(1, panes):
        x = strip[0] + step * index
        c.rect((x - band.hh(0.010), strip[1], x + band.hh(0.010), strip[3]), fill=palette["frame"])
    c.rect(strip, outline=palette["frame"], width=band.hh(0.026))

    plate = band.box(rg("plateLeft"), rg("plateTop"), rg("plateRight"), rg("plateBottom"))
    c.rect(plate, fill=palette["sign"], radius=band.hh(0.030))
    inset = band.hh(0.030)
    c.rect((plate[0] + inset, plate[1] + inset, plate[2] - inset, plate[3] - inset),
           outline=PALETTE.tone("mustard"), width=band.hh(0.018), radius=band.hh(0.018))
    c.text(((plate[0] + plate[2]) / 2, (plate[1] + plate[3]) / 2),
           table.get("process.roofSign", "HEAD OFFICE"), "display", band.hh(0.180),
           palette["signText"], anchor="mm",
           max_width=(plate[2] - plate[0] - inset * 2) * 0.86)


# --- Bina ----------------------------------------------------------------

class Layout:
    """`BuildingLayout` — kat kutuları, kaldırım payı, çatı."""

    def __init__(self, floor_count, width, height, has_roof=False):
        self.count, self.width, self.height, self.has_roof = floor_count, width, height, has_roof
        self.ground_scale = g("BuildingLayout", "groundFloorScale")
        self.pavement = g("BuildingLayout", "pavement")
        roof = g("RoofGeometry", "scale") if has_roof else 0
        units = max(0, floor_count - 1) + self.ground_scale + roof
        self.band = (height * (1 - self.pavement) / units) if floor_count and units else 0

    def band_height(self, index):
        return self.band * self.ground_scale if index == 0 else self.band

    def frame(self, index):
        bottom = self.height - self.height * self.pavement
        for lower in range(min(index, self.count)):
            bottom -= self.band_height(lower)
        h = self.band_height(index)
        return (0, bottom - h, self.width, bottom)

    def roof_frame(self):
        if not self.has_roof or not self.count:
            return None
        top = self.frame(self.count - 1)[1]
        h = self.band * g("RoofGeometry", "scale")
        return (0, top - h, self.width, top)

    def pavement_frame(self):
        h = self.height * self.pavement
        return (0, self.height - h, self.width, self.height)


def draw_building(c, box, floors, selected, has_roof, table):
    """`BuildingView` — kat kat bina, seçili katta hardal keyline."""
    x0, y0, x1, y1 = box
    layout = Layout(len(floors), x1 - x0, y1 - y0, has_roof=has_roof)

    pavement = layout.pavement_frame()
    c.rect((x0 + pavement[0], y0 + pavement[1], x0 + pavement[2], y0 + pavement[3]),
           fill=PALETTE.tone("stone"))

    roof = layout.roof_frame()
    if roof:
        band = Band(x0 + roof[0], y0 + roof[1], x0 + roof[2], y0 + roof[3])
        draw_roof_band(c, band, PALETTE.floor(max(1, PLANNED_FLOORS), PLANNED_FLOORS), table)

    for index, floor in enumerate(floors):
        frame = layout.frame(index)
        band = Band(x0 + frame[0], y0 + frame[1], x0 + frame[2], y0 + frame[3])
        palette = PALETTE.floor(index, PLANNED_FLOORS)
        if floor.get("investment"):
            draw_investment_band(c, band, palette, floor["sector"], index == 0, table)
        else:
            draw_floor_band(c, band, palette, floor["sector"], floor.get("units", 1),
                            index == 0, floor.get("staff", 0), index == selected, table)
        if index == selected and len(floors) > 1:
            c.rect((band.x0, band.y0, band.x1, band.y1),
                   outline=PALETTE.tone("mustard"), width=2)


# --- Ekran ---------------------------------------------------------------

INK = PALETTE.tone("ink")
INK_SOFT = tuple(round(a + (b - a) * 0.45) for a, b in zip(INK, PALETTE.tone("wall")))
INK_FAINT = tuple(round(a + (b - a) * 0.62) for a, b in zip(INK, PALETTE.tone("wall")))
WALL = PALETTE.tone("wall")
PLASTER = PALETTE.tone("plaster")
ENAMEL = PALETTE.tone("enamel")
MUSTARD = PALETTE.tone("mustard")
MUSTARD_DEEP = PALETTE.tone("mustardDeep")
PISTACHIO = PALETTE.tone("pistachio")
STONE = PALETTE.tone("stone")


def panel_row(c, box, title, subtitle, trailing, enabled=True):
    """`ActionPanelView.row` — emaye kenarlıklı satır."""
    x0, y0, x1, y1 = box
    c.rect(box, fill=PLASTER, radius=8)
    edge = tuple(round(a + (b - a) * (1 - (0.55 if enabled else 0.16)))
                 for a, b in zip(ENAMEL, PLASTER))
    c.rect(box, outline=edge, width=1.5, radius=8)
    c.text((x0 + 14, y0 + 11), title, "display", 17, INK)
    c.text((x0 + 14, y0 + 32), subtitle, "label", 14, INK_SOFT, max_width=(x1 - x0) - 110)
    c.text((x1 - 14, y0 + 13), trailing, "money", 16,
           MUSTARD_DEEP if enabled else INK_FAINT, anchor="ra")


def toggle_row(c, box, title, subtitle, is_on):
    x0, y0, x1, y1 = box
    c.rect(box, fill=PLASTER, radius=8)
    edge = tuple(round(a + (b - a) * (1 - (0.55 if is_on else 0.16)))
                 for a, b in zip(ENAMEL, PLASTER))
    c.rect(box, outline=edge, width=1.5, radius=8)
    c.text((x0 + 14, y0 + 11), title, "display", 17, INK)
    c.text((x0 + 14, y0 + 32), subtitle, "label", 14, INK_SOFT, max_width=(x1 - x0) - 60)
    cx, cy, r = x1 - 26, y0 + 27, 10
    c.ellipse((cx - r, cy - r, cx + r, cy + r), fill=PISTACHIO if is_on else STONE)
    if is_on:
        c.rect((cx - 5, cy - 1.5, cx + 5, cy + 1.5), fill=PLASTER, radius=1.5)


def draw_screen(c, scene, table):
    """`RootView` düzeni: kasa, ödül şeridi, bina, eylem şeridi."""
    left, right = 22, POINTS[0] - 22
    y = SAFE_TOP + 6

    # Kasa başlığı
    c.text((left, y), table["cash.label"], "label", 13, INK_SOFT)
    y += 18
    c.text((left, y), src.money(scene["money"], table), "money", 46, INK)
    y += 52

    if scene.get("boost_remaining"):
        c.text((left, y), f"×{scene['boost_multiplier']:g}  "
               + table["event.remaining"].replace("%@", scene["boost_remaining"]),
               "label", 13, PISTACHIO)
        y += 18

    if scene["automated"]:
        c.text((left, y), table["cash.perSecond"].replace(
            "%@", src.money(scene["rate"], table, precise=True)), "label", 15, PISTACHIO)
        y += 19
        if scene.get("wage"):
            gross = table["cash.gross"].replace("%@", src.money(scene["gross"], table, precise=True))
            wage = table["cash.wages"].replace("%@", src.money(scene["wage"], table, precise=True))
            c.text((left, y), f"{gross} · {wage}", "label", 12, INK_FAINT)
            y += 16
    else:
        c.text((left, y), table["cash.byHand"], "label", 15, INK_SOFT)
        y += 19

    # Reklamsız rozeti
    if scene.get("shows_support", True):
        label = table["support.open"]
        w = c.width(label, "label", 12) + 20
        c.rect((right - w, SAFE_TOP + 6, right, SAFE_TOP + 28), radius=11,
               outline=tuple(round(a + (b - a) * 0.65) for a, b in zip(ENAMEL, WALL)), width=1)
        c.text((right - w / 2, SAFE_TOP + 11), label, "label", 12, ENAMEL, anchor="ma")

    # Vardiya patlaması şeridi
    if scene.get("boost_offer"):
        y += 6
        c.rect((left, y, right, y + 38), radius=10,
               fill=tuple(round(a + (b - a) * 0.84) for a, b in zip(MUSTARD, WALL)))
        offer = table["reward.boost"].replace("%@", scene["boost_duration"], 1)
        offer = offer.replace("%@", f"{scene['boost_multiplier']:g}", 1)
        c.text((left + 12, y + 12), offer, "label", 14, INK)
        c.text((right - 12, y + 12), table["reward.boostWatch"], "label", 14, MUSTARD_DEEP,
               anchor="ra")
        y += 38

    if not scene["automated"]:
        y += 6
        c.text((left, y), table["shop.tapHint"], "label", 13, INK_FAINT)
        y += 18

    # Eylem şeridi aşağıdan yukarı yer kaplar
    sell_height = 50 if scene["automated"] else 64
    panel_height = sell_height + 10 + 30 + 10 + 196 + 4
    panel_top = POINTS[1] - SAFE_BOTTOM - panel_height

    # Bina kalan yeri alır
    draw_building(c, (12, y + 8, POINTS[0] - 12, panel_top - 8),
                  scene["floors"], scene["selected"], scene.get("roof", False), table)

    # Satış butonu
    sector = scene["floors"][scene["selected"]]["sector"]
    c.rect((left, panel_top, right, panel_top + sell_height), fill=ENAMEL, radius=14)
    size = 18 if scene["automated"] else 21
    c.text((left + 18, panel_top + sell_height / 2), table[f"sector.{sector}.sell"],
           "display", size, PLASTER, anchor="lm")
    c.text((right - 18, panel_top + sell_height / 2),
           "+" + src.money(scene["manual"], table), "display", size, MUSTARD, anchor="rm")

    # Sekmeler
    tabs_y = panel_top + sell_height + 10
    tabs = scene["tabs"]
    step = (right - left) / len(tabs)
    for index, (key, label) in enumerate(tabs):
        cx = left + step * (index + 0.5)
        active = key == scene["tab"]
        c.text((cx, tabs_y), label, "display", 15, INK if active else INK_FAINT, anchor="ma",
               max_width=step - 6)
        c.rect((left + step * index, tabs_y + 24, left + step * (index + 1), tabs_y + 26),
               fill=ENAMEL if active else WALL)
    c.rect((left, tabs_y + 25, right, tabs_y + 26),
           fill=tuple(round(a + (b - a) * 0.88) for a, b in zip(ENAMEL, WALL)))

    # Şerit içeriği
    scene["content"](c, (left, tabs_y + 36, right, tabs_y + 36 + 196), table)


# --- Altı kare -----------------------------------------------------------

def tabs_for(table, with_process=False):
    items = [("crew", table["tab.crew"]), ("equipment", table["tab.equipment"]),
             ("branches", table["tab.branches"])]
    if with_process:
        items.append(("process", table["tab.process"]))
    items.append(("building", table["tab.building"]))
    return items


def note(c, box, body, offset):
    x0, y0, x1, _ = box
    c.text((x0 + 4, y0 + offset), body, "label", 14, INK_SOFT, max_width=(x1 - x0) - 8)


def crew_content_age0(c, box, table):
    x0, y0, x1, _ = box
    panel_row(c, (x0, y0, x1, y0 + 54), table["action.hire"],
              table["action.coffeesToGo"].replace("%lld", "38"),
              src.money(150, table), enabled=False)


def crew_content_hired(c, box, table):
    x0, y0, x1, _ = box
    panel_row(c, (x0, y0, x1, y0 + 54), table["action.hire"],
              table["staff.opener.name"], src.money(480, table), enabled=False)
    c.text((x0 + 4, y0 + 66), table["staff.quick.name"], "display", 15, INK)
    c.text((x0 + 4, y0 + 84), table["staff.quick.trait"], "body", 11, INK_SOFT,
           max_width=(x1 - x0) - 8)


def building_content(c, box, table):
    x0, y0, x1, _ = box
    panel_row(c, (x0, y0, x1, y0 + 54), table["floor.open"],
              table["floor.opensSector"].replace("%@", table["sector.bakery.name"]),
              src.money(250_000, table), enabled=False)
    y = y0 + 62
    panel_row(c, (x0, y, x1, y + 54), table["action.upgradeWarehouse"],
              table["warehouse.holds"].replace("%@", src.duration(3 * 3600, table)),
              src.money(1200, table), enabled=True)
    y += 66
    # Pazar payı çubuğu
    c.text((x0, y), table["market.title"], "display", 15, INK)
    c.text((x1, y), "48%", "money", 15, MUSTARD_DEEP, anchor="ra")
    y += 22
    share = 0.48
    c.rect((x0, y, x1, y + 12), fill=STONE, radius=3)
    c.rect((x0, y, x0 + (x1 - x0) * share, y + 12), fill=MUSTARD, radius=3)
    y += 20
    c.text((x0, y), table["market.slots"].replace("%lld", "3"), "label", 13, INK_FAINT)


def process_content(c, box, table):
    x0, y0, x1, _ = box
    c.text((x0 + 4, y0), table["process.bonus"].replace("%@", "20%"), "display", 17, PISTACHIO)
    c.text((x1 - 4, y0 + 3), table["sector.coffee.name"], "label", 13, INK_FAINT, anchor="ra")
    y = y0 + 26
    for rule, is_on in (("hire", True), ("equip", True), ("branch", False)):
        toggle_row(c, (x0, y, x1, y + 54), table[f"rule.{rule}.name"],
                   table[f"rule.{rule}.note"], is_on)
        y += 60


def sale_content(c, box, table):
    x0, y0, x1, _ = box
    panel_row(c, (x0, y0, x1, y0 + 54), table["prestige.sell"],
              table["prestige.keeps"].replace("%@", src.money(31.5, table, precise=True)),
              src.money(1_132_769, table), enabled=True)
    note(c, box, table["prestige.ready"], 62)
    y = y0 + 88
    c.text((x0 + 4, y), table["prestige.points"].replace("%lld", "1"), "display", 15, INK)
    c.text((x1 - 4, y + 2), table["prestige.bonus"].replace("%@", "12%"), "label", 13, MUSTARD_DEEP,
           anchor="ra")
    note(c, box, table["prestige.pointsNote"], 112)


def offline_sheet(c, table, scene):
    """Dönüş özeti — `.sheet` yarım yükseklikte gelir."""
    c.rect((0, 0, POINTS[0], POINTS[1]), fill=None)
    dim = Image.new("RGBA", c.image.size, (0, 0, 0, 90))
    c.image.paste(Image.alpha_composite(c.image.convert("RGBA"), dim).convert("RGB"), (0, 0))
    c.draw = ImageDraw.Draw(c.image)

    top = POINTS[1] * 0.56
    # Alt köşeler ekranın dışında kalsın: yuvarlak köşe zeminde delik açmasın.
    c.rect((0, top, POINTS[0], POINTS[1] + 40), fill=WALL, radius=20)
    # Sayfanın üst kenarı: zeminle aynı renkte olduğu için ince bir ayrım gerek.
    c.rect((0, top, POINTS[0], top + 1),
           fill=tuple(round(a + (b - a) * 0.80) for a, b in zip(INK, WALL)))
    x = 24
    y = top + 22
    c.text((x, y), table["offline.title"], "display", 28, INK)
    y += 36
    c.text((x, y), table["offline.away"].replace("%@", scene["away"]), "label", 15, INK_SOFT)
    y += 26
    c.text((x, y), src.money(scene["earned"], table), "money", 46, MUSTARD_DEEP)
    y += 56
    c.rect((x, y, POINTS[0] - x, y + 48), fill=MUSTARD, radius=12)
    c.text((POINTS[0] / 2, y + 14), table["reward.double"].replace(
        "%@", src.money(scene["earned"] * 2, table)), "display", 17, INK, anchor="ma")
    y += 60
    c.rect((x, y, POINTS[0] - x, y + 50), fill=ENAMEL, radius=12)
    c.text((POINTS[0] / 2, y + 15), table["offline.continue"], "display", 18, PLASTER, anchor="ma")


def scenes(table):
    coffee_rate = 1.38
    return [
        dict(key="1-hand", money=64, rate=0, gross=0, wage=0, manual=4, automated=False,
             floors=[dict(sector="coffee", staff=0, units=1)], selected=0,
             tab="crew", tabs=tabs_for(table), content=crew_content_age0),
        dict(key="2-hired", money=12, rate=coffee_rate, gross=coffee_rate, wage=0.3, manual=4,
             automated=True, floors=[dict(sector="coffee", staff=1, units=1)], selected=0,
             tab="crew", tabs=tabs_for(table), content=crew_content_hired,
             boost_offer=True, boost_multiplier=BALANCE["rewards"]["boostMultiplier"],
             boost_duration=src.duration(BALANCE["rewards"]["boostSeconds"], table)),
        dict(key="3-building", money=486_000, rate=54.2, gross=56.0, wage=1.8, manual=14,
             automated=True,
             floors=[dict(sector="coffee", staff=4, units=2), dict(sector="bakery", staff=2, units=1)],
             selected=1, tab="building", tabs=tabs_for(table), content=building_content),
        dict(key="4-rules", money=1_240_000, rate=268.0, gross=275.2, wage=7.2, manual=29,
             automated=True, roof=True,
             floors=[dict(sector="coffee", staff=6, units=3), dict(sector="bakery", staff=3, units=2)],
             selected=0, tab="process", tabs=tabs_for(table, with_process=True),
             content=process_content),
        dict(key="5-sell", money=2_100_000, rate=209.8, gross=217.0, wage=7.2, manual=29,
             automated=True, roof=True,
             floors=[dict(sector="coffee", staff=6, units=3), dict(sector="bakery", staff=3, units=2)],
             selected=0, tab="building", tabs=tabs_for(table, with_process=True),
             content=sale_content),
        dict(key="6-offline", money=318_000, rate=209.8, gross=217.0, wage=7.2, manual=29,
             automated=True,
             floors=[dict(sector="coffee", investment=True), dict(sector="bakery", staff=3, units=2)],
             selected=1, tab="building", tabs=tabs_for(table, with_process=True),
             content=building_content, sheet=offline_sheet, earned=126_400,
             away=src.duration(6 * 3600, table)),
    ]


# --- Mağaza çerçevesi ----------------------------------------------------

def store_frame(screen, headline, subline):
    """Başlık üstte, ekran altta — mağazaya yüklenen kare bu."""
    width, height = POINTS[0] * SCALE, POINTS[1] * SCALE
    # Sayfa zemini oyunun duvarından bir tık koyu: ekran bir nesne gibi okunsun.
    page = tuple(round(a + (b - a) * 0.55) for a, b in zip(WALL, STONE))
    frame = Image.new("RGB", (width, height), page)
    draw = ImageDraw.Draw(frame)

    caption_height = int(height * 0.20)
    head_font = ImageFont.truetype(str(FONTS / "ArchivoCond-SemiBold.ttf"), int(38 * SCALE))
    sub_font = ImageFont.truetype(str(FONTS / "ArchivoCond-Medium.ttf"), int(19 * SCALE))

    margin = int(34 * SCALE)
    size = 38
    while size > 16:
        head_font = ImageFont.truetype(str(FONTS / "ArchivoCond-SemiBold.ttf"), int(size * SCALE))
        if draw.textbbox((0, 0), headline, font=head_font)[2] <= width - margin * 2:
            break
        size -= 1
    draw.text((width / 2, caption_height * 0.34), headline, font=head_font, fill=INK, anchor="mm")
    draw.text((width / 2, caption_height * 0.60), subline, font=sub_font, fill=INK_SOFT, anchor="mm")

    # Ekranın tamamı görünmeli: kalan yüksekliğe sığacak şekilde ölçekle.
    # Genişliğe göre ölçeklersek panelin son satırları kırpılır.
    top = caption_height
    target_height = height - top
    target_width = round(screen.width * target_height / screen.height)
    shot = screen.resize((target_width, target_height), Image.LANCZOS)

    mask = Image.new("L", (target_width, target_height), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, target_width, target_height + 80 * SCALE], radius=int(30 * SCALE), fill=255)
    left = (width - target_width) // 2
    frame.paste(shot, (left, top), mask)
    ImageDraw.Draw(frame).rounded_rectangle(
        [left, top, left + target_width, height + 80 * SCALE],
        radius=int(30 * SCALE), outline=tuple(round(a + (b - a) * 0.72) for a, b in zip(INK, page)),
        width=max(1, int(1.2 * SCALE)))
    return frame


def render(language, shots_text):
    table = src.strings(language)
    out = OUT / language
    out.mkdir(parents=True, exist_ok=True)
    produced = []

    for index, scene in enumerate(scenes(table)):
        canvas = Canvas(*POINTS, WALL)
        draw_screen(canvas, scene, table)
        if scene.get("sheet"):
            scene["sheet"](canvas, table, scene)

        headline, subline = shots_text[index]
        frame = store_frame(canvas.image, headline, subline)
        path = out / f"{index + 1}-{scene['key']}.png"
        frame.save(path)
        produced.append(path)

    # Tek bakışta gözden geçirmek için sözleşme sayfası.
    thumb = (produced[0].parent, 300, 652)
    sheet = Image.new("RGB", (thumb[1] * len(produced) + 5 * (len(produced) + 1),
                              thumb[2] + 10), (250, 250, 250))
    for index, path in enumerate(produced):
        sheet.paste(Image.open(path).resize((thumb[1], thumb[2]), Image.LANCZOS),
                    (index * (thumb[1] + 5) + 5, 5))
    contact = out / f"_{language}-hepsi.png"
    sheet.save(contact)
    return produced + [contact]


def screenshot_text(language):
    """Kare metinleri `docs/app-store-screenshots.md` tablosundan okunur."""
    import re
    text = (ROOT / "docs/app-store-screenshots.md").read_text(encoding="utf-8")
    code = {"en": "en-US", "tr": "tr", "es": "es-ES"}[language]
    rows = re.findall(
        rf"^\|\s*{re.escape(code)}\s*\|\s*(.+?)\s*`\d+`\s*\|\s*(.+?)\s*`\d+`\s*\|\s*$",
        text, re.M)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lang", action="append", choices=["en", "tr", "es"])
    args = parser.parse_args()
    languages = args.lang or ["en", "tr", "es"]

    for language in languages:
        shots = screenshot_text(language)
        produced = render(language, shots)
        print(f"{language}: {len(produced) - 1} kare + sözleşme sayfası → "
              f"{produced[0].parent.relative_to(ROOT)}")
    print("\nBunlar maket. Mağazaya yüklenecek kareler Xcode'da gerçek uygulamadan alınmalı.")


if __name__ == "__main__":
    main()
