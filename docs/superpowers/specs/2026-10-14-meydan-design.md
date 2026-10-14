# Meydan: tek sahnede hazırlık, savaş ve kart seçimi

Tarih: 2026-10-14. Durum: kullanıcı onayladı (sohbette).

## Amaç

Hazırlık (ordu düzeni), savaş ve kart seçimi ayrı ekranlarda değil, savaş alanının olduğu tek
sahnede ("ana meydan") olur. 9 Kings'teki gibi oyuncu ordusunu doğrudan alanda görür ve düzenler.
Aynı turda üç görsel sorun da çözülür: karolara bölünmüş ve gürültülü zemin, fare altındaki karo
vurgusu, formasyonda üst üste binen toplar. Kamera şimdiki görünümün yatay aynasından bakar.

## Kapsam dışı

- Krallık seçimi, hazine (treasury) ve koşu sonu (run_end) ekranları ayrı kalır.
- Denge sayıları değişmez. Yeni mekanik eklenmez.
- Simülasyon kuralları değişmez (sadece başlangıç konumunun kaynağı değişir).

## Kararlar (kullanıcıyla)

| Soru | Karar |
|------|-------|
| Birleşme düzeyi | Tam meydan: tek sahne, alanda sürükleme, kartlar alanın üstünde, kart etkisi alanda canlanır |
| Yerleşim | Serbest: bölük kendi bölgesinde istenen noktaya konur |
| Ön cephe / arka saf fermanları | Derinlik bantları: bölgenin rakibe yakın üçte biri ön, uzak üçte biri arka |
| Zemin | Sakin boyalı çimen: tek görüntü, büyük yumuşak ton lekeleri, dither geçiş, seyrek süs |

## A. Görsel düzeltmeler

### A1. Tek parça zemin
- `GroundArt` karo karo çizmez. Alan + kenar araziyi kapsayan tek bir `Image` üretilir
  (`Image.create`, sonra `ImageTexture.create_from_image`), bir kez çizilir.
- Renkler: biyomun `ramp` dizisi (koyu, orta, açık). Düşük frekanslı gürültü (`FastNoiseLite`,
  seed sabit, biyoma göre) iki eşikle üç tona ayrılır; eşik çevresinde 2x2 Bayer dither.
  Leke boyu en az ~3 karo: kamuflaj deseni oluşmaz.
- Görüntü izometrik eşkenar dörtgen içinde kalır; dışı koyu arazi tonuyla doldurulur.
  Kenar karo dikişi yoktur.
- Süsler (ot, taş) mevcut sayfalardan, yoğunluk yaklaşık yarıya iner. Ağaçlar aynı kalır.
- Bölge renkleri savaşta çizilmez. Hazırlıkta sadece oyuncu bölgesi çok hafif
  (alfa ~0.08) yumuşak kenarlı bir alanla belirir.
- Palet kuralı: üretilen her piksel Resurrect 64 içinde kalır (ramp zaten palette).

### A2. Fare vurgusu
- `Highlight` TileMapLayer, `DebugHUD/CellLabel` ve `_update_hover` kaldırılır.
  `set_debug_tools` sadece tıklanan konum çıktısını (test modunda) açar.

### A3. Ayna kamera
- `Battlefield.field_offset_to_world(d)` = `Vector2(TILE_HALF.x * (d.y - d.x), TILE_HALF.y * (d.x + d.y))`.
  Oyuncu sağ altta, rakip sol üstte görünür.
- Görünmez `Ground` TileMapLayer kaldırılır. Ters dönüşüm `Battlefield.world_to_field(p)` ile yapılır.
  `map_to_local` / `local_to_map` kullanan yerler bu iki fonksiyona geçer.
- `SquadView` yönü `world_facing.x` işaretinden hesapladığı için sprite çevirme kendiliğinden doğru olur.
- `GroundArt` ve ağaç yerleşimi aynı dönüşümü kullanır.

### A4. Toplar
- `SquadView.SOLDIER_SPACING` sabiti birim başına olur: `spacing_for(unit)`. Kuşatma rolü
  (top, mancınık) sprite genişliğine göre en az ~0.5 karo aralık alır.
  Sadece görüntü; simülasyon değişmez.

## B. Serbest yerleşim

### B1. Veri
- `ArmySquad.cell: Vector2i` yerine `ArmySquad.pos: Vector2` gelir. Koordinat oyuncunun kendi
  bölgesine göredir: `x` ∈ [0, FIELD_WIDTH - 1], `depth` ∈ [0, DEPLOY_DEPTH]; `depth = 0` ön.
  `Formation.DEPLOY_DEPTH := 2.9` (bugünkü 3 ızgara sırası 0, 1, 2 derinliğinde; bantlar bunlara denk gelsin).
- `Formation.deploy_to_field(pos, team)`: bölge koordinatı → savaş alanı koordinatı.
  Rakip bunu aynalayarak kullanır (bugünkü `grid_to_field` gibi).
- `Formation.MIN_GAP := 1.0` karo: iki bölük merkezi arasındaki en az mesafe (bugünkü sıra aralığı;
  formasyon ~1 karo yayılır). `Formation.nearest_free(pos, others)` dolu yere bırakılan bölüğü
  en yakın boş noktaya kaydırır.

### B2. Bantlar ve fermanlar
- `ArmySquad.band()` → `FRONT`, `MIDDLE`, `BACK`. `depth < 0.5` ön, `depth >= 1.5` arka, arası orta.
  Bugünkü ızgara sıraları (0, 1, 2) sırasıyla ön, orta, arka banda düşer: fermanlar aynı bölüklere uygulanır.
  Bant sınırları sürüklerken alanda çok hafif çizgiyle gösterilir.
