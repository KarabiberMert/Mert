# Not On My Shift

Çevrimdışı çalışan bir mobil iş simülasyonu. İngilizce, Türkçe ve İspanyolca. Küçük bir kahve arabasıyla
başlıyorsun; eleman tutup ekipman alıp süreç kurdukça iş sensiz de yürümeye
başlıyor. Olgunlaşan işi satıp bir üst kata çıkıyorsun — ve ekrandaki bina kat
kat yükseliyor.

Tam tasarım dokümanı: [`docs/oyun-tasarim-raporu.md`](docs/oyun-tasarim-raporu.md)
Geliştirme yönergesi: [`docs/claude-code-prompt.md`](docs/claude-code-prompt.md)

**Durum: Faz 7 — monetizasyon ve App Store hazırlığı. Yedi faz da bitti.**
Bina kat kat yükseliyor, çatıdaki müdürler koyduğun kurallarla işi sen yokken
yürütüyor, olgunlaşan sektörü satıp holding puanı biriktiriyorsun, son kat da
büyüdüğünde holding halka arz oluyor. İsteğe bağlı ödüller ve tek seferlik
"Reklamsız" alımı yerinde; hiçbiri oynamak için gerekli değil.

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
7. **Ekipman** şeridine geç, öğütücüyü yükselt: hem saniyelik gelir hem de
   elle satışın getirisi büyür. Kasa satırında `brüt · maaş` görünür.
8. **Şube** şeridinden ikinci şubeyi aç: binada ikinci bir hücre belirir,
   aynı kadro ve ekipmanla. Üretim de maaş da ikiye katlanır.
9. **Bina** şeridinden üst katı aç: bina yükselir, yeni kat boş gelir ve
   otomatik seçilir. Kutlama bir kez çıkar.
10. Katlara dokunarak aralarında geç. Seçili kat hardal keyline ile işaretli;
    ona dokunmak satış yapar, başka bir kata dokunmak onu seçer.
11. Üst katın paleti hafifçe soğuk: emaye mavi betona, hardal tezgâh cam griye
    kayar. Hardal vurgusu iki katta da aynı.
12. Bir süre oynayınca **olay** kartı çıkar: bir ya da iki dokunuşluk bir
    karar. Süreli bir etki seçersen kasa satırında çarpan ve kalan süre görünür.
    "Şimdi değil" her zaman açık; olay seans başına en fazla bir kez çıkar.
13. **Bina** şeridinde pazar payı çubuğu ve isimli rakipler var. Uzun süre
    uğramazsan pay rakiplere kayar — **paran azalmaz**, sadece yeni hücre
    açma hakkın daralır. Yatırım yapınca pay geri gelir.
14. **Bina** şeridinden **yönetim katını** aç: binanın tepesine alçak, cam
    şeritli bir ofis bandı oturur ve şeritte **Ofis** sekmesi belirir. Çatı
    kendi başına üretmez — kasa satırındaki oran değişmemeli.
15. **Ofis** sekmesinden seçili kata müdür tut, sonra kuralları aç: her açık
    kural katın verimine %10 ekler, tavan %30. Kural açmadan da oyun tam
    verimle çalışır — hiçbir yazı "kural koymazsan kaybedersin" demez.
16. Kuralları açık bırakıp uygulamayı kapat, birkaç dakika sonra dön:
    "Müdürler boş durmamış" raporu ne aldığını satır satır yazar. Müdür kasada
    iki dakikalık yedek bırakır; biriktirdiğin parayı süpürmez.
17. **Kararı müdürler versin**'i aç: olay kartı artık çıkmaz, olaylar sen
    yokken daha kârlı seçenekle kapanır ve raporda görünür.
18. Bir katı sonuna kadar büyüt — tam kadro, bütün ekipman, bütün hücreler.
    **Bina** şeridindeki "Bu işi sat" çubuğu doldukça ilerler; dolunca satırın
    yerini fiyat alır. Çubuk dolmadan hiçbir metin "yapamazsın" demez.
19. **Sat**: kasaya büyük bir para girer, holding puanı bir artar ve kat
    kepenkli bir **yatırım katına** dönüşür — tabelası yerinde kalır ve saniyelik
    kirası işlemeye devam eder. Kutlama bunu satır satır söyler.
20. Kasa satırındaki oran düşer ama **holding puanı bütün katları çarpar**:
    yeni açtığın kat ilk günden daha hızlı yürür. Puan hiç azalmaz.
21. Yatırım katını seç: kadro, ekipman ve şube şeritleri yerine "burayı sattın"
    notu çıkar, satış butonu kaybolur. Kat listesinde de işaretlidir.
