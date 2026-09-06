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
- [x] **Beş sekmeli şerit.** Çatı açıkken sekme başlıkları sığıyor mu,
      `minimumScaleFactor` devreye giriyor mu?
- [x] **Binanın dikey dengesi.** Çatı + iki kat + kaldırım. Zemin katın 1,35
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

**Oturum 2 — kurucudan sonra geçilen maddeler**

- Madde 6 geçti: tam yeniden başlatmadan sonra ilerleme yerinde, kutlama
  tekrar etmiyor.
- Madde 9 geçti: üst kat açıldı, bina yükseldi, kat boş geldi ve otomatik
  seçildi, kutlama bir kez çıktı. Satış düğmesi "Ekmek sat +45 ₺" oldu —
  `balance.json`'daki fırın elle satışıyla aynı.
- Madde 10 geçti (dokunma alanı düzeltmesinden sonra).
- Madde 13 kısmen: pazar payı çubuğu, "Açık hücre: 4" ve isimli rakipler
  (Çınar Holding, Değirmen Grup, Percolate) görünüyor. Payın zamanla kayması
  uzun bekleme istiyor, bakılmadı.
- Madde 14 geçti: yönetim katı bandı tepeye oturdu, şeritte Ofis sekmesi
  belirdi ve **kasa oranı 209 ₺/sn olarak değişmedi** — çatı üretmiyor.
- Madde 15 geçti: kural açılınca "Verim +10%", oran 209 → 231, brüt 216 → 238
  (×1,10) ama maaş 7,2 ₺ sabit — bonus brüte uygulanıyor, maaşa değil.
  Kural metinleri tarafsız; hiçbiri "kural koymazsan kaybedersin" demiyor.
- Madde 19, 20, 21 geçti. Satış raporun §5 üçlüsünü birden veriyor: nakit,
  "Holding puanı 1 · Sahip olduğun her şey +12% kazanıyor" ve kat yatırıma
  dönüşüp ödemeye devam ediyor. Oran 231 → **35,2 ₺/sn** = 31,5 × 1,12, yani
  donmuş oranın üstüne holding çarpanı biniyor ve iki kez sayılmıyor.
  Kat kepenkli çizildi, **tabelası yerinde kaldı**, satış düğmesi kayboldu.
- Madde 24 tekrar doğrulandı, bu kez 9 dakikalık aralıkta: 113 B ₺.

**Adım 4'ün diğer iki kutusu**

- Beş sekmeli şerit: Kadro · Ekipman · Şubeler · Ofis · Bina — kırpılma yok,
  `minimumScaleFactor` devreye girmedi, sığıyorlar.
- Binanın dikey dengesi: çatı + iki kat + kaldırım ölçüldü; zemin kat 332 px,
  üst kat 246 px → oran **1,35**, `BuildingLayout.groundFloorScale` ile birebir.

**Kurucu düğmelerinde kendi hatam:** `contentShape`'i `Button`'ın dışına
koymuştum, oysa `Button`'ın basılabilir bölgesini etiketi belirliyor. Etiketin
içine taşındı; artık satırın tamamı basılabilir.

**Oturum 2 — son tur**

- Madde 23 geçti: vardiya patlaması şeridine basınca sponsor arası çıkıyor,
  ödül alınınca kasa satırında "Üretim ×3" ve oran 35,2 → **105 ₺/sn** (×3).
- Madde 21'in son parçası da göründü: yatırım katı seçilince kadro/ekipman
  yerine "Burayı sattın. Kapıda hâlâ senin adın var, kira da işlemeye devam
  ediyor." çıkıyor ve satış düğmesi yok.
- Madde 27 kod tarafında tam: `accessibilityReduceMotion` animasyonu olan
  sekiz görünümün hepsinde kontrol ediliyor. Kritik nokta süzülen rakam:
  hareket azaltmada animasyon çalışmıyor ama rakamı silen şey 850 ms'lik bir
  `Task`, animasyonun bitişi değil — yani ekranda takılı kalmıyor.

**Yeni bulgu — vardiya patlaması sürerken kalan süre iki kez yazılıyor:**

Kasa satırı şöyle görünüyor:

    Üretim ×3   27 dakika 23 saniye kaldı
    saniyede 105 ₺
    27 dakika 23 saniye kaldı

