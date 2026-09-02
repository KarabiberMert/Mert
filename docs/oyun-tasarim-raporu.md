# Mobil İş Simülasyonu — Tasarım Raporu

**Çalışma adı önerisi:** *Kat Kat* / *Yükseliş A.Ş.* / *Bir Kahveyle Başladı*

---

## 1. Tek cümlelik konsept

Küçük bir işletmeyi kendi ellerinle işletirken başlarsın; eleman tutup makine alıp süreç kurdukça işin sensiz de yürümeye başlar; her olgunlaşan işi satıp bir üst kata çıkarsın ve 1-2 ay sonunda kat kat yükselen bir holding binası bırakırsın arkanda.

---

## 2. Alınan kararlar

| Konu | Karar |
|---|---|
| Evren | Modern gerçekçi — kafe, atölye, kurye gibi tanıdık işler |
| Ana döngü | Idle, oyun kapalıyken de kazanç |
| Seans yapısı | Kısa seans + isteğe bağlı derinlik |
| Büyüme | Karma: hem şube açma hem yeni sektöre geçiş |
| Otomasyon | Üç katman kademeli — eleman, ekipman, süreç |
| Tekrar oynanış | Yumuşak prestij: eski işi sat, yeniye geç |
| Sunum | Yandan kesit bina, kat kat büyüyen |
| Dış dünya | Olaylar + rakipler birlikte |
| Monetizasyon | Ödüllü reklam + tek seferlik "reklamsız" satın alma |
| Başlangıç | Karakter/hikaye ile belirlenir |
| Süre | 1-2 ay, uzun ama sonlu |
| Ton | Sıcak, hafif mizahi |

---

## 3. Merkezi tasarım fikri: bina = holding

Yandan kesit bina ile "çok işli imparatorluk" ilk bakışta çelişir. Çözüm: **binanın kendisi holdingtir.**

- **Zemin kat:** karakterinin başladığı iş (kahve arabası, tamir tezgâhı, kurye çantası).
- **Her yeni kat:** yeni bir sektör. Kat açmak = sektöre girmek.
- **Kat içindeki hücreler:** o sektörün şubeleri. Kat doldukça o iş kolu olgunlaşır.
- **Çatı katı:** yönetim ofisi. Süreç/kural sistemi burada açılır, holding görünümü buradan izlenir.
- **Asansör:** navigasyon. Aşağı inmek nostalji, yukarı çıkmak hedef.

Bu tek görselde üç fantezi birden okunur: *zincir kurdum*, *sektöre girdim*, *holding oldum*. Ekran görüntüsü de mağaza sayfasında anında anlaşılır — mobil pazarlama için ciddi bir avantaj.

---

## 4. Otomasyon çağları (kademelendirme önerisi)

Üç katmanı aynı anda açmak oyuncuyu boğar. Önerilen sıra — her çağın **kendi "ah, artık gerek yokmuş" anı** var:

**Çağ 0 — Elle (ilk ~20 dakika)**
Oyuncu tıklayarak üretir ve satar. Offline kazanç yok. Amaç: emeği hissettirmek. Bu çağ kısa olmalı; uzarsa oyuncu "bu bir tıklama oyunu" sanıp bırakır.

**Çağ 1 — Eleman (ilk 2-3 gün)**
İlk elemanı tutunca o istasyon otomatikleşir ve **offline kazanç açılır.** Bu, oyunun ilk büyük ödül anı. Elemanların isimleri, yüzleri ve küçük karakter özellikleri olur ("Sevim abla hızlı ama sipariş karıştırıyor"). Mizahi ton buradan beslenir.

**Çağ 2 — Ekipman (3-10. günler)**
Makine yükseltmeleri hız ve kapasite çarpanı verir; ayrıca **eleman ihtiyacını azaltır.** Böylece eleman maaşı ile makine yatırımı arasında gerçek bir seçim doğar.

**Çağ 3 — Süreç (10. günden sonra, çatı katı)**
Müdür ata, kural yaz: "stok %20'nin altına düşerse otomatik sipariş", "yoğun saatte ek vardiya aç", "şubeye kâr %X'in altına inerse uyar". Bu, "isteğe bağlı derinlik" katmanıdır.

### Derinliği cezasız yapan kural

En kritik denge kararı bu:

> Süreç kurmayan oyuncu **%100 verimle** çalışır ama ara sıra elle müdahale etmesi gerekir.
> Süreç kuran oyuncu **%130 verim** alır ve hiç dokunmaz.

Yani derinlik "ceza kaçınma" değil "ödül" olur. Kısa seans oyuncusu geri kalmış hissetmez, derine inen oyuncu ise hem daha hızlı hem daha rahat oynar. Bunun tersi (kural kurmayan cezalanır) kısa seans hedefini doğrudan öldürür.

---

## 5. Ekonomi ve ilerleme eğrisi