22. Bütün katlar büyüdüğünde **Holdingi halka arz et** satırı belirir. Bas:
    final sahnesi biten şehrin rakamlarını yazar ve sonraki şehir açılır.
    Puanların, depon ve istatistiklerin seninle gelir; bina sıfırlanır.
23. Kasa sayacının altındaki **vardiya patlaması** şeridine bas: kısa bir
    "sponsor arası" sahnesi çıkar, geri sayım bitince ödülü alırsın ve kasa
    satırında 30 dakikalık ×3 çarpanı görünür. Erken geçersen ödül yok ama
    hiçbir şey de eksilmez. Seans başına bir kez.
24. Uzun bir süre sonra dön: dönüş özetinde **"… yap"** düğmesi çıkar. Sahneyi
    izle, tutar iki katına çıkar ve yanında "Katlandı" yazar.
25. Sağ üstteki **Reklamsız** rozetine bas: fiyat App Store'dan gelir, satın
    alma ve **geri yükleme** aynı sayfadadır. (Simülatörde test etmek için
    şemaya `Config/NotOnMyShift.storekit` dosyasını StoreKit yapılandırması
    olarak bağla.)
26. Satın aldıktan sonra rozet kaybolur; dönüş özetinde katlama **sorulmadan**
    uygulanır ve vardiya patlaması sahnesiz gelir. Para veren, reklam
    izleyenden yavaş kalmamalı.
27. Ayarlar → Erişilebilirlik → **Hareketi Azalt**'ı aç: süzülen rakam,
    yerleşme ve bina yükselme animasyonu susar, oyun aynı çalışır.

### Dil kontrolü

Ayarlar → Genel → Dil ve Bölge'den uygulama dilini değiştir. Değişmesi
gerekenler: arayüz metni, **kadronun isimleri**, dükkânın tabelası ve
**para birimi** — İngilizce'de `$1.2K`, Türkçe'de `1,2 B ₺`, İspanyolca'da
`1,2 K €`. Mevcut kadro da yeni dilde görünmeli; kayıtta isim değil kimlik
saklanıyor.

### App Store

Faz 0'da kurulan, Faz 7'de tamamlanan liste:

| | Durum |
|---|---|
| Bundle ID | `com.karabibermert.notonmyshift` |
| Görünen ad | Not On My Shift |
| Sürüm | `MARKETING_VERSION 1.0` · `CURRENT_PROJECT_VERSION 1` |
| Dağıtım hedefi | iOS 17.0, yalnızca portre, arm64 |
| Gizlilik bildirimi | `PrivacyInfo.xcprivacy` — hiçbir veri toplanmıyor, izleme yok |
| İkon | `Assets.xcassets/AppIcon` (tek 1024×1024 yeterli) |
| Açılış ekranı | `UILaunchScreen` + `LaunchBackground` rengi — beyaz flaş yok |
| Şifreleme beyanı | `ITSAppUsesNonExemptEncryption = false` |
| Diller | `en` (kaynak), `tr`, `es` — `CFBundleLocalizations` içinde |
| Uygulama içi satın alma | `com.karabibermert.notonmyshift.noads`, tek seferlik, tüketilmeyen |
| Geri yükleme | "Reklamsız" sayfasında — App Review bunu şart koşar |

**Yerel test:** şemaya (Run → Options → StoreKit Configuration)
`Config/NotOnMyShift.storekit` dosyasını bağla. Fiyat orada 2,99 görünür;
gerçek fiyat App Store Connect'te belirlenir, kodda durmaz.

**Henüz eklenmedi, bilerek:** ATT izni (`NSUserTrackingUsageDescription`) ve
`SKAdNetworkItems`. Gerçek bir reklam SDK'sı gelmeden bunları koymak,
kullanılmayan bir izin metniyle App Review'a çıkmak demektir. Mimari buna
kapalı değil: reklam sağlayıcısı zaten `RewardedAds` protokolünün arkasında.

**Yayın öncesi elle yapılacaklar:** mağaza açıklaması ve anahtar kelimeler,
üç dilde ekran görüntüleri, yaş derecelendirmesi (uygulama içi satın alma
var, reklam yok), destek ve gizlilik politikası bağlantıları.