- `PassiveData.applies_to(squad)` bugünkü `cell.y == 0` / `cell.y == grid_size.y - 1` yerine
  `band()` kullanır. `grid_size` parametresi kalkar (`SquadBuilder.build` dahil).

### B3. Otomatik dizilim ve testler
- `ArmyGenerator.auto_arrange` bugünkü 3x3 mantığını korur ama sonucu `pos` olarak yazar.
  Ürettiği konumlar bugünkü `grid_to_field` konumlarıyla aynıdır.
- Kabul: `run_test.gd`, `boss_test.gd`, `upgrade_test.gd` ve `run_balance_test.ps1`
  çıktısı değişiklikten önceki ile birebir aynı.

### B4. Kayıt
- `to_dict` bölük için `"pos": [x, depth]` yazar. `from_dict` eski `"cell"` alanını
  `auto_arrange` konumuna çevirerek okur. `save_test.gd` iki biçimi de dener.

## C. Meydan sahnesi

### C1. Yapı
```
Meydan (Node2D, meydan.gd: aşama makinesi)
├── Battlefield (mevcut sahne)
├── BattleRunner (Node: simülasyonu adımlar, SquadView'ları yönetir; battle_controller'dan ayrılır)
├── PrepLayer (CanvasLayer: üst şerit, harita, bilgi paneli, "Savaşa başla"; alanda sürükleme)
├── BattleHud (CanvasLayer: hız düğmeleri, alt şerit, sonuç paneli; mevcut HUD)
└── CardLayer (CanvasLayer: kart paneli, yeniden çek, geç)
```
- `meydan.gd` aşamayı tutar: `PREP`, `BATTLE`, `CARDS`. Her aşama girişinde ilgili katman
  görünür, diğerleri gizlenir. Aşama değişince `Profile.store_run(RunState.to_dict(<aşama>))`.
- `battle.tscn` test modu (F6) ve `battle_showcase.gd` için kalır; `BattleRunner`'ı kullanır.
- Silinenler: `scenes/run/prep.tscn`, `scenes/ui/card_select.tscn`, `scripts/run/prep_screen.gd`,
  `scripts/ui/card_select.gd`, `scripts/ui/army_slot.gd`. İçlerindeki metin ve bilgi satırları
  (ferman listesi, rakip satırları, kart doldurma) yeni katmanlara taşınır; `tr()` metinleri korunur.
- `Screens.PHASE_SCENES` üç aşamayı da `meydan.tscn`'e yönlendirir; sahne açılınca
  `Profile.saved_run.phase` ya da `RunState` durumuna göre aşamaya girer.

### C2. PREP
- Oyuncu bölükleri kendi konumlarında durur (durma animasyonu). Rakip ordusu karşı tarafta durur.
- Sürükleme: bölüğün üstünde sol tık basılı tutulur, bölük fareyi izler (bölge sınırına kenetlenir),
  bırakınca `nearest_free` ile oturur. Sürüklerken bant adı ("Ön cephe" / "Orta" / "Arka saf")
  bölüğün üstünde küçük yazıyla görünür. Bölüğün üstüne gelmek ayrıntı panelini doldurur
  (bugünkü `_show_info` içeriği). Rakip bölüğüne gelmek de bilgi gösterir.
- Kamera sabit: iki orduyu içine alan çerçeve, el ile kaydırma açık.
- Üst şerit: savaş n/20, can, krallık, harita (`RunMap`). Fermanlar satırı. "Savaşa başla".

### C3. BATTLE
- Bugünkü savaş: `BattleRunner.start(player_states, enemy_states)`, hız düğmeleri, duraklatma,
  takip kamerası, sonuç paneli. "Devam" → koşu bittiyse `RUN_END`, bitmediyse `CARDS` aşaması.

### C4. CARDS
- Alan temizlenir: ölü askerler ve efektler silinir, oyuncu bölükleri tam güçle kendi
  konumlarında belirir (kısa solma). Rakip ordusu kalkar.
- Kart paneli alt kısımda (ekranın ~%40'ı), alan üstte görünür. Kart içeriği bugünkü
  `card_select.gd` kartlarıyla aynı. Yeniden çek ve "Kart alma, devam et" düğmeleri.
- Kart etkisi alanda:
  - Birlik: yeni bölük arka kenardan yürüyerek `RunState`'in verdiği boş noktaya gelir.
    Ordu doluysa panel "Değiştirilecek bölüğü seç" der; oyuncu alanda bir bölüğe tıklar.
  - Yükseltme: hedef bölük parlar (`SquadView.flash`), seviye yazısı güncellenir.
  - Ferman: etkilenen bölükler parlar, fermanlar satırına eklenir.
- Etki animasyonu bitince yeni rakip ordusu belirir ve `PREP` aşamasına geçilir.

### C5. Kayıt ve devam
- Aşama adları değişmez (`prep`, `battle`, `cards`). Kayıttan devam eden oyuncu `meydan.tscn`'de
  ilgili aşamaya girer. `battle` aşamasından devam savaşı baştan oynatır (bugünkü gibi).

## Test ve kabul

- Her parça ayrı commit: A, B, C.
- A: `sprite_preview` ve `battle_showcase` ekran görüntüsü; zeminde karo sınırı ve kamuflaj deseni
  yok; oyuncu sağ altta; toplar üst üste binmiyor.
- B: dört denge/koşu testinin çıktısı değişiklikten önceki ile aynı; `save_test.gd` geçer.
- C: headless akış testi (yeni `res://tools/meydan_test.gd`): koşu başlat, PREP → BATTLE → CARDS →
  PREP döngüsü 3 savaş, kart seç, kaydet ve devam et. Her aşamadan ekran görüntüsü.
- Çeviri: yeni metinler için `update_translations.gd`, boş msgstr'ler doldurulur.