**Toplam hedef:** 30-45 gün, 6-8 sektör. Her sektör ortalama 4-6 gün.

**Offline kazanç kapasitesi** — retention'ın kalbi:
- Başlangıç: 2 saat
- Yükseltmelerle: 24 saate kadar
- Kapasite dolduğunda bildirim: "Depo doldu, ürünler bekliyor" — geri dönüş sebebi

**Yumuşak prestij mekaniği:**
Bir sektör olgunlaştığında (tüm şubeler + tüm yükseltmeler) **satılabilir** hale gelir. Satış üç şey verir:
1. Büyük nakit — yeni kat açmaya yeter
2. Kalıcı **Holding Puanı** — tüm gelecek işlere pasif çarpan
3. Binada kalıcı bir iz — satılan kat "yatırım katı"na dönüşür, küçük pasif gelir üretmeye devam eder

Üçüncü madde önemli: oyuncu sattığı şeyin yok olmadığını görür, bu yüzden satmaya direnmez. Klasik prestijin en büyük psikolojik sorununu çözer.

**Sonlu oyunun finali:** Son sektör tamamlandığında holding halka arz olur. Kapanış sahnesi + istatistik özeti + "Yeni Şehir" modu açılır (aynı sistemler, farklı sektör paleti, hızlandırılmış eğri). Böylece oyun biter ama uygulama silinmez.

---

## 6. Olaylar ve rakipler

**Olaylar** kısa seansa yakıt verir: sağlık denetimi, tedarikçi zammı, viral olan bir ürün, mahallede festival. Her olay 1-2 dokunuşluk bir karar sunar. Sıklık: günde 2-3, seans başına en fazla 1.

**Rakipler** isimli şirketler olarak temsil edilir (mizahi ton buraya çok yakışır — "Çınar Holding, kurucusu her röportajda babasından bahsediyor"). Pazar payı çubuğu ile gösterilir.

### Cezalandırmama kuralı

> Rakip, oyuncunun **mevcut gelirini asla düşürmez.** Sadece **kazanılabilecek payı** azaltır.

Yani oyuncu üç gün girmediğinde parası azalmaz; sadece o üç günde açılabilecek yeni şube fırsatını rakip kapar. Kayıp her zaman "gecikme" olarak hissedilir, "geri gitme" olarak değil. Idle oyunlarda oyuncu kaybettiren rekabet, terk oranını en hızlı yükselten şeydir.

---

## 7. Hikaye ve ton

Oyun kısa bir sahneyle açılır ve oyuncu üç karakterden birini seçer:

| Karakter | Başlangıç işi | Pasif özellik |
|---|---|---|
| Dedesinin kahve arabasını devralan torun | Kahve arabası | Müşteri sadakati daha hızlı artar |
| İşten çıkarılmış usta tamirci | Tamir tezgâhı | Ekipman yükseltmeleri %15 ucuz |
| Kuryelikten bıkmış öğrenci | Kurye servisi | Teslimat/lojistik hızı yüksek |

Karakter, başlangıç sektörünü ve küçük bir bonusu belirler — ama sonrasında tüm sektörler herkese açıktır. Böylece tekrar oynanış sebebi olur, kapsam patlaması olmaz.

**Ton araçları:** eleman diyalog balonları, absürt müşteri talepleri, gazete manşetleri, rakip CEO'ların komik açıklamaları. Metin kısa ve atlanabilir olmalı — mizah zorunlu okuma haline gelmemeli.

---

## 8. Monetizasyon

**Ödüllü reklam (isteğe bağlı, asla zorunlu değil):**
- Offline kazancı 2x'le (seans başına 1 kez)
- Anlık "vardiya patlaması" — 30 dakika 3x üretim
- Eleman işe alımını anında tamamla
- Olay sonucunu yeniden çevir

**Tek seferlik "Reklamsız" satın alma — kritik detay:**
Satın alan oyuncu reklam ödüllerini **otomatik olarak** almalı (örn. offline 2x kalıcı açık). Aksi halde para veren oyuncu, reklam izleyenden daha yavaş ilerler ve bu en hızlı geri ödeme talebi sebebidir.

**Sonlu oyunun etkisi:** 1-2 aylık sonlu bir oyun, sonsuz idle oyunlara göre daha düşük oyuncu başı gelir üretir. Buna karşılık daha yüksek tamamlama oranı ve daha iyi mağaza yorumu getirir. Gelir tarafını "Yeni Şehir" sezonlarıyla desteklemek makul — her sezon yeni sektör paleti, yeni rakipler, isteğe bağlı ücretli sezon.

---

## 9. Açık kalan seçenekler

Bunlar henüz karara bağlanmadı. Her biri için alternatifler ve önerim:

