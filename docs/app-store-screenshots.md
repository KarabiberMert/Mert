# Ekran görüntüsü metinleri

Altı ekran görüntüsü, üç dil. Her karede bir başlık ve bir alt satır var —
mağazada küçük görünürler, o yüzden başlık en fazla 32, alt satır en fazla 60 karakter.
`scripts/check_store_copy.py` bunu doğruluyor.

Sıra bir hikâye anlatıyor: elle çalışan biri → iş sensiz yürüyor → bina
yükseliyor → kural koyuyorsun → satıyorsun → sen yokken de kazanıyorsun.
Mağazada ilk iki kare çoğu kişinin göreceği tek karedir; ağırlığı onlara ver.

Zorunlu boyutlar: 6,9" ve 6,7" iPhone. Üç dilde ayrı ayrı yüklenir.

## 1. Çağ 0 — elle çalışıyorsun

**Ekranda ne olsun:** Zemin kat, kadro yok. Kasa küçük bir rakamda, altında "Şimdilik her kahveyi sen yapıyorsun." satırı ve büyük satış butonu. Tezgâha bir kez dokunup süzülen +4'ü yakala.

| Dil | Başlık (≤32) | Alt satır (≤60) |
|---|---|---|
| en-US | It starts with your two hands `29` | Every cup is a tap. That is the job, for now. `45` |
| tr | İki elinle başlıyorsun `22` | Her fincan bir dokunuş. Şimdilik iş bu. `39` |
| es-ES | Empieza con tus dos manos `25` | Cada taza es un toque. Por ahora, ese es el trabajo. `52` |

## 2. İlk eleman — iş sensiz yürüyor

**Ekranda ne olsun:** İlk elemanı tuttuktan sonra: kadro katta duruyor, kasa satırında saniyelik net görünüyor, satış butonu küçülmüş. Kutlama kartı çıkmışken de yakalanabilir.

| Dil | Başlık (≤32) | Alt satır (≤60) |
|---|---|---|
| en-US | Hire someone. Step back. `24` | The queue moves without you, even with the app shut. `52` |
| tr | Birini tut, tezgâhtan çekil `27` | Sıra sensiz ilerler, uygulama kapalıyken bile. `46` |
| es-ES | Contrata y da un paso atrás `27` | La cola avanza sin ti, con la app cerrada. `42` |

## 3. Bina yükseliyor

**Ekranda ne olsun:** İki kat açık, üst katta birkaç hücre. Bina şeridi seçili olsun ki pazar payı çubuğu ve kat listesi de görünsün. Seçili katın hardal keyline'ı belli olmalı.

| Dil | Başlık (≤32) | Alt satır (≤60) |
|---|---|---|
| en-US | One building, floor by floor `28` | Each floor is a trade. The units are its branches. `50` |
| tr | Tek bina, kat kat `17` | Her kat bir iş. Hücreler o işin şubeleri. `41` |
| es-ES | Un edificio, planta a planta `28` | Cada planta, un oficio. Los huecos, sucursales. `47` |

## 4. Yönetim katı ve kurallar

**Ekranda ne olsun:** Çatı açık, müdür tutulmuş, iki kural işaretli. Ofis şeridinde "Verim +%20" satırı ve kural anahtarları görünsün. Binada çatı bandı da çerçevede kalsın.

| Dil | Başlık (≤32) | Alt satır (≤60) |
|---|---|---|
| en-US | Write the rules. They pay. `26` | Set none and you still run at full speed. `41` |
| tr | Kuralı yaz, o kazandırsın `25` | Hiç koymazsan da tam hızla çalışırsın. `38` |
| es-ES | Pon las reglas. Te pagan. `25` | Si no pones ninguna, vas a pleno rendimiento. `45` |

## 5. Olgunlaşan işi satmak

**Ekranda ne olsun:** Zemin kat tam kadro, tam ekipman, tüm hücreler. Bina şeridinde "Bu işi sat" satırı fiyatıyla duruyor. Satıştan sonraki kutlama kartı da iyi bir kare: kalan kirayı yazıyor.

| Dil | Başlık (≤32) | Alt satır (≤60) |
|---|---|---|
| en-US | Sell it. Keep the floor. `24` | Cash, a permanent multiplier, and rent that keeps coming. `57` |
| tr | Sat, ama kat sende kalsın `25` | Nakit, kalıcı çarpan ve işlemeye devam eden kira. `49` |
| es-ES | Véndelo. La planta se queda. `28` | Dinero, multiplicador para siempre y renta que sigue. `53` |

## 6. Sen kapalıyken

**Ekranda ne olsun:** En az bir dakika uzakta kaldıktan sonra dönüş özeti. Büyük tutar, "Sen yokken" süresi ve katlama düğmesi bir arada görünsün.

| Dil | Başlık (≤32) | Alt satır (≤60) |
|---|---|---|
| en-US | It works while you are shut `27` | Come back to what the store room collected. `43` |
| tr | Sen kapalıyken de çalışır `25` | Döndüğünde deponun biriktirdiğini alırsın. `42` |
| es-ES | Funciona con la app cerrada `27` | Vuelve y recoge lo que juntó el almacén. `40` |

## Yazarken

- Başlık bir iddia, alt satır onun kanıtı. İkisi aynı şeyi söylemesin.
- Metin oyunun tonunda: sen-dili, sade fiiller, bağırmayan harfler.
- Alt satırda sayı verme. Denge değişince ekran görüntüsü yalan söyler.
- Kare gerçek ekranı göstersin. Oyunda olmayan bir şeyi çizip koyma.
