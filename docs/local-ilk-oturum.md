# Local'de ilk oturum

Bu dosya bir **çalışma sayfası**, açıklama değil. Local Claude Code oturumu
buradaki adımları sırayla geçer, kutuları işaretler ve bulduklarını en alta
yazar. Bir sonraki oturum kaldığı yerden devam eder.

Arka plan gerekiyorsa: [`xcode-devir.md`](xcode-devir.md) neyin doğrulanıp
neyin doğrulanmadığını, `../README.md` ise projenin tamamını anlatıyor.

---

## Oturumu başlatan komut

Mac'te repoyu klonladıktan sonra Claude Code'a bunu ver:

```
Bu proje yedi fazın sonunda ama hiç derlenmedi — Swift araç zinciri olmayan
bir konteynerde yazıldı. Senin işin onu ilk kez gerçekten çalıştırmak.

Önce CLAUDE.md'yi oku; oradaki kısıtlar pazarlığa kapalı.
Sonra docs/local-ilk-oturum.md'yi aç ve adımları sırayla geç.
Her adımda kutuyu işaretle, bulduklarını dosyanın altındaki günlüğe yaz.
Bir adım bitmeden sonrakine geçme.
```

---

## Adımlar

### 0. Ortam

```bash
git clone https://github.com/KarabiberMert/Mert.git && cd Mert
```

Tek dal var ve varsayılan o; `checkout` gerekmiyor. **Proje zip'i yoktur** —
her şey bu depoda. (Daha önce paylaşılan `mockups.zip` yalnızca maket ekran
görüntüleridir, kod değil.)

- [x] `xcodebuild -version` → Xcode 16 veya üstü
- [x] `xcrun simctl list devices available | grep iPhone` → en az bir iPhone simülatörü
- [x] `./scripts/mac_kapi.sh --sadece-denetci` → beş denetçi de geçiyor

Denetçiler bu konteynerde geçiyordu; Mac'te de geçmeli. Geçmiyorsa sorun
ortamdadır, kodda değil — önce onu çöz.

### 1. Derle

- [x] `./scripts/mac_kapi.sh --derle` temiz geçti
- [x] Sıfır uyarı (CLAUDE.md: "Uyarı bırakma")

En riskli adım. Beklenen hata türü Swift 6 izolasyonu. İlk bakılacak beş yer
[`xcode-devir.md`](xcode-devir.md) §4'te.

**Hatayı susturmanın yasak yolları.** Bunlardan biriyle geçen derleme, geçmiş
sayılmaz:

| Yapma | Onun yerine |
|---|---|
| `!` ile force unwrap | `guard let` · `??` · `if let` |
| `@unchecked Sendable` | Tipi gerçekten Sendable yap; saklı alanları da |
| `nonisolated(unsafe)` | Alanı doğru aktöre taşı ya da `@ObservationIgnored` |
| `@preconcurrency import` | Çağrıyı doğru izolasyona al |
| `try!` · `as!` · `fatalError` | Hata yolunu gerçekten ele al |
| Testi silmek ya da atlamak | Testi düzelt, ya da testin haklı olduğunu kabul et |

`scripts/check_rules.sh` ilk dördünü zaten yakalıyor; kapıdan geçemezsin.

**Denge sayısıyla oynama.** Bir test kırılıyorsa `balance.json`'ı değiştirmek
en kolay ama en yanlış çözüm: testler motoru ölçüyor, dengeyi değil.

### 2. Testler

- [x] `./scripts/mac_kapi.sh` → 191 testin hepsi geçti

Kırılan olursa önce **testin kendi kurulumuna** bak. Motor mantığı kâğıt
üstünde defalarca doğrulandı; test hiç çalıştırılmadı. Yani ilk şüpheli
`XCTestCase` kurulumu, `@MainActor` izolasyonu ya da geçici klasör
yardımcısı — motorun matematiği değil.

Gerçekten motor hatası çıkarsa: testi değil kodu düzelt, sonra aynı hatayı
yakalayan bir test daha ekle.

### 3. Simülatörde aç

- [x] Uygulama açılıyor, `BootFailureView` görünmüyor
- [ ] `README.md` → "Elle doğrulama" listesindeki 27 madde geçti