## Tipografi kontrolü

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
| `NotOnMyShift/en.lproj/` | İngilizce metinler (kaynak dil) |
| `NotOnMyShift/tr.lproj/` | Türkçe çeviri |
| `NotOnMyShift/es.lproj/` | İspanyolca çeviri |
| `NotOnMyShiftTests/` | Motor, kalıcılık ve store testleri |
| `Config/Info.plist` | Info.plist (uygulama hedefinin dışında tutuldu) |
| `scripts/` | İkon üretici, pbxproj doğrulayıcı |

### Denge sayıları

Hepsi [`NotOnMyShift/Resources/balance.json`](NotOnMyShift/Resources/balance.json)
içinde. Bir fiyatı değiştirmek için Swift dosyası açman gerekiyorsa yanlış yerdesin.

Bu dosya **sadece sayı ve kimlik** tutar. Ekranda görünen hiçbir metin burada
değil: eleman isimleri, huylar ve dükkânın adı dile göre değiştiği için dil
dosyalarında durur.

### Diller

Kaynak dil İngilizce; `tr` ve `es` çeviri. Yeni dil eklemek bir `.lproj`
klasörü eklemekten ibaret.

Para birimi de dile bağlı: simge, simgenin yeri, ondalık ayracı ve büyüklük
kısaltmaları `format.*` anahtarlarından gelir.

| | `en` | `tr` | `es` |
|---|---|---|---|
| Kalıp | `${amount}` | `{amount} ₺` | `{amount} €` |
| Sayı yereli | `en_US` | `tr_TR` | `es_ES` |
| 10^3 · 10^6 · 10^9 | K · M · B | B · Mn · Mr | K · M · MM |
| Örnek | `$1.2K` | `1,2 B ₺` | `1,2 K €` |

Elemanın kayıtta saklanan şeyi kimliğidir (`quick`, `veteran`), ismi değil —
oyuncu dili değiştirince mevcut kadro da yeni dilde görünür.

### Ekonomi

Ekonomi kat kat: her kat bir sektör, her katın kendi kadrosu, ekipmanı ve
şubeleri var. Kasa ve depo ortaktır.

`kat neti = max(0, brüt − maaş)`, bina neti bunların toplamı. Zarardaki bir kat
kârdaki katı aşağı çekmez; oyuncu asla geri gitmez.

| | Nasıl hesaplanır |
|---|---|
| Brüt | kadro çarpanları × taban oran × ekipman çarpanı × şube sayısı |
| Maaş | eleman sayısı × saniyelik maaş × şube sayısı |
| Elle satış | taban getiri × ekipman çarpanı |

Ekipman maaş ödemez, eleman öder — tasarım raporunun istediği seçim buradan
doğar: makine bir kez ödenir ve her şeyi çarpar. Şube ise kopyadır; kadroyu ve
ekipmanı devralır, ayrı ayarı yoktur.

`python3 scripts/balance_report.py` bu tablonun sayısal karşılığını, olay
etkilerini ve pazar eşiklerini yazar.

### Olaylar

Süren bir olay etkisi üretim oranını kırar, dolayısıyla `advance` artık
**segment segment kapalı form**: kırılım noktaları arasında oran sabit olduğu
için her segmentte tek çarpma yapılır. Etki yoksa tek segment kalır. Adım sayısı
etki sayısı + 1'i geçemez — tick döngüsü değil.

Olay çarpanı brüte uygulanır, maaşa değil. Anlık etkiler mutlak para değil
"mevcut netin kaç saniyesi" olarak yazılır; böylece aynı olay her çağda anlamlı
kalır. Kasa asla eksiye düşmez.

Olay seçimi kayıttaki tohumdan türetilir (`GameEngine.DeterministicRandom`) —
motor saf kalır, aynı kayıt aynı olayları verir.

### Rakipler

Tasarım raporunun cezalandırmama kuralı (§6) koda gömülü: **rakip mevcut geliri
asla düşürmez.** Pazar payı yalnızca *yeni* hücre açma hakkını belirler; açılmış
şube kapanmaz. Pay zamanla rakiplere kayar ve her yatırımda geri gelir, yani
kaçırılan şey para değil fırsattır.

### Süreç katmanı

Çatıdaki yönetim katı süreç katmanını açar. Bir kata müdür tutarsın, o katta
hazır kural tariflerini (eleman al, ekipman yenile, hücre aç) açıp kaparsın —
mobilde kural editörü hızla fazla teknik hâle geldiği için tarifler hazır
gelir (rapor §10.5).

Rapor §4'ün kuralı koda gömülü: **derinlik ceza kaçınma değil, ödüldür.**

| | Kural kurmayan | Kural kuran |
|---|---|---|
| Verim | %100 | %100 + kural başına %10, tavan %30 |
| Emek | ara sıra elle müdahale | hiç dokunmaz |

