# Fetih — Görsel ve Animasyon Yön Belgesi (v0.1)

> Amaç: Kullanıcının "grafik ve animasyon aşırı zayıf" geri bildirimine somut bir yön vermek.
> Bu belge karar vermez; seçenekleri ve önerimi yazar. **Sanat yönü kararı kullanıcınındır** (bkz. bölüm 8).
> Kapsam: savaş alanı, birlikler, efektler, arayüz, geçişler. Ses bu belgenin dışında.
> Kural: Bütün görsel işler sadece görüntüdür. `BattleSimulation` sonucu ve determinizm değişmez.

**Kaynaklar:** `CLAUDE.md`, `oyun_tasarim_dokumani.md` (bölüm 2), `yayin/ekran_goruntuleri/`, `kaynak_assetler/LISANSLAR.md`,
`Fetih/scripts/battle/battle_fx.gd`, `squad_view.gd`, `unit_sprites.gd`, `ground_art.gd`, `battle_camera.gd`,
`Fetih/scripts/ui/ui_kit.gd`, `Fetih/tools/import_sprites.gd`, `Fetih/data/kingdoms/*.tres`.

**Varsayım:** `yayin/ekran_goruntuleri/` Aşama 12'den önce alınmış (zemin düz karo, birlikler koddan üretilmiş).
Bugünkü oyunda HD çimen zemin ve CC0 sprite'lar var. Aşağıdaki tespitlerin bir kısmı koddan çıkarıldı; Faz 1'in
ilk işi güncel ekran görüntüsü almaktır.

---

## 1. Mevcut durum

### 1.1 Görsel dilin bugünkü hali

| Katman | Bugün | Kaynak |
|---|---|---|
| Zemin | 128x64 HD çimen karosu, dünyada 64x32'ye küçültülüp doğrusal süzme ile çizilir; ot/kaya süsleri; krallığa göre ton (`BIOMES`) | CC0 rubberduck, `ground_art.gd` |
| Ağaçlar | 256 px HD bitki dokuları, 0.34 ölçekle, doğrusal süzme | CC0 rubberduck plants |
| Birlikler (29) | 32x32 karede ~16 px figür (Puny), 16x16 / 16x28 figür (DungeonTileset II) | CC0 Shade, CC0 0x72 |
| Birlikler (11) | 24x24 koddan üretilmiş figür, krallık rengiyle boyalı (atlılar, toplar, golemler, kentaurlar) | `UnitSprites.generate` |
| Boss'lar | Paket figürü 2x veya 3x piksel büyütme + koddan taç | `import_sprites.gd` `scale` |
| Takım ayrımı | Ayakta 3 satırlık takım renkli oval (alpha 0.7) + 7x5 px sancak | `SquadView` |
| Efektler | 1-2 px kare parçacıklar, 1 px ok çizgisi, elips halkalar, ceset solması, beyaz flaş 120 ms | `BattleFx` |
| Arayüz | Düz renkli kutular (`StyleBoxFlat`), Godot varsayılan yazı tipi, ikon yok, hiç Tween yok | `UiKit` |
| Ekran geçişi | Anında değişim (animasyon yok) | `Screens` |

### 1.2 Tutarsızlıklar ve zayıflıklar (önem sırasıyla)

1. **Piksel yoğunluğu karışık (en büyük sorun).** Aynı karede dört farklı piksel ölçeği var:
   - Birlik pikseli = 3 ekran pikseli (640x360 x3).
   - Zemin dokusu 128x64'ten 64x32'ye iniyor: zemin pikseli = 1.5 ekran pikseli ve bulanık (doğrusal).
   - Boss'lar 2x/3x büyütülmüş: boss pikseli = 6-9 ekran pikseli ("mixel": aynı sahnede farklı boyutta piksel).
   - Kamera yakınlığı 0.5'te birlik pikseli 1.5 ekran pikseline düşer; Nearest süzmede bazı pikseller 1, bazıları 2 px
     olur (titreme, düzensiz kenar).
   Göz bunu "ucuz" ve "kolaj" olarak algılar. Detay eksikliğinden daha çok bu tutarsızlık zayıf gösteriyor.
2. **Üç ayrı çizim dili.** Puny (chibi, kalın siyah kontur, büyük kafa), DungeonTileset II (daha uzun oran, kendi paleti,
   kontur yok veya ince), koddan üretilen (düz renk, tek ton). Ortak palet yok; GDD bölüm 2'deki "tek sınırlı palet"
   kararı uygulanmamış.
3. **Takım okunabilirliği zayıf.** Takım rengi sadece ayak altındaki 3 px yüksekliğindeki ovalde ve küçük sancakta.
   Kalabalıkta ovaller kapanıyor. Ayrıca renk çakışması var:
   - Oyuncu mavisi `#3D6FD1` ile İnsanlar `#7FA7E0` aynı ton ailesinde.
   - Düşman kırmızısı `#C8443A` ile İblisler `#E0453A` neredeyse aynı.
4. **Krallık renk kimliği belirsiz.** Orklar `#D77A4F`, Cüceler `#C08A4A`, Kentaurlar `#D9A55A`, Çamurlar `#8A7A40`
   aynı turuncu-kahve bandında. Harita ve kartlarda krallıklar renkten ayırt edilemiyor.
5. **Animasyon "damga" gibi.** Formasyon kusursuz 5 sütunlu ızgara; askerler aynı kareyi paylaşıyor (faz kaydırması var
   ama durma 2 kare, 2 fps). Saldırıda hazırlık (anticipation) yok, tek 200 ms kare. Vuruşta duraklama (hit-stop) yok.
   Hasar ve kayıp sayısı görünmüyor; oyuncu "ne oldu" sorusunun cevabını göremiyor.
6. **Cesetler canlı birlik gibi okunuyor.** Koddan üretilen atlıların cesedi koyu, büyük bloklar halinde yerde kalıyor
   (ekran görüntüsü 02). Canlı bölükle karışıyor.
7. **Arayüz prototip seviyesinde.** Varsayılan yazı tipi doğrusal kenarlı ve piksel sanatla uyumsuz. Panel çerçevesi,
   ikon, kart çerçevesi yok. İstatistikler düz metin ("HP 9.0 Damage 4.3"). Koşu haritası krallıkları iki harfle
   gösteriyor ("Mu", "Sl"). Kart seçimi, zafer, can kaybı anları animasyonsuz.
8. **HUD ile dünya çakışıyor.** Ekran görüntülerinde sancak sayıları hız düğmelerinin üstüne çiziliyor.
   HUD bir `CanvasLayer` üstünde değilse ya da dünya etiketleri HUD'dan sonra çiziliyorsa düzeltilmeli (doğrulanmalı).
9. **Mermi ve efektler küçük ve tek renk.** 1 px ok, 3x3 gülle. Alan hasarı sadece ince halka; iz (decal) yok.
   Büyü/ateş/çamur farkı sadece renkte.
10. **Savaş başı ve sonu yok.** Savaş aniden başlıyor, aniden bitiyor. "Fetih" duygusunu taşıyan an (sancakların
    karşılaşması, zafer) boş.

