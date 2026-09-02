# Not On My Shift

Türkçe, çevrimdışı çalışan bir mobil iş simülasyonu. Küçük bir kahve arabasıyla
başlıyorsun; eleman tutup ekipman alıp süreç kurdukça iş sensiz de yürümeye
başlıyor. Olgunlaşan işi satıp bir üst kata çıkıyorsun — ve ekrandaki bina kat
kat yükseliyor.

Tam tasarım dokümanı: [`docs/oyun-tasarim-raporu.md`](docs/oyun-tasarim-raporu.md)
Geliştirme yönergesi: [`docs/claude-code-prompt.md`](docs/claude-code-prompt.md)

**Durum: Faz 1 — Çağ 0→1 geçişi ve görsel kimlik.**
Zemin kat kesiti çizildi, elle üretimden ilk elemana geçiş ve çevrimdışı
kazancın açılması yerinde.

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

## Elle doğrulama

**Faz 1'in tek sorusu:** ilk elemanı tutma anı tatmin edici mi? Sırayla bak:

1. Uygulamayı aç. Kasa 0 ₺, "Şimdilik her kahveyi sen yapıyorsun." yazıyor.
   Binada tek kişi var: sen, tezgâhın arkasında.
2. **Tezgâha dokun** (ya da "Kahve sat" butonuna bas) — her dokunuşta 4 ₺ ve
   tezgâhtan yukarı süzülen bir rakam. "Eleman tut" satırı kaç kahve
   kaldığını söylüyor.
3. 150 ₺ birikince **Eleman tut**'a bas. Sevim Abla kata yerleşir, sen
   tezgâhtan çekilip salonda izlemeye başlarsın, kutlama ekranı bir kez çıkar
   ve kasa saniyede artmaya başlar. Çevrimdışı kazanç bu anda açılır.
4. Uygulamayı kapat (arka plana al), en az bir dakika bekle, geri dön.
   "Dönmüşsün" özeti çıkar ve uzakta geçen süre kadar para yazılır.
5. Cihaz saatini ileri al: kazanç depo kapasitesinde durur (başlangıçta 2 saat).
   Saati geri al: para artmaz, azalmaz.
6. Uygulamayı tamamen kapatıp yeniden aç: ilerleme yerinde, kutlama tekrar etmiyor.
7. Ayarlar → Erişilebilirlik → **Hareketi Azalt**'ı aç: süzülen rakam ve
   yerleşme animasyonu susar, oyun aynı çalışır.

### Tipografi kontrolü

Ekranda `ığüşöçİĞÜŞÖÇ` ve `₺` doğru görünüyor mu? Rakamlar sayaç artarken
zıplıyor mu? Zıplıyorsa özel font yüklenmemiştir — `Typography.hasCustomFonts`
false'a düşmüş demektir, `UIAppFonts` girdilerini ve paketteki dosya adlarını
kontrol et.

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
| `NotOnMyShift/Views/Building/` | Zemin kat kesiti — ekranın kahramanı |
| `NotOnMyShift/Views/Panels/` | Kasa sayacı ve eylem şeridi |
| `NotOnMyShift/Support/` | Palet, tipografi, biçimlendirme, haptics, metinler |
| `NotOnMyShift/Resources/` | `balance.json`, fontlar, varlık kataloğu, gizlilik bildirimi |
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
python3 scripts/build_fonts.py       # Archivo kesitlerini yeniden üretir (fonttools gerekir)
./scripts/check_rules.sh             # pazarlığa kapalı kuralları tarar
python3 scripts/make_app_icon.py     # 1024×1024 ikonu yeniden üretir
python3 scripts/lint_pbxproj.py      # project.pbxproj yapısını doğrular
```

Hiçbiri uygulamaya üçüncü parti bağımlılık sokmaz. `balance_report.py` bir
sayıyı değiştirdikten sonra eğrinin nereye gittiğini oyunu açmadan gösterir.

## Tipografi

İki aile: başlıklar ve rakamlar **Archivo Condensed**, gövde metni sistem fontu.

Archivo'nun değişken fontundan iki kesit üretildi — `ArchivoCond-SemiBold` ve
`ArchivoCond-Medium`, genişlik ekseni 79'a sabitlenmiş. İkisi de `ığüşöçİĞÜŞÖÇ`
ve `₺` gliflerini eksiksiz taşıyor ve `tnum` tabular figür özelliğine sahip;
`scripts/build_fonts.py` bunu her üretimde doğruluyor.

Archivo **SIL Open Font License 1.1** ile lisanslı. Lisans metni
`NotOnMyShift/Resources/Fonts/OFL.txt` içinde durur ve silinmemelidir.

Font pakete girmezse `Typography` sistem fontunun sıkışık genişliğine düşer —
ekran bozulmaz, sadece karakteri azalır.

## Görsel yön

Zemin katta esnaf estetiği: emaye tabela, çini lambri, boyalı duvar, hardal
tezgâh. Yukarı çıktıkça palet soğuyacak ve camlaşacak (Faz 3). Hardal vurgusu
iki katmanda da aynı kalır — para hep aynı renk.

Bina kesitinin tüm ölçüleri `ShopGeometry` içinde 0..1 normalize sabitler
olarak duruyor; `ShopGeometryTests` kadronun tezgâhtan taşmadığını ve
katmanların doğru sırada olduğunu doğruluyor.

Hareket kuralı: sahne kendiliğinden kıpırdamaz. Sadece oyuncunun eylemine
cevap verir — dokununca süzülen rakam, eleman gelince kata yerleşme. Her
animasyon `accessibilityReduceMotion` kontrol eder.