Yani süreç kurmamak hiçbir şey eksiltmez; kurmak üstüne ekler. Bonus katın
kendisine yazılır — müdürsüz kat etkilenmez.

Müdürlerin alımları `advance` içinde değil ondan **sonra** işlenir
(`GameEngine.applyRules`): satın alma üretim oranını değiştirir ve bunu kapalı
forma katmak motoru döngüye çevirirdi. Alımlar kasada mevcut netin iki
dakikası kadar yedek bırakır ve bir dönüşte sayısı sınırlıdır; müdür oyuncunun
biriktirdiği parayı süpürmez. Ne yaptığını dönüşte rapor eder.

Olayların otomatik kararı ayrı bir tercih ve verim bonusu vermez — saf
kolaylık. Açıkken müdür `bestChoice` ile en kârlı seçeneği seçer ve olay kartı
oyuncuya hiç gösterilmez.

### Yumuşak prestij ve final

Bir sektör olgunlaştığında (tam kadro + tam ekipman + tüm hücreler) satılabilir.
Rapor §5 satışın **üç şeyi birden** vermesini şart koşuyor, üçü de kodda:

| | Ne verir |
|---|---|
| Nakit | katın netinin `payoutSeconds` katı — bir üst katı açmaya yeter |
| Holding puanı | kalıcı çarpan, tüm katların brütünü büyütür, hiç azalmaz |
| Yatırım katı | satılan kat binada kalır ve kirasını ödemeye devam eder |

Üçüncüsü olmadan oyuncu satmaya direnir — sattığı şeyin yok olduğunu sanar. Bu
yüzden kat silinmez: kepenk iner, **tabela yerinde kalır** ve saniyelik pasif
gelir satış anında donmuş bir oranla işlemeye devam eder.

Holding çarpanı olay çarpanıyla aynı kuralı izler: **brüte uygulanır, maaşa
değil.** Yatırım katının kayıttaki oranı hamdır; çarpan çalışma anında üstüne
biner, böylece iki kez sayılmaz.

Her sektöre girildiyse ve her kat satılmış ya da olgunlaşmışsa holding halka arz
olur. Oyun biter, uygulama silinmez: **binaya ait olan sıfırlanır, sana ait olan
kalır** — holding puanı, depo ve istatistikler sonraki şehre taşınır. Halka arz
ayrıca `pointsPerCity` puan ekler; "hızlandırılmış eğri" budur.

`scripts/balance_report.py` satışın kurulum bedeline oranını ve bir şehri
bitirmenin kaç puan ettiğini yazar.

### Ödüller ve satın alma

Rapor §8'in iki kuralı koda gömülü:

| | Kural |
|---|---|
| Ödül zorunlu değil | Hiç izlemeyen, hiç ödemeyen oyuncu oyunu baştan sona oynar |
| Alan otomatik alır | Çevrimdışı katlama hep açık, vardiya patlaması sahnesiz |

İkincisi olmadan para veren oyuncu reklam izleyenden yavaş ilerler — raporun
"en hızlı geri ödeme talebi sebebi" dediği durum. Bu yüzden `hasRemovedAds`
oyuncuya hiç sormaz: dönüş özeti açıldığı anda katlama uygulanmış olur.

Çevrimdışı katlama `resume`'a dokunmaz; özet hesaplandıktan sonra farkı ekler,
yani ödül reddedilirse geri alınacak bir şey olmaz. Vardiya patlaması olay
etkisi makinesini kullanır: `advance` kapalı form kalır ve patlamanın bitişi
sadece bir kırılım noktasıdır.

İki sınır da protokoldür ve oyun kodu ikisinin de arkasını bilmez:

```
GameStore
   ├── Purchases      → StoreKitPurchases (gerçek) · MemoryPurchases (test)
   └── RewardedAds    → HouseAds (oyunun kendi sahnesi) · NoAds (kapalı)
```

Bu sürümde gerçek bir reklam SDK'sı **yok** — proje sıfır üçüncü parti
bağımlılıkla çalışıyor. `HouseAds` oyunun kendi çizdiği "sponsor arası"dır:
burada reklam olmadığını dürüstçe söyler, geri sayımı işletir ve ödülü
gerçekten verir. Böylece akış baştan sona test edilebilir. Bir sağlayıcı
gelirse `NotOnMyShiftApp` içindeki tek satır değişir, oyun kodu değişmez.

Satın alma hakkı kayda yazılmaz; kaynak StoreKit'tir. Bu yüzden "sıfırdan
başla" bir hakkı silemez ve cihaz değiştiren oyuncu geri yükleyebilir.

