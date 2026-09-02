#!/usr/bin/env python3
"""balance.json'ın ilerleme eğrisini tablo olarak yazar.

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

    print(f"Elle satış        : {tap:g} ₺/dokunuş")
    print(f"İlk eleman        : {staff['baseCost']:.0f} ₺ = {staff['baseCost'] / tap:.0f} dokunuş")
    print(f"Ücret çarpanı     : {staff['costGrowth']:g}\n")

    print(f"{'#':>2}  {'eleman':<12} {'ücret':>10}  {'oran ₺/sn':>9}  {'biriktirme':>10}  {'toplam':>8}")
    rate = 0.0
    elapsed = 0.0
    for index in range(min(staff["maxCount"], len(pool))):
        cost = staff["baseCost"] * staff["costGrowth"] ** index
        wait = cost / rate if rate > 0 else 0.0
        elapsed += wait
        rate += staff["ratePerSecond"] * pool[index]["rateMultiplier"]
        label = "elle" if index == 0 else human(wait)
        print(f"{index + 1:>2}  {pool[index]['name']:<12} {cost:>8.0f} ₺  {rate:>9.2f}  {label:>10}  {human(elapsed):>8}")

    print(f"\nTam kadro için biriken üretim süresi: {human(elapsed)}")
    print(f"Tam kadro oranı: {rate:.2f} ₺/sn = {rate * 3600:,.0f} ₺/saat\n")

    print(f"{'sv':>2}  {'kapasite':>9}  {'ücret':>10}  {'tam kadroyla':>12}  {'dolu depo':>12}")
    for index, level in enumerate(config["warehouse"]["levels"]):
        wait = level["cost"] / rate if rate > 0 else 0.0
        full = rate * level["capacitySeconds"]
        print(f"{index:>2}  {level['capacitySeconds'] / 3600:>6.0f} sa  {level['cost']:>8.0f} ₺  "
              f"{human(wait):>12}  {full:>10,.0f} ₺")

    total = sum(staff["baseCost"] * staff["costGrowth"] ** i for i in range(staff["maxCount"]))
    total += sum(level["cost"] for level in config["warehouse"]["levels"])
    print(f"\nHer şeyin toplamı: {total:,.0f} ₺ = {human(total / rate)} tam üretim")
    print("Tasarım hedefi: ilk sektör 4-6 gün (docs/oyun-tasarim-raporu.md §5)")


if __name__ == "__main__":
    main()