### 1.3 Güçlü taraflar (korunmalı)

- Kitle ordusu fikri: ekranda yüzlerce asker. Bu, 9 Kings'ten ayrışan en güçlü görsel vaat.
- Veri odaklı sprite hattı: `assets/sprites/units/<id>.png` + 4 satırlık sayfa. Stil değişse bile hat aynı kalabilir.
- Efektlerin simülasyondan ayrı olması (`BattleFx` sadece görüntü). Juice eklemek güvenli.
- Ekran sarsıntısı ayarı zaten var (`Settings.screen_shake`).

---

## 2. Referans analizi

Her oyundan Fetih'e taşınabilecek 1-2 somut ders. Gözlemler genel tasarım düzeyindedir; birebir kopya önerilmez.

### 9 Kings
- **Ders 1 — Krallık = tek baskın renk.** Her kral/deste tek bir renk ailesine sahip; kart, birlik ve arayüz o rengi
  taşır. Oyuncu bir bakışta "bu kimin kartı" der. Fetih'te: krallık ana rengi kart çerçevesinde, harita düğümünde,
  sancak amblemi ve birlik zırh vurgusunda tutarlı kullanılmalı (bölüm 4.3).
- **Ders 2 — Büyüme görünür olmalı.** Bir şey güçlendiğinde ekranda büyür veya süslenir. Fetih'te: bölük seviyesi şu an
  2 px altın noktalarla gösteriliyor. Seviye arttıkça sancak büyümeli, Sv 3'te sancak saçağı, Sv 5'te altın sancak
  ucu ve asker kontur parıltısı.

### Backpack Battles
- **Ders 1 — Her tetiklenme kaynağında "nabız" atar.** Bir eşya etkisini kullandığında kısa ölçek darbesi (scale punch)
  yapar ve sayı fırlatır. Fetih'te: bölük vurduğunda sancak 1.0 -> 1.15 -> 1.0 (120 ms); yetenek (yanma, yavaşlatma,
  onarım) tetiklenince sancağın yanında küçük ikon belirir.
- **Ders 2 — Sürükle-bırak dokunsal olmalı.** Tutulan nesne büyür, gölge düşer, bırakınca esner (squash). Fetih'in
  hazırlık ekranında bölük sürükleme bu hissi almalı (bölüm 5.5).

### Super Auto Pets
- **Ders 1 — Basit çizim + net hareket > detaylı çizim.** Figürler son derece sade ama saldırı "atıl, çarp, geri dön"
  hareketiyle anında okunuyor. Fetih'te: saldıran bölüğün ön sırası hedefe doğru 2 px atılır (lunge), temas karesinde
  durur, geri döner. Kare çizimi az olsa bile hareket okunur.
- **Ders 2 — Sayı değişimi kutlanır.** İstatistik değişince sayı büyür, renk değiştirir. Fetih'te: kart ekranında
  "Asker 20 -> 28" sayacı akarak artmalı; sancak sayısı asker kaybında kırmızı yanıp sönmeli.

### Into the Breach
- **Ders 1 — Okunabilirlik estetikten önce gelir.** Sınırlı palet, tek piksel yoğunluğu, her birimin güçlü silueti,
  takımların net ayrımı. Fetih'te: tek palet, tek piksel ölçeği, rol başına siluet kuralı (bölüm 4.2).
- **Ders 2 — Niyeti göster.** Oyuncu ne olacağını önceden görür. Fetih'te: hazırlık ekranında bölükler ile düşman
  önizlemesi arasında karşılık okları (yeşil = avantaj, kırmızı = dezavantaj) ve savaş başında hedef çizgileri
  (0.8 s görünür, sonra solar).

### Kingdom Two Crowns
- **Ders 1 — Atmosfer ışık ve renkle gelir, detayla değil.** Düşük çözünürlüklü piksel sanat, renk derecelendirme,
  gün ışığı tonu ve vinyetle zengin görünür. Fetih'te: biyom başına `CanvasModulate` tonu + hafif vinyet shader'ı
  + boss savaşında karartılmış, doygunluğu düşük renk; HD detaya gerek kalmadan sahne zenginleşir.
- **Ders 2 — Arayüz azdır, dünya konuşur.** Bilgi mümkün olduğunca dünyanın içinde (sancak, renk, parıltı) verilir.
  Fetih'te: savaş HUD'u minimum (savaş no, hız, duraklat); gerisi sancak ve efektlerle.

---

## 3. Hedef sanat yönü: üç seçenek

Ortak kısıt: 640x360 düzen, 3x varsayılan ölçek, izometrik 64x32 karo, ekranda 100-300 asker, sprite sayfası 4 satır,
sadece sağa/sola bakan figür.

### Seçenek A — "Tutarlı piksel" (Into the Breach / Kingdom Two Crowns çizgisi)
Her şey aynı piksel ölçeğinde: zemin, ağaç, birlik, boss, efekt, arayüz. Tek palet.

| Başlık | Öneri |
|---|---|
| Palet | Resurrect 64 (Kerrie Lake, Lospec) veya Endesga 32. 32-64 renk; her krallık paletten 3-4 renk alır |
| Sprite boyutu | Asker: 32x32 kare, 14-18 px figür (Puny oranı). Atlı/kentaur: 32x32 kare, 24x20 figür. Boss: 64x64 kare, 36-48 px figür, **doğal çizim** (piksel büyütme yok) |
| Zemin | 64x32 piksel karo, 1x (mevcut HD karolar araçla küçültülüp palete indirgenir veya koddan üretilir) |
| Ton | Hafif karanlık fantastik, sıcak gün ışığı; kalın 1 px koyu kontur (`#1c1612`) |
| Maliyet / emek | Düşük-orta. 29 birlik paketten var; sadece palete indirgenir. 11 birlik + 10 boss yeniden çizilir (16 px ölçekte deneyimli piksel sanatçı için birim başına ~2-4 saat varsayımı) |
| Artı | Kitle ordusu için ideal (küçük figür kalabalıkta okunur). Mevcut hat ve CC0 paketlerle uyumlu. Performans sorunu yok. Tutarlılık en hızlı bu yolla gelir |
| Eksi | HD zemin geri gider. "Retro" algısı; cilasız kalırsa ucuz görünür. Detay sınırı düşük, boss'larda etki ışık/efektle verilmeli |

### Seçenek B — "Hibrit: HD dünya + piksel birlik, ışıkla birleştirilmiş"
HD zemin ve ağaç kalır; piksel birlikler tek palete çekilir; aradaki uyumsuzluk renk derecelendirme ve shader'la kapatılır.