### Bina, katlar ve şubeler

Kat geniş ve alçak bir **bant**. Bandın yapısı (döşeme, duvar, çini lambri,
zemin) tüm genişlik boyunca sürer; şubeler bandı dikey bölmelerle hücrelere
ayırır — tasarım raporundaki "kat içindeki hücreler" tam olarak bu.

Dikey ölçüler banttan, yatay ölçüler hücreden gelir: hücre daralınca insanlar
ve tezgâh kısalmaz, sadece incelir. Zemin kat sokağa baktığı için daha
yüksektir — tentesi ve kaldırımı var.

Katı katından ayıran şey iki demirbaş: duvardaki ve tezgâhtaki parça
(`SectorFittings`). Kabuk, tezgâh, fayans ve kadro ortak. Yeni bir sektör
eklemek buraya iki çizim eklemekten ibaret.

Palet kat yükseldikçe esnaftan kurumsala karışır (`FloorPalette`): emaye mavi
betona, hardal tezgâh cam griye kayar. Hardal vurgusu değişmez — para hep aynı
renk.

Yönetim katı sektör katı değil: kadrosu, tezgâhı, hücresi yok. Bu yüzden kendi
ölçü takımıyla (`RoofGeometry`) çizilir, normal bir banttan alçaktır ve tamamen
kurumsal paletle gelir — binanın üstüne oturan bir ofis kutusu.

Satılmış kat aynı bandı kullanır, sadece tezgâhın yerine inik kepenk ve kapıya
hardal bir levha gelir (`InvestmentGeometry`). Tabela değişmez: oyuncunun adı
kapıda kalır.

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
python3 scripts/check_localization.py # dil dosyalarında anahtar ve yer tutucu eşleşmesi
python3 scripts/build_fonts.py       # Archivo kesitlerini yeniden üretir (fonttools gerekir)
./scripts/check_rules.sh             # pazarlığa kapalı kuralları tarar
python3 scripts/make_app_icon.py     # 1024×1024 ikonu yeniden üretir
python3 scripts/lint_pbxproj.py      # project.pbxproj yapısını doğrular
```

Hiçbiri uygulamaya üçüncü parti bağımlılık sokmaz. `balance_report.py` bir
sayıyı değiştirdikten sonra eğrinin nereye gittiğini oyunu açmadan gösterir.

## App Store

Faz 0'da kurulan, Faz 7'de tamamlanan liste:

| | Durum |
|---|---|
| Bundle ID | `com.karabibermert.notonmyshift` |
| Görünen ad | Not On My Shift |
| Sürüm | `MARKETING_VERSION 1.0` · `CURRENT_PROJECT_VERSION 1` |
| Dağıtım hedefi | iOS 17.0, yalnızca portre, arm64 |
| Gizlilik bildirimi | `PrivacyInfo.xcprivacy` — hiçbir veri toplanmıyor, izleme yok |
| İkon | `Assets.xcassets/AppIcon` (tek 1024×1024 yeterli) |
| Açılış ekranı | `UILaunchScreen` + `LaunchBackground` rengi — beyaz flaş yok |
| Şifreleme beyanı | `ITSAppUsesNonExemptEncryption = false` |
| Diller | `en` (kaynak), `tr`, `es` — `CFBundleLocalizations` içinde |
| Uygulama içi satın alma | `com.karabibermert.notonmyshift.noads`, tek seferlik, tüketilmeyen |
| Geri yükleme | "Reklamsız" sayfasında — App Review bunu şart koşar |

**Yerel test:** şemaya (Run → Options → StoreKit Configuration)
`Config/NotOnMyShift.storekit` dosyasını bağla. Fiyat orada 2,99 görünür;
gerçek fiyat App Store Connect'te belirlenir, kodda durmaz.

**Henüz eklenmedi, bilerek:** ATT izni (`NSUserTrackingUsageDescription`) ve
`SKAdNetworkItems`. Gerçek bir reklam SDK'sı gelmeden bunları koymak,
kullanılmayan bir izin metniyle App Review'a çıkmak demektir. Mimari buna
kapalı değil: reklam sağlayıcısı zaten `RewardedAds` protokolünün arkasında.

**Yayın öncesi elle yapılacaklar:** mağaza açıklaması ve anahtar kelimeler,
üç dilde ekran görüntüleri, yaş derecelendirmesi (uygulama içi satın alma
var, reklam yok), destek ve gizlilik politikası bağlantıları.

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
