# Claude Code Başlangıç Promptu

> **Kullanım notu (bu kısmı yapıştırma):** Aşağıdaki bloğun tamamını Claude Code'a ver, yanına da `oyun-tasarim-raporu.md` dosyasını projeye koy. Prompt bilerek fazlarla yazıldı — tüm oyunu tek seferde isteme, Faz 0'ı tamamlatıp derlendiğini gördükten sonra "Faz 1'e geç" de. Tek seferde 8 sektörlük oyun isteyen prompt, derlenmeyen 200 dosya üretir.

---

## PROMPT BAŞLANGICI

Bir iOS oyunu geliştiriyoruz. Sen bu projenin baş geliştiricisisin: hem mimariyi hem görsel tasarımı sen kuracaksın. Ben ürün sahibiyim, kararları birlikte vereceğiz.

Projenin tam tasarım dokümanı repoda `docs/oyun-tasarim-raporu.md` içinde. **İlk iş olarak onu oku.** Aşağıdaki talimatlar o dokümanın üstüne gelen teknik ve görsel yönergedir; çelişki olursa bana sor, kendi kafana göre karar verme.

---

### 1. Ürün özeti

Türkçe, ücretsiz bir mobil iş simülasyonu oyunu. Oyuncu küçük bir işletmeyle (kahve arabası, tamir tezgâhı veya kurye servisi) başlar, kendi eliyle çalışır; sonra eleman tutar, ekipman alır, süreç kurar ve iş kendi kendine yürümeye başlar. Olgunlaşan işi satıp bir üst kata çıkar. Ekranda tek bir bina var ve bu bina kat kat yükseliyor — her kat bir sektör, kat içindeki hücreler o sektörün şubeleri. 30-45 günde holdinge ulaşılıp oyun bitiyor.

Tür: idle / incremental. Oyun kapalıyken de kazanç birikir. Kısa seanslar için tasarlandı ama isteyen için altında bir kural/otomasyon katmanı var.

Ton: sıcak, hafif mizahi. Elemanların isimleri ve huyları var. Kurumsal ciddiyet değil, mahalle esnafı samimiyeti.

---

### 2. Teknik kısıtlar — bunlar pazarlığa kapalı

- **Swift 6**, strict concurrency açık. Uyarı bırakma.
- **SwiftUI**, iOS 17.0+. UIKit'e sadece zorunlu yerlerde (haptics, StoreKit) in.
- **Sıfır üçüncü parti bağımlılık.** SPM paketi ekleme. Firebase yok, Lottie yok, hiçbir şey yok.
- **SpriteKit kullanma.** Bu oyunun tamamı SwiftUI ile çizilebilir; fizik motoruna ihtiyaç yok. Animasyonlar `withAnimation`, `TimelineView`, `Canvas` ve `PhaseAnimator` ile yapılacak.
- **Sadece portre.** Landscape desteği yok.
- Ağ bağlantısı yok. Oyun tamamen çevrimdışı çalışır.
- Reklam SDK'sı **henüz yok**. Monetizasyon sonraki faz.

---

### 3. Mimari — katmanları karıştırma

Dört katman, aralarında tek yönlü bağımlılık:

```
Views (SwiftUI)
   ↓ okur
GameStore  (@Observable, timer, kalıcılık, scene phase)
   ↓ çağırır
GameEngine (saf, Sendable, UI bilmez, test edilebilir)
   ↓ okur
GameState (Codable struct) + BalanceConfig (JSON'dan yüklenir)
```

**GameEngine saf fonksiyonlardan oluşacak.** İmza şöyle olsun:

```swift
static func advance(_ state: GameState, by seconds: TimeInterval, config: BalanceConfig) -> GameState
```

İçinde `Date()`, `Timer`, `UserDefaults`, hiçbir yan etki olmayacak. Bu kural sayesinde tüm ekonomiyi UI olmadan test edebiliriz — ve edeceğiz.

**Denge sayıları koda gömülmeyecek.** Tüm katsayılar, fiyatlar, süreler, eğri parametreleri `Resources/balance.json` içinde. `BalanceConfig` bunu `Codable` ile okur. Bir fiyatı değiştirmek için Swift dosyasına dokunmak gerekiyorsa yanlış yapmışsındır.

---

### 4. Kritik teknik kurallar

Bunlar idle oyunlarda projeyi batıran yerler. Her birine dikkat et:

**4.1 — Çevrimdışı kazanç zaman damgasıyla hesaplanır, timer'la değil.**
`GameState.lastSeenAt: Date` sakla. Uygulama `.background`'a geçince kaydet, `.active`'e dönünce `Date().timeIntervalSince(lastSeenAt)` kadar ilerlet. Timer arka planda çalışmaz, buna güvenme.

**4.2 — `advance(by:)` kapalı-form olmalı, döngü değil.**
8 saatlik farkı hesaplarken 28.800 kez tick simüle etme. Üretim oranı sabit veya parçalı sabitse doğrudan çarp. Kapasite dolması gibi kırılım noktaları varsa yalnızca o noktalar arasında segment segment hesapla. Kullanıcı 3 gün sonra döndüğünde uygulama donmamalı.

**4.3 — Saat manipülasyonuna karşı korun.**
Negatif zaman farkı → 0 kabul et ve `lastSeenAt`i güncelle. Ayrıca çevrimdışı kazanca üst sınır (başlangıçta 2 saat, yükseltmelerle 24 saate kadar) uygula. Sunucu yok, mükemmel koruma da yok — amaç kazara/kolay istismarı engellemek.

**4.4 — Para `Double`, gösterim biçimlendirilmiş.**
Türkçe kısaltmalar: `1,2 B` (bin), `3,4 Mn`, `5,6 Mr`, `7,8 Tn`. `NumberFormatter`ı her çağrıda yaratma, bir kez oluştur. Sayı gösteren tüm `Text`lerde `monospacedDigit()` kullan — rakamlar zıplamasın.

**4.5 — UI timer sadece görsel, ekonominin kaynağı değil.**
1 Hz'lik bir `TimelineView` yeterli. Ekonomi her zaman zaman damgası farkından türetilir; timer sadece "ne zaman yeniden hesapla" der.

**4.6 — Kayıt atomik olmalı.**
`GameState`i JSON olarak Application Support altına yaz, `.atomic` seçeneğiyle. Bozuk kayıt durumunda yedek dosyadan dön. Oyuncunun 3 haftalık ilerlemesini kaybetmek, bu türde tek affedilmez hatadır.

**4.7 — Testler.**
`GameEngineTests` hedefi olacak ve en az şunları kapsayacak: 1 saniyelik ilerleme, 8 saatlik çevrimdışı ilerleme, kapasite sınırının doğru uygulanması, negatif zaman farkı, eleman alımının üretimi doğru artırması, kayıt/yükleme gidiş-dönüşü.

---

### 5. Görsel yön

Buradaki fikir şu: **palet oyuncunun yükselişini anlatır.** Zemin katta el boyası esnaf estetiği var — emaye tabela, çini fayans, boyalı duvar. Yukarı çıktıkça renkler soğuyor, yüzeyler camlaşıyor, tipografi düzleşiyor. Oyuncu kat değiştirdiğinde bunu hissetmeli, kimse ona söylemeden.

**Palet — zemin katlar (esnaf katmanı):**
- Emaye mavi `#1D5B79` — tabela ve ana çerçeve
- Fıstık yeşili `#4C7A55` — fayans, ikincil yüzeyler
- Hardal `#D9A441` — vurgu, para, ödül anları
- Boyalı duvar `#E9E4D6` — arka plan
- Mürekkep `#23282B` — metin

**Palet — üst katlar (kurumsal katman):**
- Cam gri `#8FA3B0`
- Beton `#52616B`
- Aynı hardal vurgusu devam eder — tek süreklilik o. Para hep aynı renk.

Bu iki palet arasında geçiş sert olmasın; ara katlarda karışsın.

**Tipografi:** İki aile. Başlıklar ve rakamlar için sıkışık, karakterli bir grotesk (Archivo veya Archivo Condensed öneriyorum — Türkçe glif desteği tam: ı, İ, ğ, ş, ç, ö, ü). Gövde metni ve arayüz için sistem fontu (SF Pro). Rakamlarda tabular figür şart.

**Türkçe karakter kontrolü:** Seçtiğin her fontu `ığüşöçİĞÜŞÖÇ` ile test et. Eksik glifi olan fontu kullanma, bu Türkçe oyunda affedilmez.

**Kaçınman gerekenler:**
- Her şeyin aynı köşe yuvarlaklığında, aynı gri gölgeli kart olduğu jenerik SaaS görünümü
- Büyük harfli minik etiketler ("KAZANÇ", "SEVİYE") — cümle düzeni kullan
- Sürekli gradient dolgular
- Her bölümde ayrı ayrı fade-in animasyonu

