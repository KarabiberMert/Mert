# Xcode'a devir

Proje yedi fazın sonunda, ama **hiç derlenmedi**. Bu dosya Mac'te ilk oturumda
ne yapılacağını ve nelerin açık kaldığını sırayla anlatır.

---

## 1. Nerede duruyoruz

| | |
|---|---|
| Kod | 33 Swift dosyası, ~7.200 satır |
| Test | 14 dosya, 191 test, ~3.600 satır |
| Dil | 212 anahtar × 3 dil (en kaynak, tr ve es çeviri) |
| Denge | `balance.json` v7 — 2 sektör (kahve, fırın) |
| Kayıt şeması | 7 · şema 1'den beri her sürüm açılıyor |
| Sürüm | `MARKETING_VERSION 1.0` · `CURRENT_PROJECT_VERSION 1` |

Yedi fazın hepsi bitti: motor ve kalıcılık, zemin katın görsel kimliği, ekipman
ve şubeler, kat kat bina, olaylar ve rakipler, süreç katmanı, yumuşak prestij
ve final, monetizasyon ve App Store hazırlığı.

## 2. Ne doğrulandı, ne doğrulanmadı

Bu ayrım önemli — ikisini karıştırmayalım.

**Doğrulandı** (bu konteynerde çalıştırılarak):

- `scripts/check_rules.sh` — force unwrap, `Timer.publish`, SpriteKit, motor
  saflığı, View'a gömülü denge sayısı: hiçbiri yok
- `scripts/check_localization.py` — üç dilde anahtar ve yer tutucu eşleşmesi
- `scripts/lint_pbxproj.py` — proje dosyasının yapısı ve referansları
- `scripts/check_store_copy.py` — mağaza metinlerinin karakter sınırları
- `scripts/balance_report.py` — ilerleme eğrisi, satış/kurulum oranı, pazar eşikleri
- Sembol çözümü: her `L.*`, `Palette.*`, `GameEngine.*`, `store.*` çağrısının
  karşılığı var; ölü dil anahtarı yok
- Geometri: bant katmanlarının çakışmadığı, çatının ve kepenkli katın
  ölçülerinin tutarlı olduğu — hem testlerde hem Python simülasyonunda

**Doğrulanmadı** (Mac gerekiyor):

- **Derleme.** Swift 6 kesin eşzamanlılık altında tek satır bile derlenmedi.
- **Testler.** 191 test yazıldı, hiçbiri çalıştırılmadı.
- **Çalışma zamanı.** Uygulama hiç açılmadı. Düzen, animasyon, dokunma
  hedefleri, kaydırma, sayfa katmanları — hiçbiri ekranda görülmedi.
- **StoreKit.** Satın alma akışı ne simülatörde ne cihazda denendi.
- **Denge hissi.** Sayılar tabloda tutarlı; oynanınca nasıl hissettirdiği belirsiz.

## 3. Mac'te ilk oturum

Adım adım çalışma sayfası ve oturum günlüğü:
[`local-ilk-oturum.md`](local-ilk-oturum.md). Aşağısı onun özeti.

En riskliden başla; her adım bir öncekine bağlı.

**1. Aç ve derle.** Xcode 16+. `NotOnMyShift.xcodeproj`. Şema `NotOnMyShift`.
Beklenti: birkaç Swift 6 izolasyon hatası. Aşağıdaki dördü en olası yerler.

**2. Testleri koştur** (⌘U). 191 test. Kırılan olursa çoğu muhtemelen bir
kurulum ayrıntısıdır, motor mantığı değil — testler motoru kâğıt üstünde
defalarca doğruladı.

**3. Simülatörde aç.** iPhone 16 Pro Max, portre. İlk bakılacaklar:
`README.md`'deki "Elle doğrulama" listesi, 27 madde, sırayla.

**4. Satın almayı dene.** StoreKit yapılandırması paylaşılan şemaya bağlı,
ek ayar yok. Satın al, sonra Reklamsız rozetinin kaybolduğunu ve dönüş
özetinde katlamanın sorulmadan uygulandığını gör.

**5. Ekran görüntülerini çek.** `docs/app-store-screenshots.md` her karede
hangi oyun durumuna gelmen gerektiğini yazıyor. `build/mockups/` altındaki
maketler kompozisyon şablonu.

## 4. Derlerken beklenen yerler

Bunlar tahmin, hata listesi değil — ama ilk bakılacak yerler bunlar.

| Yer | Neden şüpheli |
|---|---|
| `StoreKitPurchases.deinit` | `@MainActor` sınıfın nonisolated `deinit`'i `updates` görevine erişiyor. `Task` Sendable olduğu için geçmeli; geçmezse görevi tutmayı bırak. |
| `HouseAds.present()` | `withCheckedContinuation` + `@Observable`. Devamlılık `@ObservationIgnored`; izolasyon uyarısı çıkarsa `finish` tarafına bak. |
| Varsayılan argümanlar | `GameStore.init` içinde `MemoryPurchases()` ve `NoAds()` — `@MainActor` bağlamda değerlendirilmeleri gerekiyor. |
| `Canvas` kapanışları | `FloorBandView` ve `RoofBandView` `self`'i yakalıyor. Sağlayıcı `@Sendable` isterse tüm saklı alanlar Sendable — öyleler. |
| Test içindeki `StubAds` | `@MainActor` protokole uyan iç içe sınıf; açıkça işaretlendi ama derleyici farklı düşünebilir. |