| Başlık | Öneri |
|---|---|
| Palet | Birlikler için Resurrect 64; zemin için paletle uyumlu ton haritası (shader'da renk eşleme / posterize) |
| Sprite boyutu | Asker 32x32 kare (16-18 px figür) ama oyun içinde 2x çizim (birlik pikseli = 6 ekran px) **veya** 24 px figür 1x. Boss 64x64 doğal |
| Zemin | Mevcut 128x64 HD, düşük kontrast ve hafif doygunluk düşüşü; ağaçlar ön plan bulanık değil, kontur shader'ı |
| Ton | Sıcak, "masa üstü minyatür" hissi; birlikler zemine göre daha doygun |
| Maliyet / emek | Orta. Shader + renk ayarı denemeleri zaman alır; sonucun tutarlı olacağı garanti değil |
| Artı | Bugünkü HD zemin yatırımı korunur. Mağaza görüntüsünde zemin zengin görünür |
| Eksi | Piksel yoğunluğu farkı tamamen kaybolmaz; dikkatli göz yine "kolaj" görür. İki ayrı süzme (Linear + Nearest) kalıcı karmaşıklık |

### Seçenek C — "HD düz renk çizim" (Super Auto Pets / Backpack Battles / 9 Kings çizgisi)
Elle çizilmiş, kalın konturlu, düz gölgeli 2D figürler; doğrusal süzme; parça (cutout) animasyon.

| Başlık | Öneri |
|---|---|
| Palet | Serbest ama sınırlı: krallık başına 4 renk + ortak nötrler; yüksek doygunluk |
| Sprite boyutu | Asker 48-64 px (ekran pikseli, 1080p'de); boss 160-256 px. Parça animasyon: `Skeleton2D` veya Tween ile kafa/gövde/silah ayrı parçalar |
| Zemin | HD, mevcut rubberduck ile uyumlu |
| Ton | Parlak, sevimli-kahramanca, "mobil-premium" |
| Maliyet / emek | Yüksek. 40 birlik + 10 boss çizilmeli; profesyonel sanatçı gerekir (birim başına ~6-12 saat varsayımı). Sprite hattı ve `UnitSprites` büyük değişiklik ister |
| Artı | Modern Steam görünümü; 1080p'de en net. Kapsül görselleri ve fragman için en çekici |
| Eksi | Kalabalıkta 48-64 px figürler üst üste biner, okunabilirlik düşer (300 asker hedefiyle çelişir). CC0 paketler kullanılamaz. Bugüne kadarki sprite işi çöpe gider. En uzun yol |

### Öneri: Seçenek A ("Tutarlı piksel")

Gerekçe:
1. Kullanıcının "zayıf" algısının ana kaynağı detay eksikliği değil, **tutarsızlık + animasyonsuzluk**. A ikisini de en ucuz yoldan çözer.
2. Fetih'in ayırt edici vaadi kitle ordusu. Küçük, tutarlı piksel figürler yüzlerce askerde en iyi okunan çözüm.
3. Mevcut CC0 hattı (Puny, DungeonTileset II) ve `import_sprites.gd` korunur; palete indirgeme bir araç adımıdır.
4. Atmosfer Kingdom Two Crowns dersiyle (ışık, ton, vinyet) eklenir; HD zemine gerek kalmaz.

Önerinin riski: HD zemin geri alınır (Aşama 12 işi). Kullanıcı HD zemini seviyorsa **B** ikinci seçenek; C ancak
bütçeli bir sanatçı varsa mantıklı. **Karar kullanıcıda.** Bölüm 5 ve 7'deki Faz 1 işleri seçimden bağımsızdır,
karar beklenmeden başlanabilir.

---

## 4. Okunabilirlik kuralları

### 4.1 Takım rengi
Takım rengi krallıktan **bağımsız** olmalı (iki ordu aynı krallıktan olabilir).

| Öğe | Oyuncu | Rakip |
|---|---|---|
| Takım rengi | Mavi `#3D7BE0` | Kırmızı `#D8433A` |
| Zemin diski | 9x3 px elips (atlı 13x4, boss 24x8), dolgu alpha 0.75 + 1 px koyu kenar (`darkened(0.4)`) | aynı, kırmızı |
| Sancak | Bez 9x7 px takım renginde, ortasında 5x5 krallık amblemi | aynı |
| Seçmeli kontur | Ayarlarda "takım konturu" açıkken askerlere 1 px takım renkli dış kontur (shader) | aynı |
| HUD | Sol alt = oyuncu, sağ üst = rakip; panel kenarları takım renginde | aynı |

Kurallar:
- Hiçbir krallık ana rengi takım renginin ±15° ton aralığına girmez (mavi 205-230°, kırmızı 350-10°). Bu yüzden
  İnsanlar ve İblisler renk değiştirmeli (4.3).
- Zemin diski askerin altında, cesetlerin üstünde çizilir (ceset diski yok).
- Renk körlüğü: takım farkı renk + şekil ile verilir. Oyuncu sancağı dikdörtgen, rakip sancağı çatallı (kırlangıç kuyruğu) uçlu.

### 4.2 Siluet (rol başına)
Test: figürü 1x ölçekte tamamen siyaha boya. Rol yine anlaşılmalı.

| Rol | Siluet kuralı | Boyut |
|---|---|---|
| Savaşçı | Kalkık kılıç/balta, orta gövde | 14-16 px boy |
| Mızrakçı | Başın en az 4 px üstüne çıkan dikey mızrak çizgisi | 14-16 px + mızrak |
| Tank | Önde geniş kalkan bloğu, gövdeden 2 px geniş | 15-17 px, geniş |
| Okçu | İnce gövde, önde yay eğrisi | 13-15 px |
| Büyücü | Sivri şapka veya asa, asa ucunda 1 px parlak renk (krallık vurgu rengi) | 14-16 px |
| Süvari | Yatay, 22-24 px genişlik; binici başı gövdenin üstünde | 20-22 px boy |
| Kuşatma | Alçak ve geniş makine, namlu/kol açık seçilir | 12-14 px boy, 22-26 px genişlik |
| Boss | Asker boyunun 2.5-3 katı, doğal çizim, taç/özel siluet öğesi | 36-48 px |

Ek kurallar:
- Ceset: ölüm satırının son karesi %55 karartma (mevcut) + **doygunluk %60 düşük** + yarı saydam (alpha 0.8),
  zemin diski yok. Canlı birlikle karışmaz.
- Formasyon "damga" görünmesin: her askere sabit ±1 px rastgele kayma (görsel `_visual_rng`, slot başına sabit) ve
  durma animasyonunda farklı faz.

### 4.3 Krallık renk kimliği (öneri; `KingdomData.color` + yeni `accent_color`)
Ton çemberinde aralıklı yuvalar; takım tonları (mavi, kırmızı) boş bırakıldı.

| Krallık | Ana renk (`color`) | Vurgu (`accent_color`) | Ton | Bugünkü renk | Not |
|---|---|---|---|---|---|
| İnsanlar | Kraliyet moru `#7A5CC8` | Çelik `#C8CED8` | 265° | `#7FA7E0` (mavi) | Oyuncu mavisiyle çakışmayı kaldırır |
| Golemler | Taş `#A89B8A` | Ametist rün `#C060E0` | nötr + 290° | `#A89B8A` | Ana renk aynı, rün vurgusu eklenir |
| Elfler | Yaprak yeşili `#6FBF4A` | Gümüş `#E0ECD0` | 105° | `#9FDC6A` | Biraz koyulaşır |
| Orklar | Zeytin `#7E9A3A` | Kara demir `#3A3A40` | 80° | `#D77A4F` | Turuncu banttan çıkar |
| Çamurlar | Balçık sarısı `#A08A3A` | Bataklık yeşili `#4A5A30` | 50° | `#8A7A40` | Daha sarı, daha açık |
| Cüceler | Pirinç `#D9A441` | İs siyahı `#2B2B30` | 40° | `#C08A4A` | Altın-pirinç, koyu vurgu |
| Kentaurlar | Kestane `#A0582E` | Kum `#E8C888` | 22° | `#D9A55A` | Daha koyu ve kırmızımsı kahve |
| İblisler | Magma turuncusu `#FF7A2A` | Kül moru `#3A1E40` | 22° (çok doygun) | `#E0453A` | Rakip kırmızısından ayrılır; Kentaur ile değer/doygunlukla ayrışır |
| Slime'lar | Nane `#4FD8A8` | Koyu jöle `#1E6A5A` | 160° | `#50E0B0` | Aynı |
| Ölüler | Hayalet camgöbeği `#8FD8D0` | Kemik `#E8E0C8` | 175° | `#9AB0B8` | Daha belirgin |

Not: Kentaur ve İblis tonu yakın; ayrım doygunluk ve değer ile (İblis çok parlak turuncu + koyu mor, Kentaur koyu
kahve + kum). Kullanıcı isterse İblisler mor-magentaya (`#B03A8A`) kaydırılabilir (karar 8.4).

Krallık rengi nerede kullanılır: kart çerçeve şeridi, harita düğümü kalkanı, sancak amblemi, krallık seçim listesi,
birlik zırh/elbise vurgusu (palete indirgemede), biyom tonu.

### 4.4 Arayüz hiyerarşisi

| Seviye | Ne | Boyut (640x360 düzende) | Renk |
|---|---|---|---|
| 1 Birincil | Canlar, savaş no, "Savaşı başlat", kart başlığı, zafer/yenilgi | 16 px piksel yazı | `COLOR_TEXT` / `COLOR_GOLD` |
| 2 İkincil | Bölük adı, asker sayısı, istatistik değeri | 8-11 px | `COLOR_TEXT` |
| 3 Üçüncül | Açıklama, ipucu, "boş" | 8 px | `COLOR_MUTED` |

Kurallar:
- Tek piksel yazı tipi, iki boyut (8 ve 16 px, tam katlar). Türkçe karakterler (ç ğ ı İ ö ş ü) zorunlu.
- Sayısal istatistikler ikonla: kalp (can), kılıç (hasar), saat (saldırı hızı), yay (menzil), çizme (hız), kalkan (zırh).
  8x8 px ikon + değer. Metin etiketi sadece ipucunda.
- Kart türü çerçeveden okunur: Birlik = krallık rengi şerit + birlik ikonu; Yükseltme = altın çerçeve + yukarı ok;
  Ferman = mühürlü parşömen dokusu + krallık mührü.
- Bir ekranda en fazla bir "parlayan" eylem (birincil düğme). Diğer düğmeler sönük.
- Savaş HUD'u bir `CanvasLayer` üzerinde; dünya etiketleri asla HUD'un üstüne çizilmez.
- 9-dilim (9-slice) panel çerçeveleri (`StyleBoxTexture`), düz renk kutu yerine.

---

## 5. Animasyon rehberi

Bütün süreler x1 gösterim hızı içindir; savaş hızı (x2, x4) ve `PLAYBACK` çarpanı savaş içi süreleri ölçekler.
Arayüz süreleri savaş hızından bağımsızdır.

### 5.1 Birlik animasyonları (sprite sayfası)

| Animasyon | Kare | Süre / kare | Toplam | Not |
|---|---|---|---|---|
| Durma (asker) | 2-4 | 200-250 ms | 0.5-1 s döngü | Her asker farklı fazda (mevcut). 2 kare yerine 4 tercih edilir |
| Yürüme (asker) | 4 | 110-130 ms | ~0.5 s döngü | Kare hızı `move_speed` ile ölçeklenir: fps = 8 x move_speed, 6-12 arası (ayak kayması olmasın) |
| Yürüme (süvari/kentaur) | 4 | 80-90 ms | ~0.35 s | Dörtnala; gövde 1 px iner-kalkar |
| Yakın saldırı | 4 | 90 / 70 / 60 / 100 ms | 320 ms | Kare 1-2 hazırlık (geri çekiliş), kare 3 temas (hedef flaşı burada), kare 4 toparlanma |
| Uzak saldırı (okçu) | 4 | 120 / 80 / 60 / 100 ms | 360 ms | Ok kare 3'te çıkar |
| Büyü | 4 | 100 / 100 / 60 / 120 ms | 380 ms | Kare 2'de asa ucu parlar (1 px vurgu rengi), mermi kare 3'te |
| Kuşatma ateşi | 4 | 80 / 60 / 60 / 200 ms | 400 ms | Kare 2 namlu alevi, 2 px geri tepme |
| Ölüm (asker) | 4-5 | 70 ms | 280-350 ms | Son kare ceset. Mevcut `CORPSE_FALL` 0.36 s uygun |
| Ceset | — | — | 2.0 s kalır + 0.6 s solar | Bugün 1.4 + 0.8; biraz uzun kalsın, savaş izi okunsun. `MAX_CORPSES` 160 korunur |

Boss (64x64 kare, isteğe bağlı 6 satır: durma, yürüme, saldırı, ölüm, hasar, yetenek):

| Animasyon | Kare | Süre / kare | Toplam |
|---|---|---|---|
| Durma | 4 | 180 ms | 720 ms |
| Yürüme | 6 | 110 ms | 660 ms |
| Saldırı | 6 | Telegraf 3 kare toplam 360 ms, temas 1 kare 100 ms (tutulur), toparlanma 2 kare 200 ms | 660 ms |
| Hasar | 2 | 60 ms | 120 ms (her vuruşta değil; en fazla 0.6 s'de bir) |
| Yetenek | 6-8 | 90 ms | ~0.6 s |
| Ölüm | 8 | 90 ms | 720 ms + patlama efekti |

Saldırı animasyonu, saldırı aralığından uzunsa (hızlı birlikler, x4 hız) oransal kısaltılır; temas karesi hep gösterilir.

### 5.2 Vuruş, ölüm ve "juice" (kod tarafı, sprite gerektirmez)

| Olay | Efekt | Değerler |
|---|---|---|
| Saldırı atılımı (lunge) | Saldıran bölüğün ön sırası hedef yönüne kayar, geri döner | 2 px, 60 ms ileri + 100 ms geri (ease-out) |
| Vuruş flaşı | Hedef askerler beyaz siluet | 70 ms tam beyaz + 40 ms %50 (bugün 120 ms %75) |
| Geri itilme | Vurulan ön sıra geriye kayar | 1 px, 80 ms |
| Kıvılcım | Temas noktasında 3-5 parçacık + 1 kare "yıldız" sprite'ı (5x5) | 180 ms |
| Kesik izi (savaşçı/boss) | Yay şeklinde beyaz-sarı iz, 3 kare | 3 x 40 ms |
| Kayıp sayısı | Sancak üstünde "-N" (bölük başına, 250 ms pencerede toplanır) | 8 px yazı, 500 ms'de 10 px yükselir, son 150 ms solar; aynı anda en fazla 16 |
| Sancak sayacı darbesi | Asker kaybında sayı 1.3x olur, kırmızı yanıp söner | 150 ms |
| Hücum (süvari ilk vuruş) | Toz izi + çarpışma halkası + sarı "-N!" (1.5x boy) | Halka 30 px, 300 ms |
| Ölüm | Ceset + 4 damla (mevcut) + toz pufu (3 kare, 8x8) | 210 ms |
| Bölük yok oldu | Toz halkası (mevcut) + sancak devrilir (4 kare, 80 ms) ve yerde 2 s kalır | 320 ms |

Hit-stop (vuruşta kısa duraklama): sadece gösterim saatini durdurur (`BattleController` `sim_delta`'yı sıfırlar),
simülasyon adımları ve sonuç aynı kalır. Kitle savaşında sürekli donmasın diye sadece:

| Olay | Hit-stop | Ek |
|---|---|---|
| Boss vuruşu | 60 ms | — |
| Hücum çarpışması | 40 ms | — |
| Gülle inişi | 30 ms | — |
| Boss ölümü | 150 ms | Ardından 500 ms 0.4x yavaş çekim |
| Savaşın son bölüğü düştü | 0 ms | 600 ms 0.5x yavaş çekim, sonra zafer/yenilgi |

İki hit-stop arası en az 400 ms. Ayarlarda "vuruş duraklaması" kapatılabilir.

### 5.3 Yetenek efektleri (mekanik başına görsel imza)

| Mekanik (`UnitData` alanı) | Tetiklenme anı | Süren durum | Renk |
|---|---|---|---|
| Yanma (`burn_ratio`) | Mermi/vuruşta turuncu patlama 8 parçacık | Askerlerin başında titreyen alev (mevcut kıvılcım) + yükselen kor parçacıkları, saniyede 2 | `#FF8A30` / `#FFE080` |
| Yavaşlatma (`slow_amount`) | Çamur sıçraması, yerde 2 s kalan çamur birikintisi (decal) | Ayakta çamur (mevcut) + yürüme fps'i yavaşlama oranında düşer | `#6A5A2A` |
| Onarım (`regen_ratio`) | — | Saniyede bir, bölüğün üstünden yükselen 2-3 yeşil "+" (3x3) | `#8FD47F` |
| Diriliş (`revive_ratio`) | Cesetlerden yükselen mor-camgöbeği ışık, ölüm animasyonu ters oynar (askerler kalkar), halka | 800 ms | Krallık vurgu rengi |
| Bölünme (`splits`) | Esneme-sıkışma (1.3x0.7 -> 1.0) ile iki bölüğün doğuşu, jöle damlaları (mevcut) | 250 ms | Birlik rengi |
| Alan hasarı (`splash_radius`) | Halka (mevcut) + yerde 2 s kalan yanık izi (decal, alpha 0.4) | — | Mermi rengi |
| Zırh delme (`ignores_armor`) | Vuruşta kalkan kırılma kıvılcımı (gri-mavi 3 parçacık) | — | `#C8CED8` |

Mermi görselleri:
- Ok: 5 px gövde + 1 px uç, yaylım ateşinde 3-4 ok (mevcut). Hedefte 2 px "saplanma" izi 300 ms.
- Büyü mermisi: 3x3 çekirdek + 3 karelik iz (mevcut) + 4 karelik dönen parıltı sprite'ı (5x5).
- Gülle: 4x4 + 1 px parlama; inişte 3 karelik patlama sprite'ı (16x16) + krater izi (decal 2 s).

### 5.4 Savaş başı ve sonu

| An | Süre | İçerik |
|---|---|---|
| Savaş girişi | 1.2 s (tıklayınca atlanır) | 0-300 ms iki krallığın sancak paneli yanlardan kayar; 300-700 ms "VS" büyür (1.4x -> 1.0, ease-out back); boru sesi (`horn`); 700-1200 ms paneller çekilir, sancaklar bölüklerin üstünde belirir (80 ms arayla) |
| Hedef çizgileri | 0.8 s | Her bölükten ilk hedefine kesikli çizgi (takım renginde, alpha 0.5), sonra solar |
| Boss girişi | +0.8 s | Kamera boss'a yakınlaşır (zoom 2, 400 ms), boss adı ve unvanı 16 px altın yazıyla, `boss_roar`, 3 px sarsıntı |
| Zafer | 1.0 s + kart ekranı | Son vuruş yavaş çekim (5.2), "ZAFER" başlığı yukarıdan düşer (350 ms ease-out back), kalan bölüklerin sancakları 2 kez zıplar |
| Yenilgi | 1.0 s | Ekran %30 karartma + doygunluk düşer (400 ms), "YENİLGİ" ağır iner (500 ms ease-in), kalp kırılma animasyonu |

### 5.5 Arayüz geçişleri

| Geçiş | Süre | Eğri | Not |
|---|---|---|---|
| Ekran değişimi (`Screens`) | 180 ms kararma + 220 ms açılma | ease-in-out quad | Tek siyah `ColorRect` + Tween |
| Overlay açılış | Karartma 0 -> %60, 150 ms; panel ölçek 0.96 -> 1.0 + saydamlık, 180 ms | ease-out back (taşma 1.05) | Kapanış yarı sürede |
| Kart dağıtımı | 3 kart, 90 ms arayla, her biri 220 ms: y +16 -> 0 px, alpha 0 -> 1 | ease-out cubic | İsteğe bağlı kart çevirme: scale.x 0 -> 1, 160 ms |
| Kart üstüne gelme | 80 ms: 3 px yukarı, kenarlık parlar | ease-out | Çıkışta 120 ms geri |
| Kart seçimi | Seçilen: 120 ms 1.08x + beyaz flaş; sonra 280 ms solar/ordu kutusuna uçar. Diğerleri: 150 ms solar + 6 px aşağı | ease-in | — |
| Düğme basma | 60 ms: 1 px aşağı, renk koyulaşır | linear | — |
| Sayı sayacı (Şan, güç, asker) | 500-700 ms | ease-out | Her 3 artışta bir tık sesi |
| Can kaybı | Kalp 2 kez yanıp söner (120 ms), sonra kırılır (300 ms); ekran kenarında kırmızı vinyet 400 ms | — | — |
| Harita ilerleme | İşaretçi düğümden düğüme 400 ms; mevcut düğüm nabız: ölçek 1.0 -> 1.08, 900 ms döngü | ease-in-out sine | Boss düğümü daha büyük + taç |
| Sürükle (hazırlık) | Tutulan bölük 1.06x + 2 px gölge, 80 ms; bırakınca esneme 1.1x0.9 -> 1.0, 120 ms | ease-out back | Geçersiz bırakma: 2 px sağ-sol titreme, 150 ms |
| Tooltip | 100 ms gecikme + 100 ms belirme | linear | — |

### 5.6 Ekran sarsıntısı yoğunlukları

Birim: dünya pikseli (640x360 düzen pikseli; 3x pencerede 3 ekran pikseli). Ofset tam sayıya yuvarlanır (piksel
keskinliği bozulmasın). Bugünkü `MAX_SHAKE` 8 ve doğrusal sönüm korunur; süre = güç / sönüm hızı.

| Olay | Güç (px) | Süre (ms) | Not |
|---|---|---|---|
| Top ateşi | 1 | 80 | Sadece kadrajdaysa |
| Gülle inişi | 2 | 150 | Bugün 1.5 |
| Süvari hücum çarpışması | 2 | 120 | Yeni |
| Bölük yok oldu | 1 | 100 | Yeni; sadece kadrajdaysa |
| Boss vuruşu | 3 | 200 | Bugün 2.5 |
| Boss girişi | 3 | 300 | Yeni |
| Boss ölümü | 6 | 450 | Bugün 7 |
| Diriliş, bölünme, büyü | 0 | — | Sarsıntı yok; efekt yeterli |

Aynı anda birden fazla sarsıntı toplanmaz, en büyüğü alınır (mevcut `maxf`). `Settings.screen_shake` kapalıysa hiçbiri.
Erişilebilirlik için ayrıca "flaş efektleri" ayarı: kapalıyken beyaz flaş %40 saydamlıkla, ekran flaşı hiç.

### 5.7 Kamera ve piksel kuralları
- Yakınlık seviyeleri, 3x pencerede birlik pikseli tam sayı ekran pikseline denk gelecek şekilde: `zoom x pencere_ölçeği`
  tam sayı olmalı. 3x için izinli: 0.667, 1.0, 1.333, 2.0 (bugün 0.5 var: 1.5 px, düzensiz). 2x pencere için: 0.5, 1.0, 1.5, 2.0.
- Yakınlık geçişi sırasında ara değerler kabul (hareket hâlinde göz fark etmez); durduğunda izinli seviyeye oturur.
- Asker çizim konumları ekran pikseline yuvarlanır (bugün formasyon ofsetleri yuvarlanıyor, bölük merkezi değil).
  Godot 4.7'de `rendering/2d/snap/snap_2d_transforms_to_pixel` ve `snap_2d_vertices_to_pixel` seçenekleri denenmeli
  (context7 ile doğrulanmalı).

---

## 6. Asset ihtiyaç listesi (öncelik sırasıyla)

Lisans notu: Aşağıdaki paket adları ve lisansları hatırlanan bilgiye dayanır. **İndirmeden önce paketin sayfasında
lisans doğrulanmalı** ve `kaynak_assetler/LISANSLAR.md`'ye eklenmeli. İnternetten indirme kullanıcı onayıyla yapılır.

| # | Asset | Öncelik | Kaynak yolu | Not |
|---|---|---|---|---|
| 1 | Piksel yazı tipi (TR karakterli, 8 ve 16 px) | P0 | **CC0 paket:** Kenney Fonts (Kenney, CC0) veya Pixel Operator (Jayvee Enaguas, CC0). Türkçe glif (ğ ş ı İ) desteği doğrulanmalı | Desteklemiyorsa eksik glifler elle eklenebilir |
| 2 | Ortak palet (32-64 renk) | P0 | **Renk listesi:** Resurrect 64 (Kerrie Lake) veya Endesga 32 (Lospec). Renk listesi; telif riski düşük varsayımı | `.hex` dosyası `Fetih/assets/palette/` |
| 3 | Palete indirgeme aracı (mevcut sprite'lar + zemin) | P0 | **Koddan üretilebilir:** `import_sprites.gd`'ye en yakın palet rengi adımı | Seçenek A ve B için |
| 4 | Takım zemin diski, sancak (dikdörtgen/çatallı), 10 krallık amblemi 5x5 ve 12x12 | P0 | **Koddan üretilebilir** (basit şekiller) veya 12x12 amblemler **çizilmeli** | Amblem fikirleri: İnsan taç, Elf yaprak, Ork diş, Golem rün, Kentaur nal, İblis boynuz, Cüce örs, Çamur damla, Ölü kafatası, Slime damla-göz |
| 5 | İstatistik ve rol ikonları (8x8): can, hasar, hız, menzil, saldırı hızı, zırh; 7 rol; 5 mekanik | P0 | **CC0 paket:** Kenney "1-Bit Pack" (CC0, 16x16; 8x8'e uyarlanmalı) **veya koddan üretilebilir** (8x8 elle piksel dizisi) | game-icons.net CC BY 3.0 (isim zorunlu, vektör; piksele çevrilmeli) |
| 6 | Efekt sprite'ları: vuruş yıldızı 5x5 (3 kare), kesik izi (3 kare), toz pufu 8x8 (3 kare), patlama 16x16 (4 kare), büyü parıltısı 5x5 (4 kare) | P1 | **Koddan üretilebilir** (araçla `Image` üzerine çizim, `build_audio.gd` gibi bir `build_fx.gd`) | Kenney Particle Pack (CC0) HD, piksele uygun değil |
| 7 | Yerde iz (decal): yanık, çamur birikintisi, krater | P1 | **Koddan üretilebilir** | — |
| 8 | Arayüz 9-dilim çerçeveleri: panel, düğme (3 durum), kart çerçevesi x3 tür, parşömen, kalp | P1 | **CC0 paket:** Kenney "UI Pack - RPG Expansion" (CC0) veya Kenney "Pixel UI Pack" (CC0; ad doğrulanmalı) **veya koddan üretilebilir** | Krallık şeridi kodla boyanır |
| 9 | Piksel zemin karoları 64x32 (çimen 8 varyant, toprak, bataklık, kül, kar) + ağaç/çalı 1x | P1 (A seçilirse) | **Koddan üretilebilir:** rubberduck CC0 dokularını 0.5x Nearest küçültme + palete indirgeme | Sonuç bulanıksa **çizilmeli** |
| 10 | Atlılar (Şövalye, Geyik Binicisi, Kurt Binicisi), Kentaurlar (tümü), Golemler (tümü), Cüce topu/mancınık (11 birlik) | P1 | **Çizilmeli** (CC0 pakette uygun at/kentaur yok). LPC atları CC-BY-SA / GPL: copyleft, **kaçınılmalı** | Geçici: `UnitSprites.generate` iyileştirmesi (kontur, 2 ton gölge, palet) |
| 11 | 10 boss, 64x64 doğal çizim (6 satır) | P1 | **Çizilmeli** | Bugünkü 2x/3x büyütme mixel yaratıyor |
| 12 | Koşu haritası: krallık kalkanları 16x16, yol, boss düğümü, işaretçi | P2 | **Koddan üretilebilir** (amblem + kalkan şekli) | — |
| 13 | Biyom atmosferi: `CanvasModulate` tonları, vinyet shader'ı, boss ışığı | P2 | **Koddan üretilebilir** (shader) | — |
| 14 | Ana menü arka planı / anahtar görsel, logo | P2 | **Çizilmeli** (sanatçı) | Mağaza kapsülleri de aynı görselden |
| 15 | Steam kapsülleri (920x430, 462x174, 1232x706, 748x896, 600x900, 3840x1240) | P3 | **Çizilmeli** | `yayin/magaza_metni.md` boyutları |

Diğer adaylar (CC0 değil, dikkat): Pixel Frog "Tiny Swords" (ücretsiz, özel lisans; tepeden görünüm, izometrik değil).
Kullanmadan önce lisans metni okunmalı.

---

## 7. Uygulama yol haritası

### Faz 1 — Juice ve okunabilirlik (stil kararından bağımsız, hemen başlanabilir)

**gorsel-efekt-ajani**

| # | Görev | Dosya | Kabul ölçütü |
|---|---|---|---|
| 1.1 | Güncel ekran görüntüleri al (savaş, boss, hazırlık, kart, harita), "önce" seti | `res://tools/battle_showcase.gd`, çıktı repo dışı geçici klasör | 5 görüntü; sonraki her görev önce/sonra kıyaslanır |
| 1.2 | HUD'u `CanvasLayer` üstüne al; dünya etiketleri HUD'un üstüne çizilmesin | `battle_controller.gd` / savaş sahnesi | Sancak sayısı hız düğmelerinin altında kalır |
| 1.3 | Saldırı atılımı (2 px lunge), geri itilme (1 px), flaş 70+40 ms | `squad_view.gd` | Showcase'te yakın dövüşte hareket görünür; `run_test.gd` sonucu aynı |
| 1.4 | Kayıp sayısı ("-N", 250 ms toplama), sancak sayacı darbesi, hücumda sarı "-N!" | `squad_view.gd`, `battle_fx.gd` | Aynı anda en fazla 16 yazı; x4'te okunur |
| 1.5 | Hit-stop ve son vuruş yavaş çekimi (sadece gösterim saati), 400 ms bekleme | `battle_controller.gd` | Savaş sonucu ve adım sayısı değişmez (`run_test.gd`, `boss_test.gd`) |
| 1.6 | Sarsıntı tablosunu uygula (5.6), tam sayı ofset | `battle_fx.gd`, `battle_camera.gd` | Değerler tablo ile birebir; ayar kapalıyken sıfır |
| 1.7 | Kamera yakınlık seviyelerini piksel kuralına göre düzelt (5.7) | `battle_camera.gd` | 3x pencerede durağan karede tüm birlik pikselleri eşit genişlikte |
| 1.8 | Takım zemin diski (9x3 + kenar), çatallı rakip sancağı, sancak seviye süsleri | `squad_view.gd` | Aynı krallıkla ayna savaşta iki ordu 1 sn içinde ayırt edilir |
| 1.9 | Ceset okunabilirliği: doygunluk düşür, alpha 0.8, 2.0 + 0.6 s | `battle_fx.gd` | Ceset yığınları canlı bölükle karışmaz (görüntü kıyası) |
| 1.10 | Formasyon kayması (±1 px sabit), 4 kare durma fazı | `squad_view.gd` | "Damga" görünümü kırılır; simülasyon dokunulmaz |
| 1.11 | Ekran geçişi (kararma), Overlay açılışı, kart dağıtımı/hover/seçim, düğme basma, sayı sayacı (5.5) | `screens.gd`, `overlay.gd`, `card_select.gd`, `ui_kit.gd` | Tüm süreler tabloyla aynı; hiçbir giriş kilitlenmez (animasyon sırasında tıklama çalışır veya animasyonu atlar) |
| 1.12 | Savaş girişi (1.2 s, atlanabilir), boss girişi, zafer/yenilgi sahnesi (5.4) | `battle_controller.gd`, yeni `battle_intro.gd` | Tıklayınca atlanır; test araçlarında kapalı |
| 1.13 | Yetenek imzaları: yükselen "+" (onarım), çamur birikintisi, yanık izi, ters ölüm (diriliş) | `battle_fx.gd` | Her mekanik showcase'te kendi rengi ve şekliyle ayırt edilir |

**gameplay-programci**

| # | Görev | Dosya / alan | Kabul ölçütü |
|---|---|---|---|
| 1.A | Görsel olay sinyalleri: `squad_charged(attacker, target)` (hücum ilk vuruşu), `squad_damaged(squad, soldiers_lost: int)`, `squad_healed(squad, amount: float)` | `battle_simulation.gd` | Sinyaller sadece yayınlanır; `run_test.gd`, `boss_test.gd`, denge testi sonuçları bit bit aynı |
| 1.B | Ayarlar: `hit_stop: bool = true`, `flash_effects: bool = true`, `team_outline: bool = false` | `scripts/meta/settings.gd`, `settings_panel.gd`, `tr()` metinleri, `en.po` | Ayar dosyasına yazılır/okunur; testler gerçek `user://settings.cfg`'ye yazmaz |
| 1.C | Krallık vurgu rengi alanı: `KingdomData.accent_color: Color` | `kingdom_data.gd`, 10 `.tres` | Varsayılan `color.darkened(0.4)`; arayüz bu alanı okuyabilir |
| 1.D | Test araçlarında giriş animasyonunu ve hit-stop'u kapatan bayrak | `battle_controller.gd` (`skip_intro`) | `battle_showcase.gd` ve headless testler eski süreyle çalışır |

### Faz 2 — Stil kilidi (kullanıcı sanat yönünü seçtikten sonra)

Aşağıdakiler Seçenek A içindir; B seçilirse 2.3 yerine zemin posterize/renk eşleme shader'ı yapılır.

**gorsel-efekt-ajani**

| # | Görev | Dosya | Kabul ölçütü |
|---|---|---|---|
| 2.1 | Seçilen paleti ekle, palete indirgeme adımını araca koy | `Fetih/assets/palette/<ad>.hex`, `tools/import_sprites.gd` | Üretilen tüm `assets/sprites/units/*.png` sadece palet renklerini içerir (araç doğrular, rapor basar) |
| 2.2 | Piksel yazı tipini temaya bağla (8/16 px), tüm `UiKit.label` boyutlarını 2 seviyeye indir | `ui_kit.gd`, `Fetih/assets/fonts/` | Türkçe karakterler doğru; varsayılan font hiçbir ekranda görünmez |
| 2.3 | Piksel zemin: rubberduck dokularını 0.5x + palet ile 64x32 1x karoya çeviren araç; `GroundArt` Nearest | yeni `tools/build_ground.gd`, `ground_art.gd` | Zemin pikseli birlik pikseliyle aynı boyutta; biyom tonları korunur |
| 2.4 | Koddan üretilen 11 birliği yeni palet + kontur + 2 ton gölge ile iyileştir (çizim gelene kadar) | `unit_sprites.gd` | Siluet testi (4.2) geçer; atlı, golem, kentaur, top ayrı okunur |
| 2.5 | Boss büyütmesini kaldır: boss çizimi gelene kadar 2x büyütmede 1 px kontur + iç gölge (mixel etkisini azaltma) | `import_sprites.gd` | Geçici çözüm; 3.2 ile değişir |
| 2.6 | Arayüz 9-dilim çerçeveleri, kart türü çerçeveleri, istatistik ikonları, krallık şeridi | `ui_kit.gd`, `card_select.gd`, `prep_screen.gd`, `army_slot.gd` | Kartta istatistikler ikonla; kart türü çerçeveden ayırt edilir |
| 2.7 | Koşu haritası: krallık kalkanları + amblemler, yol çizgisi, nabız, boss tacı | `run_map.gd` | İki harfli kısaltmalar kalkar; krallıklar renk + amblemle ayırt edilir |
| 2.8 | Biyom atmosferi: `CanvasModulate` tonu, vinyet shader'ı, boss savaşında doygunluk düşüşü | `battlefield.gd`, yeni shader | Compatibility renderer'da çalışır; FPS kaybı yok (5 bölük x 30 asker x 2 ordu) |
| 2.9 | Hazırlık ekranında karşılık okları (yeşil/kırmızı) ve sürükle-bırak hissi | `prep_screen.gd`, `army_slot.gd` | Oyuncu düşman önizlemesindeki her bölük için avantaj/dezavantajı görür |

**gameplay-programci**

| # | Görev | Dosya / alan | Kabul ölçütü |
|---|---|---|---|
| 2.A | Krallık renklerini 4.3 tablosuna göre güncelle (kullanıcı onayıyla) | `data/kingdoms/*.tres` `color`, `accent_color` | Hiçbir krallık rengi takım tonlarının ±15° içinde değil |
| 2.B | Amblem alanı: `KingdomData.emblem: Texture2D` (5x5 ve 12x12 tek sayfa) | `kingdom_data.gd`, `.tres` | Boşsa kodla üretilen yer tutucu |
| 2.C | Sprite sayfası satır sayısı alanı: `UnitData.sheet_rows: int = 4` (boss için 6: hasar, yetenek) | `unit_data.gd`, `unit_sprites.gd` (`ROWS` sabiti yerine alan) | 4 satırlık eski sayfalar değişmeden çalışır; 6 satırda kare boyutu = yükseklik / 6 |
| 2.D | Efekt rengi alanı: `UnitData.fx_color: Color` (varsayılan şeffaf = otomatik) | `unit_data.gd` | `BattleFx` mermi rengini önce bu alandan okur; boşsa bugünkü mantık |

### Faz 3 — Çizim ve cila

**gorsel-efekt-ajani**

| # | Görev | Dosya | Kabul ölçütü |
|---|---|---|---|
| 3.1 | Efekt sprite üretim aracı (vuruş yıldızı, kesik, toz, patlama, parıltı) ve `BattleFx`'te kullanımı | yeni `tools/build_fx.gd`, `battle_fx.gd` | Parçacık sayısı düşmeden görsel zenginlik artar; havuzlama, düğüm üretimi yok |
| 3.2 | Çizilen 11 birlik + 10 boss sayfasını hatta al, `SPECS`'i güncelle | `import_sprites.gd`, `assets/sprites/units/` | Sayfa düzeni (4 veya 6 satır) doğrulanır; `sprite_preview.gd` çıktısı temiz |
| 3.3 | Boss yetenek ve hasar satırlarını oynat (boss saldırısında telegraf) | `squad_view.gd` | Telegraf 360 ms görünür; sonuç değişmez |
| 3.4 | Ana menü canlı arka planı (ağır kamera kayması, yürüyen bölükler) | `kingdom_select.gd` | 60 FPS; tıklama gecikmesi yok |
| 3.5 | Mağaza ekran görüntülerini ve 30-60 sn fragman kaydını yeniden al | `yayin/ekran_goruntuleri/`, `battle_showcase.gd` | `magaza_metni.md`'deki "geçici sprite" notu kaldırılabilir |

**gameplay-programci**

| # | Görev | Dosya / alan | Kabul ölçütü |
|---|---|---|---|
| 3.A | Boss yetenek anı sinyali: `boss_ability(squad, kind: StringName)` (ör. alan vuruşu, çağırma) | `battle_simulation.gd` | Sadece yayın; determinizm testleri aynı |
| 3.B | Steam/itch kapsül boyutları ve ikon yeniden üretimi için araç güncellemesi | `tools/build_icon.gd` | Yeni logo/anahtar görselden tüm boyutlar üretilir |
| 3.C | `CLAUDE.md` görsel bölümünü kesinleşen kararlara göre güncelle (palet, piksel ölçeği, satır sayısı) | `CLAUDE.md` | Yeni ajanlar doğru kuralları okur |

---

## 8. Kullanıcıdan beklenen kararlar

1. **Sanat yönü:** A (tutarlı piksel, önerilen), B (HD zemin + piksel birlik) veya C (HD elle çizim). Faz 2 bu karara bağlı.
2. **HD zemin:** A seçilirse HD çimen zemin piksel zemine dönüşür. Kabul mü?
3. **Palet:** Resurrect 64 mü, Endesga 32 mi (veya başka)?
4. **Krallık renkleri:** 4.3 tablosu onaylanıyor mu? Özellikle İnsanlar maviden mora, İblisler kırmızıdan magma turuncusuna (alternatif: mor-magenta).
5. **Çizim kaynağı:** 11 birlik + 10 boss için sanatçı tutulacak mı (bütçe), kullanıcı mı çizecek, yoksa koddan üretilenler iyileştirilip kalacak mı?
6. **Yeni paket indirme izni:** Kenney (yazı tipi, ikon, arayüz) ve palet dosyası indirilip `kaynak_assetler/`'e eklenebilir mi?
7. **Savaş girişi süresi:** 1.2 s giriş ve zafer sahnesi her savaşta mı, yoksa sadece boss/ilk savaşta mı?
8. **Ton:** Kan/iç organ yok (bugünkü gibi damla parçacık) mı kalsın, yoksa daha sert (kırmızı kan, iz) mi?

### 8.1 Verilen kararlar (2026-10-14)

| # | Karar | Durum |
|---|---|---|
| 1 | **Seçenek A — Tutarlı piksel** | Kullanıcı onayladı |
| 2 | HD çimen zemin piksel zemine dönüşür | A'nın gereği (kabul) |
| 3 | **Palet: Resurrect 64** | Kullanıcı onayladı |
| 4 | Krallık renkleri 4.3 tablosu | Açık — varsayılan öneri uygulanır, kullanıcı itiraz edebilir |
| 5 | Çizim kaynağı | Açık — sprite ajanı sonucundan sonra karar |
| 6 | Kenney paketi indirme | Açık — indirme için kullanıcı izni gerekli |
| 7 | Savaş girişi | Açık — varsayılan: sadece ilk savaş + boss |
| 8 | Ton | Açık — varsayılan: bugünkü kansız ton |

Terim kararı: "bölük" İngilizcede **squad** kalır.
