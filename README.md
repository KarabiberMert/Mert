# Not On My Shift

Türkçe, çevrimdışı çalışan bir mobil iş simülasyonu. Küçük bir kahve arabasıyla
başlıyorsun; eleman tutup ekipman alıp süreç kurdukça iş sensiz de yürümeye
başlıyor. Olgunlaşan işi satıp bir üst kata çıkıyorsun — ve ekrandaki bina kat
kat yükseliyor.

Tam tasarım dokümanı: [`docs/oyun-tasarim-raporu.md`](docs/oyun-tasarim-raporu.md)
Geliştirme yönergesi: [`docs/claude-code-prompt.md`](docs/claude-code-prompt.md)

**Durum: Faz 0 — iskelet ve motor.** Ekran bilerek çıplak; tasarım Faz 1'de gelecek.

---

## Çalıştırma

Xcode 16 veya üstü gerekiyor (Swift 6 dil kipi ve senkron klasör grupları için).

```bash
open NotOnMyShift.xcodeproj
```

Şemayı seç, bir iPhone simülatörü seç, ⌘R.

Komut satırından:

```bash
xcodebuild -project NotOnMyShift.xcodeproj \
           -scheme NotOnMyShift \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           build
```

## Testler

```bash
xcodebuild -project NotOnMyShift.xcodeproj \
           -scheme NotOnMyShift \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           test
```

Xcode içinden ⌘U.

## Faz 0 kabul kriterini elle doğrulama

1. Uygulamayı aç. Kasa 0 ₺, "Şimdilik her kahveyi sen yapıyorsun." yazıyor.
2. **Kahve sat**'a birkaç kez bas — her basış 4 ₺.
3. 150 ₺ birikince **Eleman tut**'a bas. Sevim Abla kadroya girer, kasa
   saniyede artmaya başlar. Çevrimdışı kazanç bu anda açılır.
4. Uygulamayı kapat (arka plana al), en az bir dakika bekle, geri dön.
   "Dönmüşsün" özeti çıkar ve uzakta geçen süre kadar para yazılır.
5. Cihaz saatini ileri al: kazanç depo kapasitesinde durur (başlangıçta 2 saat).
   Saati geri al: para artmaz, azalmaz.
6. Uygulamayı tamamen kapatıp yeniden aç: ilerleme yerinde.

---

## Mimari

Dört katman, tek yönlü bağımlılık:

```
Views (SwiftUI)
   ↓ okur
GameStore      @Observable · saat · sahne fazı · kalıcılık
   ↓ çağırır
GameEngine     saf · Sendable · UI bilmez · test edilebilir
   ↓ okur
GameState (Codable) + BalanceConfig (balance.json'dan)
```

| Klasör | İçerik |
|---|---|
| `NotOnMyShift/Models/` | `GameState`, `BalanceConfig` |
| `NotOnMyShift/Engine/` | `GameEngine` — ekonominin tamamı |
| `NotOnMyShift/Store/` | `GameStore`, `SaveStore` |
| `NotOnMyShift/Views/` | SwiftUI ekranları |
| `NotOnMyShift/Support/` | Palet, biçimlendirme, haptics, metinler |
| `NotOnMyShift/Resources/` | `balance.json`, varlık kataloğu, gizlilik bildirimi |
| `NotOnMyShift/tr.lproj/` | Türkçe metinler |
| `NotOnMyShiftTests/` | Motor, kalıcılık ve store testleri |
| `Config/Info.plist` | Info.plist (uygulama hedefinin dışında tutuldu) |
| `scripts/` | İkon üretici, pbxproj doğrulayıcı |

### Denge sayıları

Hepsi [`NotOnMyShift/Resources/balance.json`](NotOnMyShift/Resources/balance.json)
içinde. Bir fiyatı değiştirmek için Swift dosyası açman gerekiyorsa yanlış yerdesin.

### Motorun sözleşmesi

```swift
static func advance(_ state: GameState, by seconds: TimeInterval, config: BalanceConfig) -> GameState
```

İçinde `Date()`, `Timer`, `UserDefaults`, dosya erişimi yok. Kapalı form —
8 saatlik farkı hesaplarken 28.800 tick simüle etmez, tek çarpma yapar.

Saate ihtiyaç duyan tek fonksiyon `resume(_:at:mode:config:)` ve o da saati
parametre olarak alır. Depo tavanı ile geriye alınmış saat koruması oradadır.

---

## Araçlar

```bash
python3 scripts/balance_report.py    # balance.json'ın ilerleme eğrisini tablo olarak yazar
./scripts/check_rules.sh             # pazarlığa kapalı kuralları tarar
python3 scripts/make_app_icon.py     # 1024×1024 ikonu yeniden üretir
python3 scripts/lint_pbxproj.py      # project.pbxproj yapısını doğrular
```

Hiçbiri üçüncü parti bağımlılık kullanmaz. `balance_report.py` bir sayıyı
değiştirdikten sonra eğrinin nereye gittiğini oyunu açmadan gösterir.
