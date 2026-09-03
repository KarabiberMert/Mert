#!/usr/bin/env python3
"""balance.json'ın ilerleme eğrisini tablo olarak yazar.

Sayılar birimsizdir: para birimi dile bağlı (bkz. Localizable.strings).
Bir sayıyı değiştirdikten sonra bunu çalıştır — eğrinin nereye gittiğini
oyunu açmadan görürsün.

    python3 scripts/balance_report.py
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def human(seconds):
    if seconds < 60:
        return f"{seconds:.0f} sn"
    if seconds < 3600:
        return f"{seconds / 60:.0f} dk"
    if seconds < 86400:
        return f"{seconds / 3600:.1f} sa"
    return f"{seconds / 86400:.1f} gun"


def sector_report(sector):
    staff = sector["staff"]
    pool = sector["staffPool"]
    equipment = sector["equipment"]
    branches = sector["branches"]
    wage = staff["wagePerSecond"]

    print(f"\n{'=' * 62}")
    print(f"SEKTOR: {sector['id']}   kat acilis ucreti {sector['unlockCost']:,.0f}")
    print("=" * 62)
    print(f"Elle satis {sector['manual']['revenuePerSale']:g}/dokunus · "
          f"ilk eleman {staff['baseCost']:.0f} = {staff['baseCost'] / sector['manual']['revenuePerSale']:.0f} dokunus")
    print(f"Ucret carpani {staff['costGrowth']:g} · maas {wage:g}/sn/kisi\n")

    print(f"{'#':>2}  {'kimlik':<12} {'ucret':>10}  {'brut/sn':>8}  {'biriktirme':>10}  {'toplam':>8}")
    gross = 0.0
    elapsed = 0.0
    for index in range(min(staff["maxCount"], len(pool))):
        cost = staff["baseCost"] * staff["costGrowth"] ** index
        net = max(0.0, gross - wage * index)
        wait = cost / net if net > 0 else 0.0
        elapsed += wait
        gross += staff["ratePerSecond"] * pool[index]["rateMultiplier"]
        label = "elle" if index == 0 else human(wait)
        print(f"{index + 1:>2}  {pool[index]['id']:<12} {cost:>10.0f}  {gross:>8.2f}  {label:>10}  {human(elapsed):>8}")

    full_multiplier = 1.0
    print(f"\n{'ekipman':<10} {'sv':>2}  {'ucret':>10}  {'carpan':>7}")
    for item in equipment:
        for index, level in enumerate(item["levels"]):
            if index == 0:
                continue
            label = item["id"] if index == 1 else ""
            print(f"{label:<10} {index:>2}  {level['cost']:>10.0f}  x{level['multiplier']:.2f}")
        full_multiplier *= item["levels"][-1]["multiplier"]
    print(f"{'toplam':<10} {'':>2}  {'':>10}  x{full_multiplier:.2f}")

    print(f"\n{'sube':>4}  {'ucret':>10}")
    for index in range(1, branches["maxCount"]):
        print(f"{index + 1:>4}  {branches['baseCost'] * branches['costGrowth'] ** (index - 1):>10.0f}")

    print(f"\n{'durum':<32} {'brut':>10} {'maas':>8} {'net':>10}  {'net/saat':>14}")
    rows = (
        ("ilk eleman", 1, 1.0, 1),
        ("tam kadro", staff["maxCount"], 1.0, 1),
        ("tam kadro + tam ekipman", staff["maxCount"], full_multiplier, 1),
        ("hepsi + tum subeler", staff["maxCount"], full_multiplier, branches["maxCount"]),
    )
    peak = 0.0
    for label, count, multiplier, branch_count in rows:
        crew = sum(p["rateMultiplier"] for p in pool[:count])
        total = staff["ratePerSecond"] * crew * multiplier * branch_count
        cost = wage * count * branch_count
        peak = max(peak, total - cost)
        print(f"{label:<32} {total:>10.2f} {cost:>8.2f} {total - cost:>10.2f}  {(total - cost) * 3600:>14,.0f}")

    crew_cost = sum(staff["baseCost"] * staff["costGrowth"] ** i for i in range(staff["maxCount"]))
    equipment_cost = sum(level["cost"] for item in equipment for level in item["levels"])
    branch_cost = sum(
        branches["baseCost"] * branches["costGrowth"] ** i for i in range(branches["maxCount"] - 1)
    )
    total_cost = crew_cost + equipment_cost + branch_cost
    print(f"\nKadro {crew_cost:,.0f} · ekipman {equipment_cost:,.0f} · sube {branch_cost:,.0f}")
    print(f"Sektorun tamami: {total_cost:,.0f}  ({human(total_cost / peak)} tepe uretim)")
    return peak, total_cost


def main():
    config = json.loads((ROOT / "NotOnMyShift/Resources/balance.json").read_text())

    print(f"Bina: {len(config['sectors'])} sektor acik, palet {config['building']['paletteFloors']} kata gore soguyor")

    peaks = []
    grand_total = 0.0
    for sector in config["sectors"]:
        peak, cost = sector_report(sector)
        peaks.append(peak)
        grand_total += cost + sector["unlockCost"]

    print(f"\n{'=' * 62}\nDEPO (butun katlarin ortak kapasitesi)\n{'=' * 62}")
    reference = peaks[0] if peaks else 1
    print(f"{'sv':>2}  {'kapasite':>9}  {'ucret':>10}  {'dolu depo (zemin tepe)':>24}")
    for index, level in enumerate(config["warehouse"]["levels"]):
        print(f"{index:>2}  {level['capacitySeconds'] / 3600:>6.0f} sa  {level['cost']:>10.0f}  "
              f"{reference * level['capacitySeconds']:>24,.0f}")
    warehouse_cost = sum(level["cost"] for level in config["warehouse"]["levels"])
    grand_total += warehouse_cost

    events = config["events"]
    market = config["market"]
    reference_rate = peaks[0] if peaks else 1

    print(f"\n{'=' * 62}\nOLAYLAR\n{'=' * 62}")
    print(f"Ilk olay {human(events['firstAfterSeconds'])} sonra · aralik "
          f"{human(events['gapSeconds'])} (+-%{events['gapJitter'] * 100:.0f}) "
          f"→ gunde ~{86400 / events['gapSeconds']:.0f} firsat, seansta en fazla 1")
    print(f"{'olay':<12} {'secenek':<14} {'carpan':>7} {'sure':>9}  {'anlik (zemin tepe)':>22}")
    for spec in events["specs"]:
        for index, choice in enumerate(spec["choices"]):
            label = spec["id"] if index == 0 else ""
            duration = human(choice["durationSeconds"]) if choice["durationSeconds"] else "-"
            multiplier = f"x{choice['multiplier']:.2f}" if choice["multiplier"] != 1 else "-"
            instant = choice["instantSeconds"] * reference_rate
            money = f"{instant:+,.0f}" if choice["instantSeconds"] else "-"
            print(f"{label:<12} {choice['id']:<14} {multiplier:>7} {duration:>9}  {money:>22}")

    print(f"\n{'=' * 62}\nPAZAR\n{'=' * 62}")
    drift_days = (market["startShare"] - market["minimumShare"]) / market["driftPerSecond"] / 86400
    print(f"Baslangic %{market['startShare'] * 100:.0f} · taban %{market['minimumShare'] * 100:.0f}")
    print(f"Kayma gunde {market['driftPerSecond'] * 86400 * 100:.1f} puan → tabana {drift_days:.1f} gunde iner")
    print(f"Her yatirim +{market['sharePerPurchase'] * 100:.1f} puan "
          f"→ tabandan basa {(market['startShare'] - market['minimumShare']) / market['sharePerPurchase']:.0f} yatirim")
    for sector in config["sectors"]:
        maximum = sector["branches"]["maxCount"]
        span = 1 - market["minimumShare"]
        needed = []
        for slot in range(2, maximum + 1):
            progress = (slot - 1 - 0.5) / (maximum - 1) if maximum > 1 else 0
            needed.append(f"{slot}. hucre %{(market['minimumShare'] + progress * span) * 100:.0f}")
        print(f"  {sector['id']:<8} {' · '.join(needed)}")
    print("  Kural: rakip mevcut geliri asla dusurmez, sadece yeni hucreyi geciktirir.")

    process = config["process"]
    print(f"\n{'=' * 62}\nSUREC KATMANI\n{'=' * 62}")
    managers = len(config["sectors"])
    manager_total = sum(
        process["managerBaseCost"] * process["managerCostGrowth"] ** index
        for index in range(managers)
    )
    process_cost = process["roofCost"] + manager_total
    grand_total += process_cost
    print(f"Cati {process['roofCost']:,.0f} · zemin tepesinde {process['roofCost'] / reference:,.0f} sn uretim")
    print(f"{'mudur':>5}  {'ucret':>12}")
    for index in range(managers):
        cost = process["managerBaseCost"] * process["managerCostGrowth"] ** index
        print(f"{index + 1:>5}  {cost:>12,.0f}")
    print(f"Mudurlerin toplami {manager_total:,.0f} · surec katmani {process_cost:,.0f}")
    rules = len(process["rules"])
    reachable = min(process["maxBonus"], rules * process["bonusPerRule"])
    print(f"{rules} kural x %{process['bonusPerRule'] * 100:.0f} → en fazla %{reachable * 100:.0f} "
          f"(tavan %{process['maxBonus'] * 100:.0f})")
    print(f"Yedek {human(process['reserveSeconds'])} uretim · donus basina en fazla "
          f"{process['maxActionsPerVisit']} islem")
    print("  Kural: surec kurmayan tam verimle calisir; bonus eksiltmez, ekler.")

    print(f"\nDepo {warehouse_cost:,.0f}")
    print(f"Her seyin toplami: {grand_total:,.0f}")
    print(f"Tepe net {max(peaks):,.1f}/sn — ama yol boyunca oran cok daha dusuk")
    print("Tasarim hedefi: her sektor 4-6 gun (docs/oyun-tasarim-raporu.md §5)")


if __name__ == "__main__":
    main()
