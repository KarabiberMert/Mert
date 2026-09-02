# Not On My Shift — proje kuralları

Tasarım dokümanı `docs/oyun-tasarim-raporu.md`, geliştirme yönergesi
`docs/claude-code-prompt.md`. Çelişki olursa ürün sahibine sor, kendi kafana
göre karar verme.

## Pazarlığa kapalı teknik kısıtlar

- Swift 6, strict concurrency açık. Uyarı bırakma.
- SwiftUI, iOS 17.0+. UIKit'e sadece haptics ve StoreKit için in.
- Sıfır üçüncü parti bağımlılık. SPM paketi ekleme.
- SpriteKit yok. Animasyonlar `withAnimation`, `TimelineView`, `Canvas`, `PhaseAnimator`.
- Sadece portre. Ağ bağlantısı yok.
- Force unwrap (`!`) kullanma.

## Mimari kuralı

`Views → GameStore → GameEngine → GameState + BalanceConfig`. Bağımlılık tek yönlü.

- `GameEngine` saf kalır: `Date()`, `Timer`, `UserDefaults`, dosya erişimi yok.
- `advance(by:)` kapalı formdur; tick döngüsüne dönüştürme. Kırılım noktası
  gerekirse segment segment hesapla.
- Ekonomi her zaman `lastSeenAt` zaman damgasından türetilir. `Timer.publish`
  üstüne ekonomi kurma; zamanlayıcı sadece "ne zaman yeniden hesapla" der.
- Denge sayıları `Resources/balance.json` içinde. View'a ya da Swift'e sayı gömme.
- `balance.json` **sadece sayı ve kimlik** tutar. Ekranda görünen her metin —
  eleman isimleri, huylar, dükkân adı — dil dosyalarındadır.
- Kayıt `.atomic` yazılır ve yedeklenir. `GameState`'e alan eklerken
  `decodeIfPresent` kalıbını koru — eski kayıt açılmaya devam etmeli.

## Diller

Kaynak dil İngilizce; `tr` ve `es` çeviri. Yeni dil eklemek bir `.lproj`
klasörü eklemekten ibaret olmalı.

- Ekranda görünen her metin `Support/Strings.swift` içindeki `L` üzerinden
  geçer ve `defaultValue` taşır — dosya eksik olsa bile anahtar görünmez.
- **Para birimi dile bağlıdır.** Simge, simgenin yeri, ondalık ayracı ve
  büyüklük kısaltmaları `format.*` anahtarlarından gelir (`en` → `${amount}`,
  `tr` → `{amount} ₺`, `es` → `{amount} €`). Koda para birimi gömme.
- **İsimler dile bağlıdır.** Kayıtta elemanın kimliği saklanır (`quick`,
  `veteran`), ismi değil; oyuncu dili değiştirince kadro da yeni dilde görünür.
- Çoğul eki olan cümle kurma. `.stringsdict` kurmak yerine 1 ve 38 için aynı
  çalışan bir kalıp seç.
- Yer tutucuya ek yapıştırma: `%@lik` Türkçe ünlü uyumunu bozar ("2 saatlik"
  doğru ama "3 günlik" değil). Ayrı sözcük kullan.
- Süre metnini elle yazma; `DurationText` birim adlarını ve çoğul eklerini
  `Duration.UnitsFormatStyle`'a bırakır.
- `python3 scripts/check_localization.py` anahtar ve yer tutucu eşleşmesini
  derlemeden doğrular. Yeni metin eklerken çalıştır.

## Görsel yön

Palet oyuncunun yükselişini anlatır: zemin katta esnaf estetiği (emaye mavi,
fıstık yeşili, hardal, boyalı duvar), yukarı çıktıkça soğuk ve camlaşan
kurumsal katman. Hardal vurgusu iki palette de aynı — para hep aynı renk.

- Cesareti tek yere harca: bina. Yan paneller sakin kalsın.
- Animasyon sadece oyuncunun eylemine cevap versin. Her animasyonda
  `accessibilityReduceMotion` kontrol edilir.
- Metin sen-dili, sade fiiller. Büyük harfli minik etiket kullanma (tabela ve
  kapı levhası hariç — onlar arayüz değil, binanın parçası).
- Tipografi: başlık ve rakam `Typography.display/money` (Archivo Condensed),
  gövde sistem fontu. Rakamlarda tabular figür şart.
- Yeni font eklerken `ığüşöçİĞÜŞÖÇ` ile test et — `scripts/build_fonts.py`
  bunu otomatik doğruluyor. Archivo OFL 1.1; `Resources/Fonts/OFL.txt` silinmez.
- Bina ölçüleri `ShopGeometry` içinde 0..1 normalize sabitlerdir. View'a
  piksel gömme; yeni parça eklerken oraya sabit ekle ve testini yaz.

## Fazlar

Faz 0 (bitti) → 1 (bitti): Çağ 0→1 geçişi ve görsel kimlik → 2: ekipman ve şubeler →
3: ikinci sektör ve kat açma → 4: olaylar ve rakipler → 5: süreç katmanı →
6: yumuşak prestij ve final → 7: monetizasyon ve App Store.

Bir fazı bitirmeden sonrakine geçme. Her fazın sonunda proje temiz derlenmeli.