**Cesaretini tek yere harca:** Binanın kendisi. O ekranın kahramanı. Yan paneller, butonlar, sayaçlar sakin ve disiplinli kalsın.

**Hareket:** Sadece oyuncunun eylemine cevap veren animasyon. Para kazanıldığında yukarı süzülen rakam, eleman işe alındığında kata yerleşme animasyonu, kat açıldığında binanın yükselmesi. Bunun dışında ekran sakin dursun. `accessibilityReduceMotion` her animasyonda kontrol edilecek.

**Dokunsal geri bildirim:** Para kazanma, yükseltme alma, kat açma anlarında haptics. Ama her dokunuşta değil — değerini kaybeder.

**Metin dili:** Türkçe, sen-dili, sade fiiller. Buton ne yapacağını söyler ("Eleman tut", "Gönder" değil). Boş ekran davet eder, özür dilemez.

---

### 6. Fazlar

**Şu an sadece Faz 0'ı yap. Bitince dur ve bana göster.**

**Faz 0 — İskelet ve motor (şimdi yapılacak)**
- Xcode projesi, hedef iOS 17, portre, Swift 6
- Klasör yapısı: `Models/`, `Engine/`, `Store/`, `Views/`, `Resources/`, `Tests/`
- `GameState`, `BalanceConfig`, `GameEngine`, `GameStore`
- `balance.json` — tek sektör (kahve arabası) için başlangıç değerleri
- Kayıt/yükleme + scene phase entegrasyonu
- Çalışan test hedefi (yukarıdaki 6 test)
- **Görsel:** tek ekran, çıplak. Sadece para sayacı, üretim butonu, "eleman tut" butonu. Tasarım henüz yok, motorun döndüğünü görelim.
- Kabul kriteri: uygulama açılıyor, para artıyor, kapatıp 5 dakika sonra açınca çevrimdışı kazanç doğru geliyor, tüm testler geçiyor, sıfır uyarı.

**Faz 1 — Çağ 0→1 geçişi ve görsel kimlik**
Bölüm 5'teki tasarım yönüyle zemin kat, elle üretim, ilk eleman alımı, çevrimdışı kazancın açılması. Test edeceğimiz tek soru: ilk elemanı tutma anı tatmin edici mi?

**Faz 2 — Ekipman katmanı ve şubeler**

**Faz 3 — İkinci sektör, kat açma, bina yükselme animasyonu**

**Faz 4 — Olaylar ve rakipler**

**Faz 5 — Süreç/kural katmanı (çatı katı)**

**Faz 6 — Yumuşak prestij, sektör satışı, final**

**Faz 7 — Monetizasyon (ödüllü reklam + StoreKit 2 ile tek seferlik reklamsız alımı), App Store hazırlığı**

---

### 7. App Store hazırlığı (Faz 0'da kurulacak, sonra unutulmasın)

- Bundle identifier ve display name'i bana sor, uydurma
- `PrivacyInfo.xcprivacy` dosyası oluştur; MVP'de hiçbir veri toplanmadığını beyan et
- App Icon için tüm boyutlar (asset katalogda tek 1024×1024 yeterli)
- Launch screen — açılışta beyaz flaş olmasın, oyunun arka plan rengiyle aynı
- Türkçe birincil dil, `Localizable.strings` yapısı baştan kurulsun (İngilizce sonra eklenecek)
- İlerideki reklam entegrasyonu için ATT gerekecek; şimdi ekleme ama mimariyi buna kapatma

---

### 8. Yapmanı istemediğim şeyler

- Bana kod bloğu gösterip "işte dosya" deme; dosyaları gerçekten oluştur
- Faz 0'ı bitirmeden Faz 1'e geçme
- Denge sayılarını View içine yazma
- Ekonomiyi `Timer.publish` üstüne kurma
- Force unwrap (`!`) kullanma
- Emin olmadığın ürün kararını kendin verme — sor
- Derlenmeyen kod bırakma; her fazın sonunda proje temiz derlenmeli

---

### 9. Şimdi başla

1. `docs/oyun-tasarim-raporu.md` dosyasını oku
2. Faz 0 için somut bir dosya listesi ve `GameState` şemasını bana **önce** göster, onay al
3. Onaydan sonra kodu yaz
4. Bitince: nasıl çalıştıracağımı, testleri nasıl koşacağımı ve hangi kararları senin verdiğini özetle

## PROMPT SONU
