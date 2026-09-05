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

- [ ] `xcodebuild -version` → Xcode 16 veya üstü
- [ ] `xcrun simctl list devices available | grep iPhone` → en az bir iPhone simülatörü
- [ ] `./scripts/mac_kapi.sh --sadece-denetci` → beş denetçi de geçiyor

Denetçiler bu konteynerde geçiyordu; Mac'te de geçmeli. Geçmiyorsa sorun
ortamdadır, kodda değil — önce onu çöz.

### 1. Derle

- [ ] `./scripts/mac_kapi.sh --derle` temiz geçti
- [ ] Sıfır uyarı (CLAUDE.md: "Uyarı bırakma")

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

- [ ] `./scripts/mac_kapi.sh` → 191 testin hepsi geçti

Kırılan olursa önce **testin kendi kurulumuna** bak. Motor mantığı kâğıt
üstünde defalarca doğrulandı; test hiç çalıştırılmadı. Yani ilk şüpheli
`XCTestCase` kurulumu, `@MainActor` izolasyonu ya da geçici klasör
yardımcısı — motorun matematiği değil.

Gerçekten motor hatası çıkarsa: testi değil kodu düzelt, sonra aynı hatayı
yakalayan bir test daha ekle.

### 3. Simülatörde aç

- [ ] Uygulama açılıyor, `BootFailureView` görünmüyor
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

- [ ] **Sponsor arası sahnesinin katmanı.** Dönüş özeti bir `.sheet`; katlama
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

### Oturum 1 — (tarih)

**Yapıldı:**

**Bulundu:** (derleme hataları, kırılan testler, ekranda yanlış görünenler)

**Kaldı:**