```bash
xcrun simctl boot "iPhone 16 Pro Max"
xcodebuild -project NotOnMyShift.xcodeproj -scheme NotOnMyShift \
           -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
           -derivedDataPath build/dd build
xcrun simctl install booted \
  build/dd/Build/Products/Debug-iphonesimulator/NotOnMyShift.app
xcrun simctl launch booted com.karabibermert.notonmyshift
xcrun simctl io booted screenshot /tmp/ekran.png
```

Ekran görüntüsünü oku ve düzeni gözle kontrol et.

### 4. Kör düzeltilmiş üç yer

Bunlar bu konteynerde ekran görülmeden düzeltildi. Gerçekten çalıştığını ilk
kez burada göreceğiz.

- [x] **Sponsor arası sahnesinin katmanı.** Dönüş özeti bir `.sheet`; katlama
      düğmesine basınca geri sayım sayfanın **üstünde** çıkmalı, arkasında değil.
- [ ] **Beş sekmeli şerit.** Çatı açıkken sekme başlıkları sığıyor mu,
      `minimumScaleFactor` devreye giriyor mu?
- [ ] **Binanın dikey dengesi.** Çatı + iki kat + kaldırım. Zemin katın 1,35
      katı yüksekliği ekranda doğru duruyor mu?

### 5. Satın alma

StoreKit yapılandırması paylaşılan şemaya **zaten bağlı**, ek ayar yok.