## 5. Çalıştıktan sonra ilk bakılacaklar

Derleme geçtiğinde ekranda ilk kontrol edilecek üç şey — üçü de kör
düzeltildi, gözle görülmedi:

1. **Sponsor arası sahnesinin katmanı.** Dönüş özeti bir `.sheet`; sahne onun
   üstünde mi çıkıyor? (Bir `ViewModifier`'a taşındı, sayfa kendi katmanında
   taşıyor.) Katlama düğmesine bas, geri sayımı gör.
2. **Panelin 196 noktalık şerit yüksekliği.** Beş sekmeli hâlde sekme
   başlıkları sığıyor mu, `minimumScaleFactor` devreye giriyor mu?
3. **Binanın dikey dengesi.** Çatı açıkken üç bant + kaldırım. Zemin katın
   1,35 katı yüksekliği ekranda doğru mu duruyor?

## 6. Açık işler

Öncelik sırasına göre. İlk ikisi tasarımın kendi hedefini tutturmak için şart.

### Bina 4 kattan sonra okunmuyor

`BuildingLayout.minimumBandHeight` 74 nokta. Bina alanı ~393 noktayken:

| Kat (çatı dahil) | Bant | |
|---|---|---|
| 2 + çatı | 125 nokta | okunur |
| 3 + çatı | 94 nokta | okunur |
| 4 + çatı | 75 nokta | sınırda |
| 5 + çatı | 62 nokta | okunmaz |
| 8 + çatı | 41 nokta | okunmaz |

Rapor §5 **6-8 sektör** istiyor. Bugün 2 sektör var, sorun görünmüyor; üçüncü
sektör eklendiğinde görünmeye başlayacak. Çözüm seçenekleri: binayı kaydırmak
(asansör zaten raporda navigasyon olarak geçiyor), alt katları katlanmış
çizmek, ya da kamerayı seçili kata odaklamak. Bu bir tasarım kararı — sana ait.

### Sektör sayısı

`balance.json`'da iki sektör var, hedef 6-8. Yeni sektör eklemek üç dosyaya
dokunuyor: `balance.json`'a bir `sectors` girdisi, üç dil dosyasına
isim/tabela/satış fiili, `SectorFittings`'e iki çizim. Motor tarafında kod
gerekmiyor. Mağaza açıklaması bilerek sektör sayısı vermiyor, yani metin
yeniden yazılmıyor.

### Denge: iki sayısal kaygı

**Dördüncü hücre pratikte açılamayabilir.** Taban paydan (%20) dördüncü hücre
eşiğine (%87) çıkmak 19 yatırım gerektiriyor, pay ise günde 12,1 puan
rakiplere kayıyor. Günde bir kez oynayan oyuncu bu eşiği hiç geçemeyebilir.
`sharePerPurchase` yükseltilebilir ya da `driftPerSecond` düşürülebilir.

**Depo geç oyunda anlamsızlaşıyor.** Fırın tepe netinde 24 saatlik depo 188M
tutuyor; oyunun tamamı ~10,4M. Yani bir noktadan sonra tavan hiç dolmuyor ve
"depo doldu, gel" geri dönüş sebebi ölüyor. Kapasiteyi mutlak saniye yerine
üretime oranlı yapmak ya da geç oyunda başka bir dönüş sebebi koymak gerek.

`scripts/balance_report.py` iki sayıyı da her değişiklikten sonra yazar.

### Ertelenmiş, bilerek

- **Reklam SDK'sı yok.** Sıfır bağımlılık kuralı. `RewardedAds` protokolü
  yerinde; bir sağlayıcı gelirse `NotOnMyShiftApp` içindeki tek satır değişir.
- **ATT ve `SKAdNetworkItems` yok.** Gerçek reklam gelmeden kullanılmayan izin
  metniyle App Review'a çıkmak doğru değil.
- **Ekran görüntüleri maket.** `build/mockups/` altındakiler kaynaktan
  çizilmiş; mağazaya gerçek uygulamadan çekilenler gitmeli.

## 7. Yayına giden yol

1. Derle, testleri koştur, simülatörde 27 maddeyi geç
2. Cihazda dene — özellikle çevrimdışı kazanç (uygulamayı kapat, saati ileri al)
3. Satın alma ve geri yüklemeyi dene (StoreKit yapılandırması şemada hazır)
4. Ekran görüntülerini üç dilde çek (6,9" ve 6,7")
5. App Store Connect: uygulama kaydı, `com.karabibermert.notonmyshift.noads`
   ürününü oluştur ve fiyatını ver
6. `docs/app-store-metadata.md`'deki metinleri alan alan gir
7. Yaş derecelendirmesi: uygulama içi satın alma var, üçüncü parti reklam yok
8. Destek ve gizlilik politikası bağlantıları (Apple ikisini de şart koşuyor)
9. TestFlight, sonra inceleme

Bir ila üç arası hafta sonu işi; asıl belirsizlik birinci adımda.
