# Arayüz yenileme (UI1–UI8) — tasarım

Tarih: 2026-10-15 · Sürüm hedefi: 0.13.0 · Önceki: grafik devrimi (GR1–GR11), Meydan (T1–T12)

## Amaç

Oyun "demode" görünüyor. Kullanıcının istekleri:

1. Giriş ekranı yok: animasyonlu, modern bir ana menü (Devam / Yeni oyun / Hazine / İstatistikler / Ayarlar / Çık).
2. Krallık seçimi düz buton ızgarası + yazı paneli: animasyonlu, görsel bir ekran olsun.
3. Bölüklerin üstündeki asker sayıları ("20", "10", "17") kalksın.
4. Üstteki rakip sırası çubuğu ("Ça Go Ke El…") kalksın; yerine sade aşama göstergesi.
5. Canlar animasyonlu kalplerle gösterilsin.
6. Ordu arkasındaki kamp evleri kalksın (9 Kings'e fazla benzedi); her krallığın kendi manzarası olsun.
7. Gereksiz yazılar kalksın, yazılar modern görünsün.
8. Ayarlar elden geçirilsin.

**Başarı ölçütü:** Kullanıcı ana menüyü, krallık seçimini ve Meydan'ı ekran görüntüsünde "modern ve şık" bulur;
Meydan ekranında bölük üstünde sayı, rakip sırası çubuğu ve açıklama metni kalmaz; her rakip krallığın
savaş alanı tek bakışta ayırt edilir.

## Kararlar (kullanıcı onaylı)

| Konu | Karar |
|---|---|
| Görsel dil | **İki tema.** Menü ekranları (giriş, krallık seçimi, ayarlar, hazine, istatistik, koşu sonu) **renkli fantastik**. Oyun içi (Meydan: hazırlık, savaş, kartlar, duraklat) **koyu şık**. |
| Yazı tipi | **Modern düz font** (piksel değil). Piksel font kuralı kalkar. |
| Giriş | Kısa logo açılışı + **canlı katmanlı manzara** arka planı. |
| Menü düğmeleri | Devam et (varsa) / Yeni oyun / Hazine / İstatistikler / Ayarlar / Çık. |
| Krallık seçimi | Üstte **10 dalgalanan sancak**, altında seçilen krallığın **canlı dioraması** + bilgi kartı + büyük "Başla". |
| Savaş alanı | Manzara **rakip krallığa göre**; kamp evleri kalkar, her ordunun arkasında **kendi renginde tek sancak**. |

## Kullanıcı yokken önerilenle seçilenler (itiraz edilebilir)

- Fontlar: başlıklar **Cinzel** (OFL, fantastik, büyük harf), metin **Nunito** (OFL, yuvarlak, okunur). İkisi de
  Google Fonts / `github.com/google/fonts` (OFL) kaynaklı; Türkçe harf (ğ ş ı İ ö ü ç) desteği font testinde
  doğrulanır, eksikse yedek **Alegreya SC** + **Inter**. İndirme kullanıcı onayıyla yapılır.
- Kalpler Meydan'da sol üst köşede (aşama göstergesinin solunda).
- Aşama göstergesi: 20 noktalık ince çizgi; 5., 10., 15., 20. noktalar boss tacı; geçilenler dolu, şu anki
  büyük ve nabız atan; rakip adı yazmaz (üstüne gelince ipucunda yazar).
- Hasar sayıları (-30 gibi) ayardaki açma/kapama ile kalır; sadece **asker sayısı etiketleri** kalkar.
- Bölük ayrıntısı yazısı sadece fare bölüğün üstündeyken küçük bir kartta çıkar; sabit "Bir bölüğün üstüne gel…"
  ipucu metni kalkar (ilk koşuda `Tips` bir kez söyler).
- Manzara ve sancak çizimleri koddan (Resurrect 64 paleti), harici sanat indirilmez.

## Tasarım

### 1. Tema ve yazı (UI1)

- `UiKit` iki tema üretir: `UiKit.theme_menu()` (renkli fantastik) ve `UiKit.theme_game()` (koyu şık).
  `UiKit.theme()` geriye uyum için `theme_game()` döner.
- **Renk belirteçleri** (`const`): ortak metin/altın/iyi/kötü; menü için gece mavisi gökyüzü + sıcak altın +
  parşömen paneller (`StyleBoxFlat`: yuvarlatılmış köşe 6–8 px, kalın 2 px altın kenar, alt gölge);
  oyun için `#121418` civarı %80 saydam paneller, 1 px ince altın kenar, köşe 4 px, gölge.
- **Font**: `FontFile` + `FontVariation` (Godot: aynı dosyadan kalınlık/aralık türevi). Cinzel başlık
  (Bold), Nunito metin (Regular/SemiBold/Bold). `UiKit.font_spec` ve piksel-kat oturtma kalkar;
  `UiKit.label(text, size)` aynı imzayla kalır, boyut doğrudan uygulanır. `UiKit.pixel_font()` çizim
  kodunda `UiKit.ui_font()` ile değişir.
- Netlik: stretch `canvas_items` metni pencere çözünürlüğünde çizer (Godot font oversampling). Font
  antialiasing gri, hinting hafif; UI kök Control'lerinde `texture_filter = LINEAR` (sahne Nearest kalır).
- Ortak animasyon yardımcıları `UiKit`: `fade_in(node, delay)`, `slide_in(node, from, delay)`,
  `pop(node)` (ölçek 0.9→1.0, `Tween` TRANS_BACK), düğmede üstüne gelince hafif büyüme + parlama
  (mevcut `hover_scale` genişler), basınca 0.95 ölçek. Ayar "Ekran efektleri" kapalıysa süreler kısalır.
- Düğme türleri: `UiKit.button_primary` (büyük, altın dolgu), `UiKit.button` (normal),
  `UiKit.button_ghost` (sadece kenar). Odak (focus) çerçevesi tek tip ve sadece klavye/gamepad ile.

### 2. Giriş ve ana menü (UI2)

- Yeni sahne `scenes/ui/main_menu.tscn` + `scripts/ui/main_menu.gd`; `project.godot` `run/main_scene` bu olur.
  `Screens.MAIN_MENU` eklenir; krallık seçimi, hazine, koşu sonu "geri" ile ana menüye döner.
- **Logo açılışı** (yalnız oyun açılışında, ~2.5 sn, tık/tuşla geçilir): ekran siyah → "FETİH" harfleri
  sırayla düşer (Cinzel, büyük, altın), bir kılıç parıltısı soldan sağa geçer, alt başlık solar → menü
  düğmeleri alttan kayarak gelir. `Settings`'e dokunmaz.
- **Canlı manzara** `scripts/ui/menu_backdrop.gd` (`Control`, `_draw` + `_process`): katmanlar
  (uzaktan yakına) gökyüzü degrade + yıldız/güneş, yavaş kayan bulutlar, uzak dağlar, tepe üstünde kale
  silueti ve dalgalanan sancaklar, ön tepeler/ağaçlar (`assets/terrain/px/plants`), arada uçan kuş sürüsü.
  Fare hareketiyle hafif paralaks (katman başına 1–8 px). Hepsi palet renkleri, seed sabit.
- Düzen: solda logo, altında dikey düğme sütunu (Devam et varsa en üstte, altın; altında küçük
  "Orklar · savaş 4" bilgisi), sağ altta sürüm ve Şan. Başka yazı yok.
- **İstatistikler** penceresi (`Overlay`): oynanan koşu, fetih, en uzun savaş, krallık başına fetih
  (sancak simgeleriyle). Eski alt satırdaki istatistik yazısı kalkar.
- "Yeni oyun" yarım koşu varken onay sorar ("Yarım kalan koşu silinir").

### 3. Krallık seçimi (UI3)

- `kingdom_select.gd` baştan yazılır, `theme_menu()` kullanır, arka planda soluk `MenuBackdrop`.
- **Sancak sırası** (üstte, 10 adet): `KingdomBanner` (`Control`): direk + krallık `color`/`accent_color`
  bez + krallık amblemi (koddan basit simge: taç, yaprak, balta, kafatası, boynuz…); bez kenarı
  `sin` ile dalgalanır. Seçilen sancak 8 px yukarı kalkar ve parlar; kilitli sancak gri, zincir + kilit
  simgesi. Üstüne gelince hafif sallanır.
- **Diorama** (sol, büyük): `KingdomDiorama` (`Control`, kendi `_draw`'ı; `Battlefield` kullanılmaz,
  hafif kalsın): krallığın biyom zemini (`GroundArt` renkleri + o krallığın manzara süsleri, bkz. §5)
  üstünde başlangıç birliklerinden 6–10 minik figür (`MiniUnitArt`, durma/yürüme animasyonu) ve sancak.
  Krallık değişince sahne yana kayarak değişir (`Tween`).
- **Bilgi kartı** (sağ): krallık adı (Cinzel), uzmanlık rozeti, 1–2 cümle açıklama, başlangıç fermanı
  (simge + ad; açıklama ipucunda), birlik simgeleri sırası (ad ipucunda), boss simgesi. Uzun liste
  yazısı kalkar. Altta büyük "Başla" (`button_primary`); kilitliyse kilit açma koşulu tek satır.
- Klavye: ←/→ krallık değiştirir, Enter başlar, Esc ana menü.

### 4. Ayarlar (UI4)

- `SettingsPanel` menü temasında (oyun içinde açılınca oyun teması) yeniden kurulur; sekmeler:
  **Ses** (ana/müzik/efekt sürgüleri, yüzde göstergesi), **Görüntü** (tam ekran, pencere boyutu),
  **Oyun** (savaş hızı, ekran sarsıntısı, vuruş flaşı, hasar sayıları, vuruş duraklaması,
  ipuçlarını sıfırla), **Dil**. Sekmeler `TabBar` + kayarak değişen içerik.
- Hatalar: açma/kapama düğmelerindeki tutarsız sarı odak çerçevesi kalkar (odak stili tek tip);
  sürgülerin gösterdiği değer gerçek ayarla eşleşir (gösterim modunda da). Satırlar eşit yükseklikte.
- `PauseMenu` aynı görsel dili (oyun teması) kullanır.

### 5. Savaş alanı: krallık manzaraları ve sancak (UI7)

- `KingdomCamp` ve `building_art.gd` kaldırılır; `Battlefield._camps` → `_banners`.
- **Ordu sancağı** `unit_art/banner_art.gd`: direk + krallık renginde bez + amblem, her ordunun
  arka kenarının ortasında tek sancak, bez dalgalanır (2–3 karelik animasyon). Kamera sınırı
  (`battlefield.gd:125`) sancağı kapsayacak kadar daralır.
- **Manzara süsleri** `GroundArt.BIOMES` genişler: her krallığa `props` listesi (koddan palet içi çizim,
  `unit_art/terrain_props.gd`) ve gerekiyorsa ikinci zemin motifi:
  - İnsanlar: ekin tarlası şeritleri, çit, saman balyası · Elfler: dev ağaç, mantar, ışık böcekleri
  - Orklar: kuru bozkır, kemik, kazıklı çit · Cüceler: kaya, maden arabası, kristal damar
  - Ölüler: mezar taşı, kuru ağaç, sis lekesi · İblisler: lav çatlağı (parlayan), obsidyen sivri
  - Slime'lar: yeşil gölcük, kabarcık · Çamurlar: çamur birikintisi, kamış
  - Golemler: kristal küme, yıkık sütun · Kentaurlar: savan otu, tek akasya ağacı
- Süsler alan kenarında ve dışında öbeklenir, yerleşim bölgesine girmez (mevcut ağaç kuralı);
  `y_sort` ile birliklerle doğru sıralanır. Parlayanlar (lav, kristal, ışık böceği) yavaşça nefes alır.
- Hepsi sadece görüntü; simülasyon ve determinizm değişmez.

### 6. Meydan arayüzü: sadeleştirme ve koyu şık tema (UI5, UI6)

- **Kalkanlar:** `SquadView._draw_count_label` (asker sayısı) ve ilgili `_count_pulse`; `RunMap`
  (rakip sırası çubuğu) ve `SquadInfo.top_bar` metinleri; sol paneldeki sabit ipucu cümlesi;
  savaş alt şeridindeki "Süre: 7.0 sn" (test modunda seed yazısı kalır).
- **Üst orta: `RunProgress`** (`scripts/ui/run_progress.gd`): 20 nokta + boss tacı; şu anki nokta
  nabız atar; aşama değişince ilerleme çizgisi dolar (`Tween`). İpucunda "Savaş 4 · Elfler".
- **Sol üst: `LivesHearts`** (`scripts/ui/lives_hearts.gd`): 3 piksel kalp, hafif nefes animasyonu;
  can kaybında kalp sallanıp kırılır (iki parçaya ayrılıp düşer), boş kalp kontur kalır.
  Meydan'da hazırlık ve savaşta görünür.
- **Rakip kartı** (hazırlık, sol): krallık amblemi + adı + güç sayısı; bölükler simge sırası
  (birlik ikonu + seviye noktaları); fermanlar küçük simge (ad/açıklama ipucunda). Uzun yazı yok.
- **Bölük kartı**: fare bölüğün üstündeyken imlecin yanında küçük kart (ad, seviye, can/hasar
  çubukları). Sürüklerken bant adı (ön/orta/arka) kalır.
- **Savaş HUD**: sağ üst hız düğmeleri yuvarlak simge düğmeleri (▶, ▶▶, ▶▶▶, ❚❚); sol üst eşleşme
  yazısı kalkar (bilgi `RunProgress`'te). Sonuç paneli ("Zafer!") ortada büyük, pop animasyonlu.
- **Kart paneli**: koyu şık kartlar, yuvarlatılmış köşe, birlik/ferman/yükseltme türüne göre ince
  renkli üst şerit, kart sırayla alttan kayarak gelir, üstüne gelince kalkar. "Kart alma, devam et"
  `button_ghost`. Başlık "Zafer! Elfler ganimeti" kısalır: "Ganimet seç".
- Duraklat menüsü, koşu sonu ekranı (koşu sonu menü temasına geçer) aynı dille.

### 7. Çeviri, belgeler, sürüm (UI8)

- Yeni/değişen metinler `tr()`; `res://tools/update_translations.gd` + `en.po` doldurulur; kullanılmayan
  eski msgid'ler (ör. "Can: %d / %d", "Bir bölüğün üstüne gel…") temizlenir.
- `CLAUDE.md` güncellenir: piksel font satırı → yeni font/tema kuralı; ekran akışı (ana menü);
  `KingdomCamp` → sancak + manzara süsleri; `RunMap` → `RunProgress`.
- Sürüm 0.13.0, yeni Windows build.

## Aşamalar

| Aşama | İçerik | Bağımlılık |
|---|---|---|
| UI1 | Fontlar (indirme + Türkçe doğrulama), iki tema, düğme türleri, animasyon yardımcıları | — |
| UI2 | Ana menü, logo açılışı, canlı manzara, istatistik penceresi, `main_scene` | UI1 |
| UI3 | Krallık seçimi: sancaklar, diorama, bilgi kartı | UI1, UI7 süsleri (diorama) |
| UI4 | Ayarlar + duraklat menüsü yenileme, odak/sürgü hataları | UI1 |
| UI5 | Meydan sadeleştirme: sayı etiketleri, `RunMap`, ipucu metni kalkar; `RunProgress`, `LivesHearts`, rakip/bölük kartı | UI1 |
| UI6 | Savaş HUD + kart paneli + koşu sonu koyu şık | UI1, UI5 |
| UI7 | Kamp kalkar, ordu sancağı, krallık manzara süsleri | — (UI1'den bağımsız) |
| UI8 | Çeviri, `CLAUDE.md`, sürüm 0.13.0, build | hepsi |

Sıra: UI1 → UI7 → UI5 → UI6 → UI2 → UI3 → UI4 → UI8. (Meydan en çok görülen ekran; önce o temizlenir.)

## Test

- `res://tools/font_test.gd` yeni fonta göre yeniden yazılır: Türkçe harflerin glif varlığı, tema
  boyutları. `font_preview.gd` korunur.
- Yeni `res://tools/menu_test.gd`: ana menü düğmeleri (kayıt varken/yokken), "Yeni oyun" onayı,
  krallık seçimi klavye gezinmesi, kilitli krallıkla başlanamaması, sürgü değerinin ayarla eşleşmesi.
  Gösterim profili kullanılır; **gerçek `save.json` / `settings.cfg`'ye yazılmaz.**
- `field_test.gd`: kamp testleri → sancak konumu ve manzara süslerinin yerleşim bölgesine girmemesi.
- `meydan_test.gd`: `RunProgress` noktası = `battle_index`; can kaybında `LivesHearts` güncellenir.
- `card_fit_test.gd`: yeni font ve kart düzeninde metin taşmaz.
- Görsel: `battle_showcase.gd -- scene res://scenes/ui/main_menu.tscn`, `-- meydan prep|battle|cards`,
  her krallık için `-- meydan prep <sıra>` ekran görüntüsü; önce/sonra kıyası.
- Simülasyona dokunulmadığı için denge testi gerekmez; `run_test.gd` bir kez çalıştırılıp değişmediği görülür.

## Kapsam dışı

- Oyun mekaniği, denge sayıları, yeni içerik.
- Ses/müzik değişikliği (mevcut `menu` müziği ana menüde çalar).
- Harici çizim/sanat paketi (fontlar hariç).

## Riskler

- **Font netliği:** düz font 640x360 düzenden ölçeklenince bulanık olabilir → oversampling ve
  `LINEAR` filtre ile denenir; olmazsa UI kökü için ayrı `CanvasLayer` + font boyutu ölçek çarpanı.
- **Diorama maliyeti:** her seçimde yeniden kurulum; 10 krallık için önbellek (`ImageTexture`) tutulur.
- **Metin genişliği:** düz font piksel fonttan geniş/dar olabilir → `card_fit_test` ve ekran görüntüsü.