- [ ] Reklamsız rozeti görünüyor, fiyat `2,99` geliyor
- [ ] Satın alınca rozet kayboluyor
- [ ] Dönüş özetinde katlama **sorulmadan** uygulanıyor (rapor §8'in kuralı)
- [ ] Vardiya patlaması sahnesiz geliyor
- [ ] Geri yükleme çalışıyor

### 6. Gerçek ekran görüntüleri

- [ ] Üç dil × altı kare, 6,9" ve 6,7"

```bash
xcrun simctl status_bar booted override --time 9:41 \
  --batteryState charged --batteryLevel 100
xcrun simctl io booted screenshot kare-1.png
```

Hangi karede hangi oyun durumuna gelinmesi gerektiği
[`app-store-screenshots.md`](app-store-screenshots.md)'de; `build/mockups/`
altındaki maketler kompozisyon şablonu.

Karelere elle ulaşmak uzun sürüyorsa `#if DEBUG` altında kaydı doğrudan
istenen duruma kuran bir işlev yaz. Motor saf olduğu için bu kolay ve
yayın derlemesine sızmaz.

---

## Oturum günlüğü

Her oturumun sonunda buraya yaz. Kısa tut: ne yapıldı, ne bulundu, ne kaldı.

### Oturum 1 — 5 Eylül 2026

**Yapıldı:** Adım 0, adım 1, adım 2 ve adım 3'ün ilk kutusu. Proje ilk kez
derlendi, 191 testin hepsi geçti, uygulama simülatörde açıldı.

**Bulundu:**

- Ortam: Xcode 26.6, Swift 6.3.3. `iPhone 16 Pro Max` bu makinede yok; bütün
  komutlar `DEST='platform=iOS Simulator,name=iPhone 17 Pro Max'` ile koşuldu.
  Betiğin `DEST` kancası tam da bunun için varmış.
- Beş denetçi Mac'te ilk denemede temiz geçti; konteyner sonucu birebir tuttu.
- **Derleme hataları Swift 6 izolasyonu değildi.** `xcode-devir.md` §4'ün beş
  şüphelisinden hiçbiri patlamadı. Çıkan dört hata "hiç derlenmemiş olmanın"
  izleriydi:
  1. `MomentBannerView.swift:12` — `let body body_: String` geçersiz sözdizimi;
     `body` SwiftUI'ın `var body`'siyle çakışıyor. Saklı ad `message` oldu,
     dış etiket `body` açık bir `init` ile korundu; üç çağrı yeri değişmedi.
  2. `GameState.swift` — elle yazılmış `init` şema 7'nin iki alanını
     (`holdingPoints`, `cityNumber`) almıyordu, `newGame` ise 22 argüman
     veriyordu. Kod çözücü ve kodlayıcı ikisini de doğru işliyordu; eksik olan
     yalnızca init'ti.
  3. `ActionPanelView.swift:146` — `store.state.staff`; kadro şema 4'te kata
     taşınmıştı. `store.currentFloor?.staff ?? []` oldu.
  4. `ActionPanelView.swift:180,319` — `map(Money.text)`; fonksiyon referansı
     `style` varsayılanını kaybediyor. `map { Money.text($0) }` oldu.
- Testlerde iki şey çıktı:
  - `PersistenceTests.swift:119` — aynı `state.staff` kalıntısı. İddia
    `state.floors[0].staff` oldu; beklenti değişmedi.
  - `FormattersTests` üç test — kod `5,6Mr ₺` üretiyordu, test `5,6 Mr ₺`
    bekliyordu. **Test haklıydı**: `Money.text`'in kendi doküman satırı da
    `1,2 B ₺` yazıyor. `number()` sayı ile kısaltmayı ayraçsız birleştiriyordu.
    Ayraç dile bağlı olduğu için (İngilizce bitişik, Türkçe/İspanyolca ayrı
    sözcük) `format.scaleSeparator` anahtarı eklendi — en `""`, tr/es `" "` —
    ve `Money.Style` bir `scaleSeparator` alanı kazandı. Koda dil listesi
    gömülmedi; yeni dil hâlâ tek `.lproj` klasörü. Test kurulumlarına alan
    eklendi, **beklenen çıktıların hiçbiri değişmedi.**
- Ekran ilk açılışta doğru: kasa `0 ₺`, tek kişi tezgâhın arkasında, "Kahve sat
  +4 ₺", şerit dört sekmeli (Kadro · Ekipman · Şubeler · Bina). Tabela okunuyor.

**Oturum 2 bulgusu — patron ilk eleman tutulunca kayboluyordu (düzeltildi):**

README madde 3 "sen tezgâhtan çekilip salonda izlemeye başlarsın" diyor.
Ekranda olan bu değil: eleman tutulduğu anda patron figürü hiç çizilmiyor.
İki ayrı sebep var, ikisi de kodda:

- `FloorBandView.figure(...)` bütün figürleri `standing: false` ile çiziyor.
  `ShopFigureView`'ın `standing` parametresine hiçbir yerde `true` geçilmiyor,
  yani "salonda duran patronun bacakları" dalı ölü kod. Dosyanın kendi
  başlığı bu çizimi tarif ediyor.
- `visibleFigures = max(1, unitWidth / pointsPerFigure - 1)` bu bantta 1
  dönüyor. `ownerInRow = showsOwner && (visible < capacity || staff.isEmpty)`
  koşulu ilk elemandan sonra `1 < 1` → false oluyor; patron tezgâh sırasında
  eleman ile yer yarışına giriyor ve kaybediyor.

Ürün sahibi düzeltilmesini onayladı. Yapılan: yerleşim `FloorGeometry`'ye
saf ve test edilebilir bir işlev olarak taşındı (`figureLayout(staffCount:
capacity:showsOwner:)`). Patron artık kadroyla yuva yarışına girmiyor —
kadro yokken tezgâhın arkasında kadronun yerinde duruyor, ilk eleman gelince
kendi yuvasını alıp salona geçiyor. Salon katmanı `drawFront`'tan **sonra**
çiziliyor (tezgâhın önünde) ve `standing: true` ile, yani bacakları görünüyor
— `ShopFigureView`'ın ölü dalı böylece gerçekten kullanılıyor.

Testi yazıldı (`testOwnerKeepsASlotEvenWhenTheCounterIsFull`): kapasite 1 iken
kadro 1 olduğunda patron yuvası artık kayboluyor mu diye bakıyor. Ekranda
doğrulandı; madde 3 tam geçti. Test sayısı 192 → 193.

**Oturum 2 bulgusu — dönüş özeti hiç çıkmıyordu (düzeltildi):**

Madde 4 "Dönmüşsün özeti çıkar" diyor; çıkmıyordu. Para doğru yazılıyordu,
özet yoktu. Sebep sahne fazı sırası: geri dönerken iOS `.background →
.inactive → .active` veriyor ve `NotOnMyShiftApp` `.inactive`'i de
`handleWillResignActive()`'e bağlıyor. O çağrı `.live` resume yapıp
`lastSeenAt`'i şimdiye damgalıyordu — parayı yazıyor ama uzakta geçen süreyi
siliyordu, dolayısıyla `.active`'te `elapsed ≈ 0` ve `isReportable == false`.

Bunu önce testle kanıtladım (`testReturnSummarySurvivesTheInactivePhaseOnTheWayBack`):
gerçek fazı sırasını kurunca para 300 ₺ doğru geliyor ama `offlineReport` nil.
Düzeltme `GameStore`'da: `isResigned` bayrağı, `handleWillResignActive()` araya
`handleBecameActive()` girmeden ikinci kez çalışmıyor. Sahne fazı bağlantısına
dokunulmadı; kaç tane `.inactive` gelirse gelsin sonuç aynı.

Etkisi göründüğünden büyüktü: madde 24 (çevrimdışı katlama) ve madde 26 (satın
alanın katlamayı sorulmadan alması) dönüş özetinin içinde yaşıyor, yani ikisi
de hiç görülemezdi. `stats.offlineReturns` de hiç artmıyordu. Ayrıca aynı
kökten, `hasOfferedEventThisSession` her kısa kesintide sıfırlanıyordu.

Test sayısı 191 → 192.

**Oturum 2 bulgusu — kökte iki `.sheet` yan yanaydı (düzeltildi):**

`isResigned` düzeltmesinden sonra bile özet çıkmadı. Sebep ikinci ve ayrı bir
hataydı: `RootView`'da aynı görünüme iki `.sheet` zincirlenmişti —
`isPresented: $showsSupport` ve hemen altında `item: $store.offlineReport`.
SwiftUI bu durumda yalnızca birini sunuyor; destek sayfası kazanıyor, dönüş
özeti hiç açılmıyordu.

Destek sayfası `CashHeaderView`'a taşındı. Düğmenin kendisine değil: satın
alma `hasRemovedAds`'i açınca düğme kayboluyor ve sayfa altından çekilirdi.
Kökte artık tek `.sheet` var. Bunu yorumla da işaretledim ki ileride geri
birleştirilmesin.

Bu iki düzeltmeden sonra madde 4 ekranda geçti: "Dönmüşsün · 1 dakika 26
saniye uzaktaydın · 93 ₺" ve altında katlama düğmesi.

**Adım 3 ve 4'te geçen maddeler**

- Madde 1, 2, 3 geçti. Rakamlar denge raporuyla birebir: ilk eleman sonrası
  `saniyede 1,1 ₺`, `brüt 1,4 · maaş 0,3`; sıradaki eleman Kadir 480 ₺.
  Kutlama ekranı bir kez çıkıyor ve `MomentBannerView` düzeltmesi doğru
  çiziliyor (başlık, huy satırı, gövde metni, düğme).
- Madde 4 geçti (yukarıdaki iki düzeltmeden sonra).
- Madde 12'nin "Şimdi değil her zaman açık" kısmı geçti; olay kartı kendi
  başına çıktı.
- Madde 24 geçti: katlama düğmesi → sponsor arası → "186 ₺ · Katlandı".
- **Adım 4'ün birinci kutusu geçti**: sponsor arası sahnesi dönüş özetinin
  üstünde çıkıyor, arkasında değil.
- Yan doğrulama: kasa 1000 ₺'yi geçince "1,0 B ₺" yazıyor — bu oturumda
  eklenen `format.scaleSeparator` cihazda çalışıyor.

**Oturum 2 — `#if DEBUG` durum kurucusu:**

Ürün sahibi onayladı; çalışma sayfasının adım 6'da önerdiği yol. `GameStore`
içinde (aynı dosyada, çünkü `state` ve `persist()` dosyaya özel) beş senaryo:
para ver · üst katı aç · çatı + müdür · katı olgunlaştır · halka arza hazırla.
Düğmeleri "Motor" panelinde, zaten var olan `#if DEBUG` bölümünde.

Durum **elle uydurulmuyor**: her adım gerçek mağaza eylemini çağırıyor
(`hireStaff`, `upgradeEquipment`, `openBranch`, `unlockNextFloor`,
`unlockRoof`, `hireManager`, `sellSector`), yalnızca para dışarıdan veriliyor.
Yani motorun kabul etmeyeceği bir kayıt buradan çıkamaz. Döngüler sayaçla
sınırlı — pazar payı şube açmayı engellerse takılmıyor.

Küçük tuzak: `Button`'ın etiketi düz metin olduğu için vuruş alanı yazı kadardı,
satırın boşluğuna basınca çalışmıyordu. `.contentShape(Rectangle())` eklendi.

**Kurucuyla doğrulanan maddeler**

- Madde 7 geçti: ekipman hem saniyelik geliri hem elle satışı büyütüyor
  (+4 ₺ → +29 ₺), kasa satırında `brüt · maaş` görünüyor.
- Madde 8 geçti: dört hücre açıldı, her biri aynı kadro ve ekipmanı devraldı,
  patron yalnızca ilk hücrede duruyor.
- Madde 18 geçti: kat olgunlaşınca "Bu işi sat · 1,1 Mn ₺" ve "Büyüdü,
  satılmaya hazır" çıkıyor; satılan katın kalacak oranı da yazıyor
  ("Saniyede 31,5 ₺ kazandırmaya devam eder").
- Rakamlar `balance_report.py` ile birebir tutuyor: tam kadro + tam ekipman +
  tüm şubelerde `brüt 216 ₺ · maaş 7,2 ₺ · net 209 ₺`; rapor 216,97 / 7,20 /
  209,77 diyor. Fırın katı açılışı 250 B ₺ — `balance.json` ile aynı.

**Oturum 2 bulgusu — iki kattan sonra kat değiştirilemiyordu (düzeltildi):**

Madde 10 doğrulanırken çıktı ve bu oturumun en ağır hatasıydı. Alt kata
dokunmak onu seçmiyordu; hiçbir şey olmuyor sanılıyordu. "Motor" panelindeki
`Elle satış` sayacı gerçeği söyledi: 38 → 41, yani alt kata yaptığım üç
dokunuşun üçü de **üst katta satış** yapmış.

Sebep `BuildingView`'da modifier sırası: `.contentShape(Rectangle())` ve
`.onTapGesture`, `.position()`'dan **sonra** geliyordu. `.position` görünümü
ebeveynin tamamı kadar büyütüyor, dolayısıyla her katın dokunma alanı binanın
tümü oluyordu ve ZStack'te en son çizilen kat (en yüksek indeks) bütün
dokunuşları yutuyordu.

Etkisi: ikinci kat açıldığı anda oyuncu alt kata **bir daha hiç dönemiyordu** —
kadro, ekipman, şube, satış, hepsi erişilemez hale geliyordu. Madde 10, 13, 19,
21 ve çok katlı oyunun tamamı buna bağlı.

Düzeltme: `.position` en sona alındı, dokunma alanı katın kendi çerçevesinde
kuruluyor. Ekranda doğrulandı: alt kata dokununca seçiliyor, keyline ve satış
düğmesi ("Kahve sat +29 ₺") o kata geçiyor, patron da o kata taşınıyor.

Not: bu SwiftUI yerleşim sırası hatası birim testiyle yakalanmıyor; koda
sebebini anlatan bir yorum bırakıldı.

**Kaldı:**

- **Adım 3'ün ikinci kutusu (27 maddelik elle doğrulama) ve adım 4, 5, 6.**
  Engel teknik: simülatöre dokunma/yazma yapılamıyor, çünkü Claude Code'un
  simülatör aracı `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
  çalıştırılmadan açılmıyor. Komut şifre istediği için Mert'in çalıştırması
  gerekiyor; sonrasında 27 madde, kör düzeltilmiş üç yer, StoreKit ve ekran
  görüntüleri sırayla geçilebilir.
- `xcode-devir.md` §6'daki açık işlere (bina 4 kattan sonra okunmuyor, sektör
  sayısı, dengedeki iki sayısal kaygı) bu oturumda dokunulmadı.
- Değişiklikler commit edilmedi; çalışan kopyada duruyor.

