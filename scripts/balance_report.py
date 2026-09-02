#!/usr/bin/env python3
"""balance.json'ın ilerleme eğrisini tablo olarak yazar.

Sayılar birimsizdir: para birimi dile bağlı (bkz. Localizable.strings).

Bir sayıyı değiştirdikten sonra bunu çalıştır: eğrinin nereye gittiğini
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
    return f"{seconds / 86400:.1f} gün"


def main():
    config = json.loads((ROOT / "NotOnMyShift/Resources/balance.json").read_text())
    tap = config["manual"]["revenuePerSale"]
    staff = config["staff"]
    pool = config["staffPool"]

    print(f"Elle satış        : {tap:g}/dokunuş")
    print(f"İlk eleman        : {staff['baseCost']:.0f} = {staff['baseCost'] / tap:.0f} dokunuş")
    print(f"Ücret çarpanı     : {staff['costGrowth']:g}\n")

    print(f"{'#':>2}  {'kimlik':<12} {'ücret':>10}  {'oran/sn':>9}  {'biriktirme':>10}  {'toplam':>8}")
    rate = 0.0
    elapsed = 0.0
    for index in range(min(staff["maxCount"], len(pool))):
        cost = staff["baseCost"] * staff["costGrowth"] ** index
        wait = cost / rate if rate > 0 else 0.0
        elapsed += wait
        rate += staff["ratePerSecond"] * pool[index]["rateMultiplier"]
        label = "elle" if index == 0 else human(wait)
        print(f"{index + 1:>2}  {pool[index]['id']:<12} {cost:>8.0f}  {rate:>9.2f}  {label:>10}  {human(elapsed):>8}")

    print(f"\nTam kadro için biriken üretim süresi: {human(elapsed)}")
    print(f"Tam kadro oranı: {rate:.2f}/sn = {rate * 3600:,.0f}/saat\n")

    equipment = config["equipment"]
    branches = config["branches"]
    wage = staff["wagePerSecond"]

    print(f"{'ekipman':<10} {'sv':>2}  {'ücret':>10}  {'çarpan':>7}")
    full_multiplier = 1.0
    for spec in equipment:
        for index, level in enumerate(spec["levels"]):
            if index == 0:
                continue
            label = spec["id"] if index == 1 else ""
            print(f"{label:<10} {index:>2}  {level['cost']:>8.0f}  x{level['multiplier']:.2f}")
        full_multiplier *= spec["levels"][-1]["multiplier"]
    print(f"{'toplam':<10} {'':>2}  {'':>10}  x{full_multiplier:.2f}\n")

    print(f"Maas {wage:g}/sn/kisi. Tam kadroda saniyede {wage * staff['maxCount']:.2f} gider.")
    print(f"{'durum':<34} {'brut':>8} {'maas':>7} {'net':>8}  {'net/saat':>12}")
    for label, count, multiplier, branch_count in (
        ("ilk eleman", 1, 1.0, 1),
        ("tam kadro", staff["maxCount"], 1.0, 1),
        ("tam kadro + tam ekipman", staff["maxCount"], full_multiplier, 1),
        ("hepsi + tum subeler", staff["maxCount"], full_multiplier, branches["maxCount"]),
    ):
        crew_sum = sum(p["rateMultiplier"] for p in pool[:count])
        gross = staff["ratePerSecond"] * crew_sum * multiplier * branch_count
        cost = wage * count * branch_count
        print(f"{label:<34} {gross:>8.2f} {cost:>7.2f} {gross - cost:>8.2f}  {(gross - cost) * 3600:>12,.0f}")

    print(f"\n{'sube':>4}  {'ucret':>10}  {'tam kadroyla':>12}")
    for index in range(1, branches["maxCount"]):
        cost = branches["baseCost"] * branches["costGrowth"] ** (index - 1)
        print(f"{index + 1:>4}  {cost:>8.0f}  {human(cost / rate) if rate else '-':>12}")
    print()

    print(f"{'sv':>2}  {'kapasite':>9}  {'ücret':>10}  {'tam kadroyla':>12}  {'dolu depo':>12}")
    for index, level in enumerate(config["warehouse"]["levels"]):
        wait = level["cost"] / rate if rate > 0 else 0.0
        full = rate * level["capacitySeconds"]
        print(f"{index:>2}  {level['capacitySeconds'] / 3600:>6.0f} sa  {level['cost']:>8.0f}  "
              f"{human(wait):>12}  {full:>10,.0f}")

    crew_cost = sum(staff["baseCost"] * staff["costGrowth"] ** i for i in range(staff["maxCount"]))
    warehouse_cost = sum(level["cost"] for level in config["warehouse"]["levels"])
    equipment_cost = sum(level["cost"] for spec in equipment for level in spec["levels"])
    branch_cost = sum(
        branches["baseCost"] * branches["costGrowth"] ** i for i in range(branches["maxCount"] - 1)
    )
    total = crew_cost + warehouse_cost + equipment_cost + branch_cost

    peak_crew = sum(p["rateMultiplier"] for p in pool[: staff["maxCount"]])
    peak = (
        staff["ratePerSecond"] * peak_crew * full_multiplier * branches["maxCount"]
        - wage * staff["maxCount"] * branches["maxCount"]
    )

    print(
        f"\nKadro {crew_cost:,.0f} · ekipman {equipment_cost:,.0f} · "
        f"şube {branch_cost:,.0f} · depo {warehouse_cost:,.0f}"
    )
    print(f"Her şeyin toplamı: {total:,.0f}")
    print(f"Tepe net {peak:.1f}/sn ile {human(total / peak)} — ama yol boyunca oran çok daha düşük")
    print("Tasarım hedefi: ilk sektör 4-6 gün (docs/oyun-tasarim-raporu.md §5)")


if __name__ == "__main__":
    main()