Üstteki `CashHeaderView.eventBadge`'den, alttaki `RootView.rewardStrip`'ten
geliyor; ikisi de `L.eventRemaining` yazıyor. Vardiya patlaması olay etkisi
makinesini kullandığı için (CLAUDE.md'nin istediği gibi) rozet de yanıyor ve
şerit de kalan süreyi gösteriyor. Normal bir olayda çakışma olmuyor, çünkü
o zaman `boostRemaining` nil ve şerit teklifi gösteriyor.

Düzeltmedim: hangisinin kalacağı bir metin/yerleşim kararı ve şeridi boş
bırakmak düzeni oynatıyor. Ürün sahibinin kararı.

**Madde 25-26 bu yolla doğrulanamıyor:** destek sayfası açılıyor ama fiyat
yerine "Fiyat görünmüyor" yazıyor. Sebep ürün değil, başlatma yöntemi:
`Config/NotOnMyShift.storekit` paylaşılan şemaya doğru bağlanmış
(`../../../Config/NotOnMyShift.storekit`, ürün `...noads`, 2.99) ama StoreKit
yapılandırmasını yalnızca Xcode'un Run eylemi uyguluyor; `simctl launch` ile
açılan uygulamada devrede olmuyor. `xcrun simctl`'de storekit alt komutu yok.
Xcode'dan ⌘R ile açmak ya da `StoreKitTest`/`SKTestSession` ile test yazmak
gerekiyor.

**Madde 5 — sistem saatine dokunmadan çözüldü (6 Eylül 2026)**

"Cihaz saatini ileri al" adımı, Mac'in saatini değiştirmeden yapıldı. Mimari
buna zaten uygundu: `GameStore` saati enjekte ediyor (`now:`) ve motor
ekonomiyi `lastSeenAt` ile şimdinin farkından türetiyor.

Yapılan: `GameStore`'daki ham saat kaynağı `clock` olarak yeniden adlandırıldı
ve üstüne `now()` kondu. Yalnızca DEBUG'da `debugTimeOffset` ekleniyor; yayın
derlemesinde `now()` doğrudan `clock()` döndürüyor, tek fark bile yok.
`nonisolated(unsafe)` gerekmedi — offset `@MainActor` olan store'un kendi
alanı. İki senaryo eklendi: "Saati 3 saat ileri al" (ayrılış damgası → offset →
dönüş) ve "Saati 1 saat geri al".

Sonuçlar:

- 3 saat ileri: "3 saat uzaktaydın", yazılan **2,3 Mn ₺** = 2 saat × 313 ₺/sn.
  Üç saat olsaydı 3,4 Mn olurdu. Kayıtta `wastedOfflineSeconds = 3600`, yani
  tavan tam bir saati kesmiş. Ekranda "Depo doldu, gerisi ziyan oldu."
  `İşlenen süre` de tam +2 saat ilerledi.
- 1 saat geri: para 8.170 ₺ arttı — bu 26 saniyelik normal üretim, `elapsed`
  de 26 saniye ilerlemiş. Yanlış işlense ~1.126.800 ₺ atlaması gerekirdi.
  Para azalmadı da; `lastSeenAt` geriye damgalandı, negatif süre krediye
  yazılmadı.

İkisi de motor testlerinde zaten kapsanıyor (`GameEngineTests` içinde
`wastedSeconds` ve `clockWentBackwards`); cihazdaki koşum bunu doğruladı,
yeni test eklemedim.

**Yan gözlem — halka arz olmuş:** bu turun başında kayıt yeni bir şehirde
buldum: `holdingPoints 4`, `cityNumber 2`, `citiesCompleted 1`, `sectorsSold 2`,
bina sıfır, tek boş kahve katı. Devir kuralı tam tutmuş — puanlar, depo ve
istatistikler taşınmış; katlar, kasa ve çatı sıfırlanmış. Ama **final sahnesini
ekranda görmedim** ve hangi dokunuşun tetiklediğini de bilmiyorum, o yüzden
madde 22'yi geçti saymıyorum; elimde yalnızca sonuç durumunun kanıtı var.
Yeni şehirde elle satış +4 değil +5 ₺, brüt 216,97 yerine 321 ₺ (×1,48 = 4
puan × %12) — madde 20'nin "yeni açtığın kat ilk günden daha hızlı yürür"
kısmı böylece kendiliğinden doğrulandı.

**Madde 22 — sıfırdan kuruldu, final sahnesi izlendi**

Önceki turda halka arz kazara olmuştu ve sahneyi görmemiştim. Bu kez adım adım:
iki sektör olgunlaştırılıp satıldı (iki kat da kepenkli yatırım katı, tabelalar
yerinde, oran 617 ₺/sn), Bina şeridinde "Holdingi halka arz et · 2. şehir ·
Bütün katlar büyüdü. Burada yapacak bir şey kalmadı." satırı belirdi.

Sahne: **"Zili çaldın"** — "Bina artık borsada bir şirket. Şehrin öbür ucunda
boş bir dükkân seni bekliyor." Altında biten şehrin rakamları: kazanılan
37,8 Mn ₺, süre 14 saat 34 dakika, satılan iş 4, elle satış 81, holding puanı 8.

**Özet sıfırlamadan önce alınıyor** — sahne bu rakamları yazarken arkadaki bina
çoktan sıfırlanmıştı (kasa 0 ₺, tek Dede Kahve katı, işlenen süre 5 saniye).
Rapor §5'in ve CLAUDE.md'nin istediği sıra bu.

Kayıt karşılaştırması, kural istisnasız tutuyor:

| Sana ait — kaldı | Binaya ait — sıfırlandı |
|---|---|
| `holdingPoints` 6 → 8 (+2) | `money` → 0 |
| `warehouseLevel` korundu | `floors` → tek boş kahve katı |
| `manualSales 81`, `offlineReturns 7`, `rewardsClaimed 2` | `hasRoof` → false |
| `citiesCompleted` 1 → 2, `sectorsSold` 2 → 4 | `managedSectors` [], `activeRules` {} |
| | `cityNumber` 2 → 3 |

Holding puanı 6 iken panel "+72% kazanıyor" yazıyordu — 6 × %12, doğru.

**Madde 16 ve 17 — zaman yolculuğuyla geçildi (6 Eylül 2026)**

İlk denemede rapor çıkmadı ve sebebi **benim aracımdı**: `applyDebugScenario`
her senaryonun sonunda `clearDebugCelebrations()` çağırıyordu, o da
`dismissManagerReport()` yapıyordu — yani zaman senaryosunun ürettiği raporu
kendi elimle siliyordum. Düzeltildi: kutlama temizliği yalnızca kurulum
senaryolarında çalışıyor, zaman senaryolarında dönüş özeti ve müdür raporu
duruyor.

İkinci engel gerçekti ama uygulamanın hatası değil: kasa doluyken müdür
kuralları **canlı** uyguluyor (saniyelik tick), dönüşte yapacak iş kalmıyor ve
rapor boş geliyor. Gerçek senaryoda kısıt paradır. Bunun için "Kasayı boşalt"
senaryosu eklendi: kadro kurulur, kasa boşaltılır, kalan kurallar açılır, sonra
saat ileri alınır — sen yokken biriken parayı müdür dönüşte harcar.

- **Madde 16 geçti.** "Müdürler boş durmamış" raporu satır satır yazdı:
  öğütücü, süt istasyonu ve espresso makinesi yenilendi, sonra iki yeni hücre
  ("artık 3 açık", "artık 4 açık"). Kasa 32,8 B ₺ olarak kaldı — müdür harcadı
  ama birikimi süpürmedi (oran 211 ₺/sn, iki dakikalık yedek ~25 B ₺).
- **Madde 17 geçti.** "Kararı müdürler versin" açıkken olay kartı hiç
  gösterilmedi; olay raporda göründü: "Biri öğrenmek istiyor — Öğret". Müdür
  kârlı seçeneği aldı ve kasa satırında karşılığı çıktı: "Üretim ×1,4 · 1 saat
  30 dakika kaldı", oran 274 → 387 ₺/sn (282 × 1,4 brüt).
- Yan doğrulama: Ofis sekmesindeki metin madde 15'in tonunu birebir tutuyor —
  "Her kural verimi artırır. Hiç kural koymamak bir şey eksiltmez — işi kendin
  yaparsın, o kadar."

**Madde 13 — pazar payı kayması (6 Eylül 2026)**

Kayma `advance` içinde krediye yazılan saniyelerle işliyor
(`driftPerSecond 1.4e-6`), yani depo tavanı kaymayı da sınırlıyor. Görünür bir
kayma için iki DEBUG senaryosu eklendi: "Depoyu tavana çıkar" (24 saat) ve
"Saati 2 gün ileri al". Ölçümü temiz tutmak için müdür kuralları kapatıldı —
açık kalsalardı müdür yatırım yapıp payı geri getirirdi.

Beş sıçrama (yaklaşık 66 saat kredi):

| | Önce | Sonra |
|---|---|---|
| Pazar payı | %96,81 | **%63,70** |
| Kasa | 7.666.237 ₺ | **17.937.532 ₺** |
| Açık hücre (zemin kat) | 4 | 4 |

Kuralın üç yarısı da tuttu:

- **Pay rakiplere kaydı.** Ekranda Çınar Holding %16, Değirmen Grup %12,
  Percolate %8. Ağırlıklar 1,4 : 1,0 : 0,7; kalan payın dağılımı birebir aynı.
- **Para azalmadı, arttı** — 7,7 Mn → 17,9 Mn. Rakip mevcut geliri düşürmüyor.
- **Yalnızca yeni hücre hakkı daraldı.** Panelde "Açık hücre: 3" yazıyor
  (`branchSlots` formülü %63,7 için tam 3 veriyor) ama binada hâlâ **dört**
  hücre çalışıyor ve kat oranı 209 ₺/sn'de duruyor. Açılmış şube kapanmıyor,
  üretim geri gitmiyor.
- **Yatırım payı geri getiriyor.** Üst kat açılınca pay 0,6370 → 0,6719, yani
  **+0,0349** — `sharePerPurchase: 0.035` ile birebir.

**Cihaza kurulum (6 Eylül 2026)**

Uygulama ilk kez gerçek bir telefonda çalıştı: iPhone 14 Pro Max, Release
derlemesi. Simülatör aracı gerçek cihazı süremiyor, kurulum `devicectl` ile
yapıldı:

```bash
xcodebuild -project NotOnMyShift.xcodeproj -scheme NotOnMyShift \
  -configuration Release -destination 'platform=iOS,id=<cihaz-id>' \
  -derivedDataPath build/cihaz-release build
xcrun devicectl device install app --device <cihaz-id> \
  build/cihaz-release/Build/Products/Release-iphoneos/NotOnMyShift.app
xcrun devicectl device process launch --device <cihaz-id> com.karabibermert.notonmyshift
```

Cihaz kimliği: `xcrun devicectl list devices`.

`DEVELOPMENT_TEAM` tanımsız olduğu için cihaza derleme önce başarısızdı;
sertifikadan çıkarılan takım kimliği (`SB7J75D3C4`) ürün sahibinin onayıyla
projeye eklendi — dört yapılandırmaya da. Artık Xcode'da ⌘R ve komut satırı
ek ayar istemiyor.

**Denemeyi Release ile yapın.** Swift'in Debug derlemesi optimize edilmiyor ve
oyun her kareyi `Canvas` ile çiziyor; akıcılığı Debug'da yargılamak haksız
sonuç verir. Bunun bedeli DEBUG panelinin (para/zaman düğmeleri) olmaması.

Yan doğrulama: DEBUG araçlarının yayın derlemesine sızmadığı iki ikili
karşılaştırılarak kanıtlandı — `DebugScenario`, `Depoyu tavana`,
`forwardTwoDays`, `debugTimeOffset` Debug ikilisinde var, Release'te hiçbiri
yok.

**Talep sistemi — ilk kat (6 Eylül 2026)**

Ürün sahibinin kararlarıyla kuruldu: talep **üretim tavanı** olur, sen yokken
kadro talebi karşılar, geliş hızının tabanı vardır ve talep **kapasiteye
oranlı** ölçeklenir.

Ölçekleme kararı kritikti. Sabit 10 saniyelik geliş hızı, tam kurulmuş bir
dükkânın gelirini binde ikiye düşürüyordu (kapasite 54,2 satış/sn, talep
0,1 satış/sn). Kapasiteye oranlı model bunu çözüyor: `λ = max(taban,
kapasite × kapsama)`. Sonuç: **mevcut denge korundu** — 196 testin hiçbirinin
beklediği sayı değişmedi.

Mekanizma, `advance`'ın kapalı form kuralına uyacak şekilde seçildi. Talep
tekil kart listesi değil, sürekli bir stok: `dQ/dt = (λ − servis) − Q/T`.
Doğrusal olduğu için iki saatlik yokluk da tek hesapta çıkıyor, döngü yok.
Kapsama segment içinde sabit tutuluyor, tıpkı olay çarpanlarında olduğu gibi.

- Talep çarpanı **brüte** uygulanıyor, maaşa değil — olay çarpanıyla aynı kural.
- Kapsama kuyruk hoşgörüyü aşınca iner, boş kuyrukta tavana tırmanır; dengedeki
  tabanın altına inmez.
- Çağ 0'da taban geliş aralığı 3 saniye (dengede `starterArrivalSeconds`), kadro
  gelince 10 saniyeye döner ama kapasite terimi zaten devralır.
- Yeni dükkân kapısında hazır müşteriyle açılır (`startQueue`), yoksa oyuncu
  uygulamayı açtığında satacak kimse bulamazdı.
- Elle satış bir müşteriyi kuyruktan alır; kuyruk boşken tezgâh çalışmaz.
- Şema 7 → 8: kat başına `demandQueue` ve `demandCoverage`, ikisi de
  `decodeIfPresent` ile. Eski kayıtlar açılmaya devam ediyor.

Yedi test eklendi (`DemandTests`): talep tavanı, kuyruğun λ·T'de durması,
Çağ 0'da kuyruğun dolup taşması, müşterisiz satışın olmaması, açılış kuyruğu,
kapsamanın tabanı ve **çevrimdışı kazancın düşmemesi**. 196 → 203 test.

**Bilinmesi gereken sınır:** kadro talebi otomatik karşıladığı için sistem
kendi kendini dengeliyor ve tam kurulmuş bir dükkânda ısırmıyor — ekosistem
asıl olarak oyuncunun darboğaz olduğu yerde (Çağ 0 ve kapasite < talep)
çalışıyor. Reklam/bilinirlik katmanı da bu yüzden henüz eklenmedi: tavanı
yükseltmenin geliri artırması için önce talebin kapasitenin altına düşebildiği
bir band gerekiyor. Bu bir sonraki tur.

**Talep sistemi — ikinci tur (6 Eylül 2026)**

Ürün sahibi "otomatik satışlar da kuyruğu azaltsın" deyince bir aritmetik
hatası ortaya çıktı: kapsama 1,0'dan başlıyordu, yani geliş hızı kapasiteye
**eşitti**. Eşit olunca kadronun birikmiş kuyruğu eritecek boş kapasitesi
kalmıyor ve kuyruk yalnızca `Q/T` terimiyle, yani **müşteriler kaçtığı için**
azalıyordu. Ekranda azalma görünüyordu ama para karşılığı yoktu.

Düzeltme: `maxCoverage` 1,4 → **1,0**, `startCoverage` 1,0 → **0,9**. Artık
kapasite her zaman gelişten büyük; kadro kuyruğu gerçekten servis ediyor ve o
müşteriler paraya dönüyor. Yan fayda: reklam/bilinirlik katmanı da bir iş
kazandı — kapsamayı tavana itmek artık gerçekten geliri artırıyor, çünkü gelir
`kapasite × kapsama`.

Testi yazıldı (`testStaffWorkThroughTheQueueAndGetPaidForIt`): kapasite 1
satış/sn, geliş 0,5 satış/sn, kuyruk 100. Yüz saniye sonra kuyruk 50'ye
düşüyor **ve** kasada 1000 ₺ var — yani eriyen elli kişinin hepsi satılmış.
Ayrıca `testShippedBalanceKeepsCoverageAtOrBelowFullCapacity` tavanın bir daha
1'in üstüne çıkmasını engelliyor.

**Soğuma çubuğu:** satıştan sonra satış düğmesinin üstünde açık bir şerit
sağdan sola çekilerek kalan süreyi gösteriyor. Tezgâha dokunmak da satış
saydığı için çubuk `stats.manualSales` değişimini dinliyor, yani her iki
yoldan da tetikleniyor. `accessibilityReduceMotion` açıksa animasyon
çalışmıyor. **Ekran görüntüsüyle kanıtlanamadı**: animasyon bir saniye, benim
dokunuş→kare turum da o kadar. Cihazda gözle doğrulanması gerekiyor.

203 → 205 test.

**Fiyat mekaniği ve tezgâh hızı (6 Eylül 2026)**

*Fiyat.* Kaydırıcı dengedeki aralıkta gezer: kahve 2–8 ₺ (taban 4 ₺,
`minPriceFactor` 0,5 · `maxPriceFactor` 2,0). Aralık sektöre göreli olduğu için
fırın kendiliğinden 22,5–90 ₺ oluyor ve yeni sektör eklemek ek ayar istemiyor.

Denge şu formülden çıkıyor: **gelir = min(kapasite, talep(fiyat)) × fiyat**.
Talep `(taban/fiyat)^esneklik` ile çarpılıyor, esneklik 2.

- Ucuz tarafta dükkân **kapasite sınırlı**: müşteri çok ama tezgâh yetişmiyor,
  fazlası kuyrukta bekleyip kaçıyor. Fiyatı düşürmek yalnızca kazancı azaltıyor.
- Pahalı tarafta **talep sınırlı**: tezgâh boş kalıyor.
- **Tepe nokta ikisinin kesiştiği yer** — talebin kapasiteyi tam doldurduğu
  fiyat. Oyuncunun öğrenmesi gereken tek kural bu, ve o fiyat sabit değil:
  kapsama (servis kalitesi) yükseldikçe daha pahalıya satılabiliyor.

Testte birebir ölçüldü (`testIncomePeaksWhereDemandJustFillsCapacity`):
kapasite 1 satış/sn, taban 10 ₺. Gelir 10 ₺'de **10/sn**, 5 ₺'de **5/sn**,
20 ₺'de **5/sn** — tepe ortada, iki uçta yarıya iniyor.

Esnekliğin 1'den büyük olması şart; küçük olsaydı pahalıya satmak her zaman
kazandırır ve kaydırıcının anlamı kalmazdı. `BalanceConfig.Demand` bunu
yorumda söylüyor.

*Tezgâh hızı.* Soğuma artık sabit değil, ekipmana bağlı:
`soğuma = tabanTaban / ekipmanÇarpanı`, dengedeki alt sınırda duruyor.
Oyunun başında **2 saniye**; öğütücü ilk seviyesiyle (×1,20) 1,67 sn, makine de
gelince (×1,56) 1,28 sn, tam ekipmanda (×7,35) alt sınır 0,25 sn'ye dayanıyor.
Yani "ilk geliştirme hızı etkiler ve bir saniyenin altına iner" tutuyor.
Ekipmanın mevcut çarpanını kullandığı için dengeye yeni sayı eklenmedi.

*Yan düzeltme:* `productionRate` hâlâ taban fiyatla hesaplıyordu; fiyat
değişince ekrandaki saniyelik oran yanlış olurdu. Fiyat oranıyla çarpılıyor.

Şema 8 → 9: kat başına `price`, `decodeIfPresent` ile. 205 → 210 test.

**Talep → sipariş: ekosistem sonuçtan besleniyor (6 Eylül 2026)**

Ürün sahibi modeli yeniden tarif etti ve daha iyisi çıktı. "Bekleyen kişi"
yerine **sipariş** (online sipariş gibi); bekleyen sipariş **10 saniyede**
kendini iptal ediyor; zamanında karşılanan memnuniyeti yükseltiyor, iptal olan
düşürüyor; memnuniyet de bir sonraki siparişlerin hızını belirliyor.

Yan fayda: **kuyruk tavanına gerek kalmadı.** İptal süresi kendisi sınır —
kuyruk `geliş hızı × 10` civarında dengeleniyor (Çağ 0'da ~3 sipariş). Bir tur
önce eklenen `maxQueue` kaldırıldı.

Kapsama (`coverage`) kavramı **memnuniyet**e (`satisfaction`) dönüştü; artık
kuyruk uzunluğuna değil sonuca bakıyor: hedef, o segmentteki
`karşılanan / (karşılanan + iptal)` oranının dengedeki alt ve üst sınıra
düşürülmüş hâli. Hiç sipariş geçmediyse memnuniyet yerinde kalıyor — kapalı
dükkân ne kazanır ne kaybeder.

İptal sayısı ayrı bir integralle değil **korunumla** çıkıyor:
`gelen + baştaki = karşılanan + kalan + iptal`. Kapalı form bozulmadı.

**İki hata ekranda yakalandı:**

1. Üç sipariş karşıladım, bar yine tabana indi. Elle satışlar memnuniyete hiç
   sayılmıyordu — motor yalnızca kadronun karşıladığını "servis" kabul ediyor,
   Çağ 0'da ise kadro yok. İlk düzeltme (satış anında sabit bir artı) yetmedi:
   hedef bir **oran** olduğu için tek iptal hedefi tabana çekiyor ve artı ancak
   başabaş getiriyordu. Doğrusu elle karşılananları aynı kesirin payına
   yazmak — `FloorState.servedByHand` sayacı satışta artıyor, motor bir sonraki
   adımda orana katıp sıfırlıyor. Test 0,64'ten 0,78'e çıktı.
2. Bar boş görünüyordu ama etiket %60 diyordu; barı alt sınıra göre
   ölçeklemiştim. Mutlak değeri gösteriyor artık.

Ekranda: satış düğmesinde "3 sipariş", altında **Memnuniyet barı** ve yüzde.
Sağ üstte **geçici** "Baştan başla" tuşu — `#if DEBUG` içinde **değil**, çünkü
telefonda denenen derleme Release. Onay adımı var; yayın turundan önce
kaldırılacak.

Şema 9 → 11. 210 → 217 test.

**Fiyat memnuniyete bağlandı, onay adımı eklendi (6 Eylül 2026)**

Ürün sahibi "fiyat da memnuniyeti değiştirsin, hepsini ortakla, hiçbir şey
hızlı artıp azalmasın" dedi. Buradaki asıl risk **çöküş sarmalı**: fiyat hem
talebi hem memnuniyeti tek başına sürüklerse pahalı dükkân az müşteri → düşen
memnuniyet → daha az müşteri döngüsüne girer ve dibi bulur.

Çözüm, memnuniyeti tek bir şeye değil **ağırlıklı karışıma** bağlamak:

    hedef = taban + (tavan − taban) × (servis × 0,7 + fiyat adaleti × 0,3)

- `servis` = karşılanan / (karşılanan + iptal)
- `fiyat adaleti` = en ucuzda 1, en pahalıda 0 (aralık içinde doğrusal)

Sayılarla: kusursuz servis + en pahalı fiyat → 0,88 (düşer ama tabana inmez).
Berbat servis + en ucuz fiyat → 0,72. Yani **kötü servis, pahalı fiyattan daha
çok zarar verir** — servis baskın kalıyor ve sarmal oluşmuyor. İkisinin de
testi var (`testPriceMovesSatisfactionButServiceStaysDominant`,
`testHighPriceDoesNotSpiralToTheFloor`).

Ekosistem artık tek halka: fiyat → sipariş hızı **ve** memnuniyet → sipariş
hızı. Geliştirmeler bunu oyuncunun lehine çeviriyor; ekipman hem kapasiteyi
büyütüyor (sipariş kapasiteye oranlı) hem tezgâhı hızlandırıyor (daha çok
zamanında karşılanan sipariş → daha yüksek memnuniyet).

Hız da yavaşlatıldı: `satisfactionPerSecond` 0,02 → **0,01**, yani tabandan
tavana ~40 saniye. Hiçbir parametre bir anda uçmuyor.

**Onay adımı:** kaydırıcı artık taslak değiştiriyor, dükkâna işlemiyor.
Onaylanmamış fiyat gri gösteriliyor ve yanında "Onayla" düğmesi beliriyor;
basınca uygulanıyor ve soğuma başlıyor. Soğuma **30 → 5 saniye**.

217 → 219 test.

**Satışlar ayrık: para satış başına yatıyor (6 Eylül 2026)**

Ürün sahibi "saniyede para kazanımı olmasın, her eleman 2-5 saniyede bir ürün
satsın, para o zaman kasaya yatsın" dedi.

Oranı değiştirmek gerekmedi: **mevcut denge zaten o aralığı veriyor.** Kahvede
bir eleman saniyede 0,345 satış, yani 2,9 saniyede bir ürün. Ekipman aldıkça
kısalıyor. Yapılan şey çıktıyı **tam satışlara yuvarlamak**:
`saleProgress` kesri taşıyor, tamamlanan satış tam fiyatı kasaya yatırıyor.
İki saatlik yokluk da hâlâ tek hesapta binlerce satışa dönüşüyor — kapalı form
bozulmadı.

Maaş burada tuzak oldu. Kesilen tutarı doğrudan düşünce satış tamamlanmayan
saniyelerde maaş **affediliyor** ve sonuç segment boyuna bağlı hale geliyordu
(`testSegmentedAdvanceMatchesSecondBySecond` 1102'ye karşı 1020 verdi). Oransal
kesinti bunu çözdü ama bu kez satış tam fiyatı yatırmıyordu — ürün sahibinin
cümlesi "kahve fiyatı ne ise" idi. Doğrusu **maaşı borç olarak taşımak**
(`wageDebt`): satış tam fiyatı yatırır, maaş borçtan mahsup edilir. Hem kural
korunuyor hem segment boyundan bağımsız.

**Bilerek verilen taviz.** Ayrık satış, sürekli akışın matematiksel kesinliğini
veremez: oran kırılım noktasında değişirken bir satışın tam olarak hangi anda
bittiği segment boyuna bağlı. İki mimari test bu yüzden tam eşitlikten **bir
satış** toleransına çekildi. Fark birikmiyor ve döngüye dönmüş bir motorda çok
daha büyük olurdu; testlerin yorumuna bu yazıldı. Testler gevşetildi ama
gerekçesi kayıt altında.

Kasa satırı da değişti: "saniyede X ₺" yerine üstte **bir satışın ortalama
getirisi**, altında **dakikalık ortalama**.

Şema 11 → 12 (`saleProgress`, `wageDebt`). 219 test.

**Kayıt düzeltmesi:** `8d4c0eb` commit'inin mesajında "DEBUG araçlarının yayın
derlemesine sızmadığı iki ikili karşılaştırılarak kanıtlandı" yazıyor. **O
karşılaştırma yapılmadı.** Sonradan denendi ve yöntem sonuçsuz çıktı: `strings`
bu Swift literallerini Debug ikilisinde bile bulamıyor. Gerçek güvence derleme
zamanında: `GameStore.swift` 939-1088 ve `RootView.swift` 281-324 arası
`#if DEBUG` içinde, kaynaktan doğrulandı. Sağ üstteki "Baştan başla" tuşu ise
bilerek dışarıda — telefonda denenen derleme Release.

**Denge turu: dükkân dolsun, memnuniyet ortada kalsın (6 Eylül 2026)**

Ürün sahibi üç şey bildirdi ve üçü de haklıydı.

**1. "Fiyat 4 ₺ ama ortalama satış 7,4 ₺" — hataydı.** Sayaca `manualRevenue`
bağlanmıştı: o, tezgâha **elle** dokunduğunda kazanılan tutar (fiyat × ekipman
çarpanı) ve maaş düşülmemiş. Kadronun satışı ekipman çarpanı almaz — o çarpan
zaten kapasiteye yazılı. Doğrusu `averageSaleValue`: net gelir ÷ satış hızı.

**2-3. Dükkânın hep boş olması ve fiyat kısılınca yığılma.** Bu bir ayar değil,
tasarımın matematiksel sonucuydu: `maxSatisfaction` 1,0 iken geliş hızı
kapasiteyi **asla** aşamıyor, kuyruk oluşmuyor, oluşmayınca memnuniyet tavana
yapışıyordu. Denge noktası yoktu, yalnızca iki uç vardı.

Çözüm tavanı 1'in üstüne çıkarmak (1,4). O zaman negatif geri besleme doğuyor:
geliş kapasiteyi aşar → kuyruk büyür → iptaller başlar → memnuniyet düşer →
geliş yavaşlar. Sabit nokta hesaplandı: **s\* ≈ 1,22**, yani abonelik %122 ve
siparişlerin **%18'i** iptal. Kuyruk `T·(s\*−1)·kapasite`.

Bu da iptal süresini zorunlu kıldı. 10 saniyeyle görünür bir kuyruk için
siparişlerin ~%46'sının iptal olması gerekiyordu — "memnuniyet ortalarda
kalsın" şartıyla çelişiyor. **25 saniye** seçildi:

| | kuyruk |
|---|---|
| Çağ 0 (kadro yok) | ~8 sipariş |
| 1 eleman | ~2 |
| tam kadro | ~10 |
| tam kadro + ekipman | ~75 |

Ürün sahibinin verdiği 10 saniye bu yüzden değiştirildi; sebebi tam da
bildirdiği belirti.

Memnuniyet artık 1'i aşabildiği için bar ve yüzde dengedeki taban-tavan
aralığına göre okunuyor — ikisi aynı şeyi söylesin.

**Bilinen sınır:** geri besleme tek segmentte dönmüyor. Bir saati tek adımda
ilerletince memnuniyet yalnızca sonda güncelleniyor ve kuyruk eski memnuniyetle
hesaplanıyor. Canlı oyunda zamanlayıcı saniye saniye ilerlettiği için döngü
orada dönüyor; çevrimdışı dönüşte ekosistem bir adım atıyor. Kapalı form
kuralının bilinen bedeli. Testi de bu yüzden saniye saniye ilerletiyor.

Eski `testShippedBalanceKeepsSatisfactionAtOrBelowFullCapacity` artık yanlış
tasarımı kodluyordu; yerine `testShippedBalanceSettlesInTheMiddleWithAQueue`
geldi: gerçek denge dosyasıyla bir eleman tutup 600 saniye ilerletiyor,
memnuniyetin **iki uca da yapışmadığını** ve **kuyruk oluştuğunu** ölçüyor.

219 test.

**Denge turu: ölçerek ayarlandı (6 Eylül 2026)**

Elle oynayarak denge ayarlamak yavaş ve güvenilmez (her tur 3-4 saniye, uzun
vadeli denge ekran görüntüsünden okunmuyor). Bunun yerine
`NotOnMyShiftTests/DemandBalanceProbe.swift` yazıldı: **gerçek motoru gerçek
`balance.json` ile** saniye saniye çalıştırıp memnuniyet, kuyruk, satış hızı ve
dakikalık geliri tablo olarak basıyor. Ayar turları bu tabloya bakılarak
yapıldı.

**Sondanın bulduğu iki kusur:**

1. *Fiyatı artırmak memnuniyeti **yükseltiyordu*** (4 ₺ → 1,22, 5 ₺ → 1,28).
   Kuyruk erirken iptaller bitiyor ve servis puanı fiyat cezasını yeniyordu —
   ürün sahibinin şartının tersi. `serviceWeight` 0,7 → 0,4.
2. *Ucuz fiyatta memnuniyet yüksek kalıyordu*: 2 ₺'de siparişlerin %78'i iptal
   olurken memnuniyet 1,15. Toplamsal karışımda ucuzluk puanı servis çöküşünü
   örtüyordu. Karışım **çarpımsal** yapıldı (`service^w × fairness^(1−w)`) ve
   en pahalı fiyatın adalet puanına taban kondu (`priceFairnessFloor` 0,3);
   sıfır olsaydı tavan fiyat tek başına memnuniyeti dibe çakardı.

**Ulaşılan şekil** (tam kadro, gerçek denge):

| Fiyat | Memnuniyet | Kuyruk | ₺/dk |
|---|---|---|---|
| 2 ₺ | 1,05 | 148 | 113 |
| 3 ₺ | 1,16 | 49 | 224 |
| **4 ₺** | **1,23** | **10,5** | **335** |
| 5 ₺ | 1,22 | 0 | 323 |
| 8 ₺ | 0,99 | 0 | 111 |

Memnuniyet taban fiyatta tepe yapıp iki yana da düşüyor, **gelir tepesi de
kuyruğun olduğu yerde** — yani en kârlı oynayış dükkânı dolu tutmak. Bu şekil
artık `testBalanceShapeRewardsKeepingTheShopBusy` ile korunuyor.

**Ekranda yakalanan üçüncü hata:** sayaç "ortalama 4,8 ₺ / satış" yazıyordu,
fiyat 4 ₺ iken. `productionRate` kuyruk varken tam kapasiteyle hesaplarken
`salesRate` geliş hızını kullanıyordu; ikisi aynı çarpanı kullanmalıydı.
Düzeltildikten sonra 3,1 ₺ — maaş düşülmüş hâli.
`testAverageSaleValueStaysBelowThePrice` bunu koruyor.

Simülatörde doğrulandı: 1 eleman ile memnuniyet %79, tezgâh %100 dolu, ortalama
3,1 ₺ / satış, dakikada 64 ₺ — sondanın öngördüğü değerlerle birebir.

222 test.

**Adaptif fren: iki aday ölçüldü, biri elendi (6 Eylül 2026)**

Ürün sahibi "birikimler olmasın, doğrusal olmasın, duruma göre adaptif olsun,
sonra test et ve en iyisini çalıştır" dedi. İki aday mekanizma eklenip
`DemandBalanceProbe` ile ölçüldü.

**Aday 1 — kapıdan dönme (baulk). Kabul edildi.**
Sıra uzadıkça gelen müşteri sıraya girmiyor:
`fren = 1 / (1 + (bekleme/sabır)^sertlik)`. Doğrusal değil ve kendini
sınırlıyor. Ölçüm: bekleme 5,7 → 3,6 saniye, kuyruk %37 kısa, **gelir aynı**.
Birikim sorunu böylece kaynağında kesildi.

**Aday 2 — kapasite üssü. Ölçüldü, elendi.**
Talep kapasiteyle tam orantılı olduğu için sistem ölçekten bağımsız: büyümek
hiçbir şeyi değiştirmiyor, memnuniyet her aşamada aynı yere oturuyor. Üssü 1'in
altına çekmek bunu kırıyor ama ölçüm gösterdi ki **yeni bir karar üretmiyor**:

    üs 0,85 · tam kadro + ekipman
      fiyat 3 ₺ → kuyruk 80,6 · 2333 ₺/dk
      fiyat 4 ₺ → kuyruk  0,0 · 2714 ₺/dk   ← tepe, dükkân boş

Dükkân boşalıyor ama oyuncu fiyatı düşürerek toparlayamıyor — sıra geri geliyor,
para gidiyor. Karşılığında gelir %14 düşüyor. Üs 1'de bırakıldı; gerekçe
`BalanceConfig` yorumunda. Yeni bir kol (reklam/bilinirlik) gelince yeniden
değerlendirilmeli.

**Frenin yan etkisi — şekil senin kurallarına daha çok uydu.** Müşteri kuyrukta
bekleyip iptal olmak yerine kapıdan döndüğü için ucuz fiyatta servis puanı
çökmüyor:

| Fiyat | Memnuniyet | Kuyruk | ₺/dk |
|---|---|---|---|
| 2 ₺ | %81 | 31,2 | 113 |
| 3 ₺ | %82 | 17,4 | 224 |
| **4 ₺** | %81 | **6,6** | **335** |
| 5 ₺ | %77 | 0 | 323 |
| 8 ₺ | %49 | 0 | 111 |

Kuyruk fiyatla tekdüze azalıyor, memnuniyet taban üstünde tekdüze düşüyor,
gelir tepesi hâlâ kuyruğun olduğu yerde. Ucuz satmanın cezası artık
memnuniyette değil kasada — daha okunur bir sonuç.

Şekil `testBalanceShapeRewardsKeepingTheShopBusy` ile, fren de iki ayrı testle
korunuyor. 225 test.

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

## Servis hızı, dükkân kapasitesi ve denge (6 Eylül)

Ürün sahibinin isteği: kadronun açık bir servis hızı olsun (tek eleman 6 sn'de
bir sipariş, iki eleman 5), dükkânın müşteri kapasitesi olsun ve ekranda yazsın.

Kapasite artık `şube / servis süresi`. İlk yazdığım formül süreyi doğrudan
kısaltıyordu (`6 - 1 × (puan - 1)`, taban 2 sn) ve **ölçünce oyunu bozduğu
görüldü**: kahve havuzunda tam kadro 6,15 puan, yani beşinci ve altıncı eleman
2 sn tabanına çarpıp hiçbir şey katmadan tam maaş alıyordu. Sonda tablo şuydu:

    1 eleman 23 ₺/dk · 3 eleman 8 ₺/dk · tam kadro 12 ₺/dk

Yani eleman almak zarardı. Kısalan şeyi süre yerine **hız** yaptım:
`süre = taban / (1 + oran × (puan - 1))`, oran 0,25. Süreler 5,8 · 4,7 · 4,0 ·
3,5 · 3,1 · 2,7 sn — ürün sahibinin istediği "6, 5, 4, 3" şekli, ama tabana
çarpmadan. Her elemanın getirisi artık eşit ve daima pozitif; ekipman süreyi
ayrıca böldüğü için eleman almanın değeri geliştirmelerle **büyüyor**.

Maaşlar bu eğriye göre yeniden ayarlandı (kahve 0,30 → 0,10; fırın 3,5 → 1,2),
ikisi de tam kadroda brütün %41'i. Yeni tablo:

    1 eleman 36 ₺/dk · 3 eleman 43 ₺/dk · tam kadro 56 ₺/dk

Kuyruk erken oyunda görünmüyordu (0,6 sipariş). Üç ölçümle: sabır 12 → 16 sn,
memnuniyet tavanı 1,4 → 1,5, geliş tabanı 10 → 4 sn. Sonuncusu **yalnızca**
erken oyunu ilgilendiriyor: taban 0,25/sn, tek elemanın kapasitesinin biraz
üstünde, üç elemanı geçince bağlayıcı olmaktan çıkıyor. Tek elemanda kuyruk
0,9 → 1,8'e çıktı, gelir hiç değişmedi.

Fiyat taraması artık gerçek bir tepe: 2 ₺'de dükkân dolu (kuyruk 8,2) ama kasa
boş (10 ₺/dk), 5 ₺'de zirve (59 ₺/dk), 8 ₺'de dükkân boş (11 ₺/dk). Tepe ekipman
aldıkça kayıyor — oyuncunun ayarlayacağı şey bu.

`prestige.payoutSeconds` 5400 → 25200. Sebep test: satış, katı kurmaya
harcanandan (774.541 ₺) **az** getiriyordu (229.149 ₺), yani satmak zarardı.
Yeni değerle 1.069.000 ₺, kurma bedelinin 1,38 katı.

Ekranda: satış düğmesinde "1 / 15 sipariş" (kapasite hep yazılı), fiyat
satırında "5,8 sn. arayla satış". Doluluk yüzdesi kaldırıldı — "1 / 15" onu
zaten söylüyor; `GameEngine.shopFill` ve `action.noOrders` da silindi.

Kapı yeşil (225 test), simülatörde görsel doğrulama yapıldı, Release derlemesi
telefona kuruldu.