### A. Offline kazanç modeli
| Seçenek | Etkisi |
|---|---|
| Sabit birikim (saat başı X) | Anlaşılır, tahmin edilebilir, sıkıcı |
| **Vardiya modeli** — oyuncu çıkarken vardiya kurar, süresi dolunca durur | Çıkışta da bir karar var, daha ilgi çekici |
| Azalan verim — ilk 4 saat tam, sonrası yarım | Sık giriş ödüllendirir, ama kısa seans hedefiyle çelişir |

*Öneri: vardiya modeli.* Karakter/eleman temasıyla da tutarlı.

### B. Eleman sisteminin derinliği
| Seçenek | Etkisi |
|---|---|
| Basit slot (isimsiz, sadece sayı) | Ucuz, ama mizahi ton kaybolur |
| **Kişilikli kadro** — isim, yüz, 1-2 özellik | Ton ve bağlanma için ideal, orta maliyet |
| Tam RPG — yetenek ağacı, moral, terfi, ilişkiler | Zengin ama kapsam riski yüksek |

*Öneri: kişilikli kadro.* Terfi mekaniği sonradan eklenebilir bir genişleme.

### C. Şube yönetimi
| Seçenek | Etkisi |
|---|---|
| **Tek tuş kopyalama** — yeni şube mevcut ayarları devralır | Kısa seans dostu, kesinlikle gerekli |
| Her şube ayrı ayarlanır | Derinlik sever ama tekrar eden angarya üretir |

*Öneri: kopyalama varsayılan, elle ince ayar isteğe bağlı.* B seçeneği derinlik değil angaryadır.

### D. Rakip temsili
| Seçenek | Etkisi |
|---|---|
| Soyut pazar payı çubuğu | Basit, duygusuz |
| **İsimli rakip şirketler** | Mizahi tona yakıt, hatırlanabilir |
| Gerçek zamanlı çok oyunculu | Sunucu maliyeti + dengeleme kâbusu |

*Öneri: isimli AI rakipler.* Çok oyunculu ilk sürümde kesinlikle olmamalı.

### E. Prestij ödülü
| Seçenek | Etkisi |
|---|---|
| Kalıcı çarpan | Hızlı ama tekdüze |
| Yeni içerik kilidi | Motive edici ama içerik üretimi pahalı |
| **İkisi birden** (çarpan + yatırım katı) | Bölüm 5'teki öneri |

### F. Sosyal katman
| Seçenek | Etkisi |
|---|---|
| **Yok** | İlk sürüm için doğru |
| Arkadaş listesi + skor tablosu | Ucuz, retention'a küçük katkı |
| Holding birlikleri (lonca) | Ağır sistem, sonlu oyunla uyumsuz |

### G. Sanat yönü
| Seçenek | Etkisi |
|---|---|
| Piksel sanat | Ucuz, nostaljik, kalabalık pazar |
| **Düz vektör / illüstratif** | Sıcak-mizahi tonla en uyumlu, ölçeklenebilir |
| 3D render'dan 2D | Pahalı, ama kat kat bina için etkileyici |

---

## 10. Riskler

1. **Kapsam.** Üç otomasyon katmanı + olaylar + rakipler + 8 sektör ciddi bir yapım. Çağ sistemi bunu evrelere böler ama yine de en büyük risk budur.
2. **Çağ 0'ın uzunluğu.** Elle çalışma fazı uzarsa oyuncu ilk 5 dakikada bırakır. Test edilecek ilk şey bu.
3. **Rakip baskısının dozu.** Kural net olsa bile oyuncu "kaybediyorum" hissederse terk eder. Duyguyu ölçmek gerekir, matematiği değil.
4. **Sonlu oyunun geliri.** Kabul edilmiş bir takas; sezon yapısıyla telafi edilmeli.
5. **Süreç katmanının anlaşılırlığı.** Kural yazma sistemi mobilde kolayca fazla teknik hale gelir. Şablon kurallar ("hazır tarifler") ile başlatmak gerekir.

---

## 11. İlk prototip kapsamı (2-3 haftalık)

Tüm oyunu değil, **tek soruyu** test et: *Çağ 0'dan Çağ 1'e geçiş tatmin edici mi?*

- Tek sektör: kahve arabası → kafe
- Çağ 0, 1 ve 2 (süreç katmanı yok)
- 3 günlük ilerleme eğrisi
- Prestij yok, rakip yok, monetizasyon yok
- Yerleştirilmiş görseller, tek kat

Ölçülecek: oyuncu ilk elemanı ne zaman tutuyor, o an ne hissediyor, ertesi gün geri dönüyor mu.

---

## 12. Sıradaki kararlar

1. Yukarıdaki A-G seçeneklerinden hangilerini kesinleştiriyoruz
2. Sektör listesi ve açılma sırası
3. Ekonomi tablosu — sayısal denge (gelir eğrisi, maliyet katsayıları, offline oranları)
4. Kural şablonları listesi (süreç katmanı için)
5. Prototip için görev kırılımı
