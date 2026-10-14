# Grafik Devrimi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Savaş alanı ve oyun içi arayüzü 9 Kings görsel diline geçirmek (uzak izometrik kamera, düz zemin, minik kalabalık birlikler, krallık yapıları, parlak efektler, sade arayüz).

**Architecture:** Sadece görüntü katmanı değişir: `Battlefield` dönüşümü (ayna), `GroundArt` (düz zemin), `BattleCamera` (uzak), yeni `MiniUnitArt` + `UnitSprites` geçişi, `SquadView` (formasyon, gölge, sayı), yeni `BuildingArt` + `KingdomCamp`, `BattleFx` ölçeği, `UiKit` teması ve oyun içi ekranların düzeni. Simülasyon ve denge dokunulmaz.

**Tech Stack:** Godot 4.7.2, GDScript, `Image` ile koddan piksel sanat, headless test scriptleri.

**Spec:** `docs/superpowers/specs/2026-10-15-grafik-devrimi-design.md` (ayrıca `docs/superpowers/plans/2026-10-14-meydan.md` Task 0 ve Task 1 metni aynen kullanılır).

## Global Constraints

- Godot: `$G = "C:\Users\Samet PC\Desktop\Godot_v4.7.2-stable_win64.exe"`; komutlar çalışma klasöründen: `& $G --headless --path Fetih -s res://tools/<script>.gd`.
- Simülasyon, `balance.gd`, `Fetih/data/**/*.tres` DEĞİŞMEZ (denge ayrı dalda yürüyor; çakışma olmasın).
- Bütün yeni pikseller Resurrect 64 paletinde (`SpritePalette.quantize` / `SpritePalette.nearest_step`); Nearest süzme; dünya konumları tam piksel.
- UI metinleri `tr()` (statikte `UiKit.t()`); yeni metin varsa `update_translations.gd` + `Fetih/i18n/en.po`.
- Testler oyuncunun `user://save.json` ve `user://settings.cfg` dosyalarına yazmaz.
- Araç scriptleri autoload adlarını derleme anında tanımaz (`root.get_node("RunState")`).
- Her task sonunda: test komutları, ekran görüntüsü (görsel task'larda), commit (mesaj sonunda `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`); push'u ana oturum yapar.
- Task raporunda kullanılan Godot kavramı bir cümleyle açıklanır (kullanıcı Godot öğreniyor).

## Review Focus

- Çok kalabalık bölük (Sv 5 takviyeli, 40+ asker): formasyon alanın dışına taşmaz, figürler üst üste binmez.
- Boss savaşı: boss büyük ve okunur kalır, can çubuğu görünür; yeni minik ölçek boss'u küçültmez.
- Aynı birlik iki tarafta (ayna maç): takım rengi (altın / kırmızı) tek bakışta ayırt edilir.
- Ayarlar "vuruş flaşı" ve "ekran sarsıntısı" kapalıyken yeni efektler de söner.
- Kamera elle kaydırma/yakınlaştırma (WASD, tekerlek, F) yeni yakınlık seviyelerinde çalışır.

Testleri: GR5 Step 3 (kalabalık), GR5 Step 4 (boss, ayna maç ekran görüntüsü), GR7 Step 3 (ayarlar), GR3 Step 3 (kamera).

---

### GR0: Temel çıktılar

- [ ] Meydan planı Task 0 aynen: `run_test`, `boss_test`, `upgrade_test`, `save_test` çıktıları `$S\base_*.txt`.
- [ ] "Önce" ekran görüntüleri: `& $G --path Fetih -s res://tools/battle_showcase.gd --write-movie "Fetih/tools/reports/grafik_9k/once/normal.png" --quit-after 150 -- 22 notips`; `-- boss 3 notips` (`boss.png`); `-- scene res://scenes/run/prep.tscn notips` (`prep.png`); `-- scene res://scenes/ui/card_select.tscn notips` (`cards.png`). `--write-movie` dosya adına kare numarası ekler; son kareyi tut, diğerlerini sil.

### GR1: Ayna kamera, TileMap ve fare vurgusu kaldırma

Meydan planı **Task 1** (Step 1-6) aynen uygulanır: `field_offset_to_world` aynalı, `world_to_field`, `mouse_field`, `zone_of_field`, `Ground`/`Highlight`/`DebugHUD` silinir, `Fetih/tools/field_test.gd` oluşturulur.
Kabul: field_test "Hata: 0"; run_test çıktısı `base_run.txt` ile aynı.

### GR2: Düz zemin ve seyrek motif (spec G1)

**Files:** Modify `Fetih/scripts/battle/ground_art.gd`; Modify `Fetih/tools/field_test.gd`.

**Interfaces:** Produces `static GroundArt.motif_points(biome_id: StringName, rect: Rect2i) -> Array[Vector3i]` (x, y, motif türü; deterministik), `GroundArt.show_player_zone(on: bool)`.

- [ ] **Step 1: Test** (field_test'e):
```gdscript
func test_ground() -> void:
	var rect := Rect2i(-9, -9, 28, 34)  # alan + MARGIN (karo)
	var a := GroundArt.motif_points(&"default", rect)
	var b := GroundArt.motif_points(&"default", rect)
	check("motif deterministik", a == b)
	var per_tile := float(a.size()) / (rect.size.x * rect.size.y)
	check("motif seyrek (%.2f/karo)" % per_tile, per_tile > 0.15 and per_tile < 0.45)
```
- [ ] **Step 2:** Çalıştır, `motif_points` yok hatasını gör.
- [ ] **Step 3: Uygula:**
  - `_draw()`: (1) `draw_rect(BACKDROP)` biyomun `ramp[1]` rengiyle (düz zemin, alanın içi ve dışı aynı); (2) motifler; (3) `_show_zone` ise oyuncu bölgesi `_diamond(Vector2(0, d - rows), Vector2(w, d))` `Color(1, 0.85, 0.3, 0.06)`; (4) seyrek kenar süsleri (`_draw_decals`, alan içi eşik 0.04, dışarıda 0.12/0.18/0.22). Karo döngüsü, `ZONE_TINT`, alan sınırı polyline'ı silinir.
  - Motifler: karo başına `_cell_rng(cell, 4)`; `randf() < 0.3` ise karo içinde rastgele noktada bir motif. Türler biyoma göre: çimen biyomları (default, humans, elves, slimes, dwarves) 3 px ot tutamı `ramp[2]` ("ı ı" biçimi: 1x2 + 1x3 + 1x2 dikey çubuk), çöl/kuru (orcs, centaurs) 5 px kum dalgası `ramp[0]` (yatay 2 px - 1 px yukarı - 2 px), karanlık (undead, demons, mud, golems) 2x1 taşçık `ramp[2]`. Hepsi `draw_rect` ile, tam piksel.
  - `motif_points` aynı RNG'yi kullanan statik fonksiyon; `_draw` onu çağırır (test ile görüntü aynı kaynaktan).
  - `show_player_zone(on)`: `_show_zone = on; queue_redraw()`. Hazırlık ekranı şimdilik çağırmaz (Meydan'da kullanılacak).
  - `GRASS_VARIANTS`, `OUTSIDE_ROW` ve karo kesim kodu silinir; süs/ağaç sayfası okuma kalır. Dosya başı açıklaması güncellenir.
- [ ] **Step 4:** field_test TAMAM. Ekran görüntüsü `grafik_9k/ara/ground.png` (`-- 22 notips`) ve `-- boss 6 notips`: zemin düz, motif seyrek, karo/kamuflaj yok. Gözle onay: ana oturum bakar.
- [ ] **Step 5:** Commit `gorsel: düz biyom zemini ve seyrek motif (9 Kings tarzı)`.

### GR3: Uzak kamera (spec G1)

**Files:** Modify `Fetih/scripts/battle/battle_camera.gd`, `Fetih/scripts/battle/battle_controller.gd` (`SQUAD_FRAME_PAD`), `Fetih/scripts/battle/battlefield.gd` (`_setup_camera` sınırı yapıları da kapsar: köşeler 3 karo dışarı).

- [ ] **Step 1:** `ZOOM_LEVELS := [0.75, 1.0, 1.5, 2.0]`, `_zoom_index` başlangıcı 1.0'ın sırası. `follow()` ilk yerleşimde (instant) bütün alanı (`bounds` + yapı payı) sığdıran en yakın seviyeyi seçer; savaşta `FIT_MARGIN := 80.0`, `KEEP_MARGIN := 30.0` (daha geç yakınlaşır). Takip sadece kutu ekranın yarısından küçükse 1.5'e çıkar: `if rect.size.x * level > screen.x * 0.5 and level > 1.0: continue` (1.0 üstü seviyeler için).
- [ ] **Step 2:** `SQUAD_FRAME_PAD := Vector2(24, 24)` (minik figür).
- [ ] **Step 3: Doğrula (Review Focus 5):** `battle_showcase -- 22 notips` 150. kare ve 600. kare: savaş başında iki ordu ve kenarlar görünür, sonunda yakınlık en fazla 1.5. Ekranlı açılışta (`& $G --path Fetih -s res://tools/battle_showcase.gd -- 22`) WASD, tekerlek, sağ tık sürükleme ve F çalışır (ana oturum dener).
- [ ] **Step 4:** Commit `gorsel: uzak kamera, savaş tek bakışta`.

### GR4: Minik birlik sanatı (spec G2, sanat)

**Files:** Create `Fetih/scripts/battle/unit_art/mini_unit_art.gd`; Modify `Fetih/scripts/battle/unit_sprites.gd`; Modify `Fetih/tools/sprite_preview.gd` (gerekirse); Modify `Fetih/tools/field_test.gd`.

**Interfaces:**
- Produces `class_name MiniUnitArt`: `const CELL := 16`, `const FRAMES: Array[int] = [2, 4, 3, 4]`, `static func sheet(unit: UnitData) -> Image` (4 satır x maks 4 sütun, 16x16 kareler, figür sağa bakar, ayak ortası `(8, 14)`).
- `UnitSprites._build(unit)`: `unit.is_boss` değilse `MiniUnitArt.sheet(unit)`; boss mevcut yol (dosya ya da `generate`). `assets/sprites/units/*.png` boss dışında okunmaz. `UnitSprites.icon` aynen çalışır.

- [ ] **Step 1: Test:**
```gdscript
func test_mini_art() -> void:
	for unit in UnitCatalog.all():
		if unit.is_boss:
			continue
		var img := MiniUnitArt.sheet(unit)
		check("%s boyut" % unit.id, img.get_height() == MiniUnitArt.CELL * 4)
		var used := img.get_region(Rect2i(0, 0, 16, 16)).get_used_rect()
		check("%s figür 8-13 px" % unit.id, used.size.y >= 8 and used.size.y <= 13 and used.size.x <= 14)
		var bad := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0 and SpritePalette.nearest(c) != Color(c, 1.0):
					bad += 1
		check("%s palet" % unit.id, bad == 0)
```
(`SpritePalette.nearest(c)` yoksa `SpritePalette` içindeki eşdeğer en yakın renk fonksiyonu kullanılır; adını dosyadan oku.)
- [ ] **Step 2:** Çalıştır, `MiniUnitArt` yok.
- [ ] **Step 3: Uygula `MiniUnitArt`** — her kare `Image.create_empty(16, 16, false, FORMAT_RGBA8)`; renkler:
  - Renkler: çerçeve `2e222f`; gövde takım rengi (oyuncu `f9c22b`, rakip `e83b3b`) ve onun bir ton koyusu (gölge yüzü); silah/şapka vurgusu `unit.placeholder_color` palete indirgenmiş; ten `fca790`, metal `c7dcd0`, ahşap `966c6c`.
  - İmza: `static func sheet(unit: UnitData, team_color: Color) -> Image` (Interfaces'teki tek argümanlı imzanın yerine bu geçerli). `UnitSprites.sheet_for(unit: UnitData, team := SquadState.Team.PLAYER)`; önbellek anahtarı `"%s_%d" % [unit.id, team]`; takım rengi `SquadView.TEAM_COLORS[team]`. Arayüz ikonları (`UnitSprites.icon`) oyuncu rengini kullanır.
  - Rol siluetleri (sağa bakan, 10-12 px boy, 1 px koyu çerçeve; çerçeve `_outline(img)` ile dolu piksellerin 4-komşu boş piksellerine çizilir):
    - piyade (melee/infantry): yuvarlak kask, gövde 4x5 takım rengi, sağda 1x4 kılıç (metal `c7dcd0`), solda 2x3 kalkan (vurgu rengi).
    - mızrakçı (spear): gövde aynı, sağda 1x9 dikey mızrak ucu üstte 1x2 metal.
    - okçu (ranged/archer): başlık (vurgu), solda yay (2x6 kahverengi `966c6c` yay çizgisi).
    - büyücü (mage): sivri şapka 3 px (vurgu), sağda asa 1x8 + üstte 2x2 parlak (`8fd3ff`).
    - atlı (cavalry): 12 px geniş at gövdesi (`966c6c`/vurgu) + üstte küçük binici takım renginde.
    - kuşatma (siege): 12x6 top namlusu (`625565`) + iki tekerlek (`4c3e24`), mürettebat yok; golemler için mancınık kolu.
    - tank: daha geniş 6x6 gövde, büyük kalkan 3x6 takım renginde.
    - Rol eşleşmesi `RoleRules` sabitleriyle (dosyadan oku: `RoleRules.CAVALRY`, `RoleRules.SIEGE`, `RoleRules.is_ranged_role`, birim `role` değerleri `data/units/*.tres` içinde).
  - Animasyon: durma 2 kare (gövde 1 px nefes), yürüme 4 kare (bacaklar ±1 px, gövde 0/-1 px), saldırı 3 kare (silah ileri 1-2 px / yay gerilir / asa parlar), ölüm 4 kare (1 px düşüş, sonra yatay 8x3 beden).
  - Sonda `SpritePalette.quantize(img)`.
- [ ] **Step 4:** field_test TAMAM. `& $G --headless --path Fetih -s res://tools/sprite_preview.gd -- "Fetih/tools/reports/grafik_9k/ara/mini_units.png"` (araç yeni sayfaları göstermiyorsa 4x büyüterek bütün birlikleri ızgaraya dizecek şekilde güncelle). Ana oturum gözle onaylar: her rol siluetten ayırt edilir.
- [ ] **Step 5:** Commit `gorsel: minik birlik sanatı (MiniUnitArt, rol siluetleri, takım rengi)`.

### GR5: Bölük görünümü (spec G2, görüntü)

**Files:** Modify `Fetih/scripts/battle/squad_view.gd`; Modify `Fetih/tools/field_test.gd`.

**Interfaces:** Produces `static SquadView.layout(count: int, frame_w: int) -> Array[Vector2]` (asker yerleri, karo cinsinden; x yana, y geriye).

- [ ] **Step 1: Test:**
```gdscript
func test_layout() -> void:
	for n in [1, 5, 12, 25, 48]:
		var slots := SquadView.layout(n, 12)
		var min_px := INF
		for i in slots.size():
			for j in range(i + 1, slots.size()):
				var d := Battlefield.field_offset_to_world(slots[i] - slots[j]).length()
				min_px = minf(min_px, d)
		check("%d asker çakışmasız (%.1f px)" % [n, min_px], n == 1 or min_px >= 12 * 0.7 - 0.5)
		var span := 0.0
		for s in slots:
			span = maxf(span, s.length())
		check("%d asker 1.6 karo içinde" % n, span <= 1.6)
```
- [ ] **Step 2:** Çalıştır, `layout` yok.
- [ ] **Step 3: Uygula:**
  - `layout(count, frame_w)`: sütun `ceili(sqrt(count * 1.6))`, satır `ceili(count / cols)`; aralık `spacing = frame_w * 0.75 / Battlefield.field_offset_to_world(Vector2(1, 0)).length()`; konumlar ortalanmış ızgara. 1.6 karoyu aşarsa aralık oranlanarak küçültülür (çakışma testine uyan en küçük `0.7`'ye kadar; 48 askerde sınır testini birlikte sağlayacak şekilde: gerekirse `span` sınırını 1.6 yerine figür sayısına göre `0.9 + 0.015 * n` yap ve testi buna eşitle).
  - `setup()`: `sheet = UnitSprites.sheet_for(squad.unit, squad.team)`; `_slots = layout(...)` (boss hariç).
  - Gölge: `DISC_ROWS` yerine figür başına `5x2` px `Color(0, 0, 0, 0.35)` (boss eski diski korur). `TEAM_COLORS` oyuncu `f9c22b` olur (spec G2).
  - Sancak (`_draw_banner`) yerine bölüğün en üst figürünün 4 px üstünde küçük sayı: `draw_string` ile `UiKit` fontu, boyut 8, takım renginde, 1 px koyu gölge. Sayı kaybında mevcut "pulse" davranışı aynen.
- [ ] **Step 4: Doğrula (Review Focus 1-3):** field_test TAMAM; ekran görüntüleri: `-- run 0 12 notips` (geç oyun, kalabalık), `-- boss 3 notips`, ayna maç için test modunda iki tarafın aynı birlik olduğu bir seed (`-- list` çıktısından seç). Ana oturum gözle onaylar.
- [ ] **Step 5:** Commit `gorsel: sık formasyon, küçük gölge ve sayı etiketi, altın oyuncu rengi`.

### GR6: Krallık yapıları (spec G3)

**Files:** Create `Fetih/scripts/battle/unit_art/building_art.gd`, `Fetih/scripts/battle/kingdom_camp.gd`; Modify `Fetih/scripts/battle/battlefield.gd` (`set_biome` yanına `set_camps(player_kingdom: StringName, enemy_kingdom: StringName)`), `Fetih/scripts/battle/battle_controller.gd` (koşu modunda `RunState.kingdom.id` ve rakip; test modunda `&"humans"`/`&"orcs"`), `Fetih/scripts/run/prep_screen.gd` dokunulmaz.

**Interfaces:**
- `BuildingArt.piece(kind: StringName, main: Color, accent: Color) -> Image` — kind: `&"wall"`, `&"tower"`, `&"tent"`, `&"banner"`, `&"fire"`, `&"signature_<krallık>"`; boyutlar 16-40 px, izometrik ön yüz + çatı, 1 px koyu çerçeve, palette indirgenmiş.
- `KingdomCamp.build(parent: Node2D, kingdom: KingdomData, team: SquadState.Team) -> Array[Sprite2D]` — oyuncu için alanın arka kenarının (y = FIELD_DEPTH .. FIELD_DEPTH + 3) arkasına, rakip için ayna (y = -1 .. -4) 5-7 parça; x boyunca dağıtılmış; deterministik (`hash(kingdom.id)`). Ateş ve imza yapının parlak kısmı ayrı `Sprite2D`, `create_tween().set_loops()` ile `modulate:a` 0.7-1.0 arası 1.2 sn.

- [ ] **Step 1: Test** (field_test):
```gdscript
func test_buildings() -> void:
	for k in KingdomCatalog.all():
		var img := BuildingArt.piece(StringName("signature_%s" % k.id), k.color, k.accent_color)
		check("%s imza yapı dolu" % k.id, img.get_used_rect().size.x >= 12)
	var tower := BuildingArt.piece(&"tower", Color("4d9be6"), Color("f9c22b"))
	check("kule çerçeveli", tower.get_pixel(tower.get_used_rect().position.x, tower.get_used_rect().get_center().y).v < 0.3)
```
- [ ] **Step 2:** Çalıştır, `BuildingArt` yok.
- [ ] **Step 3: Uygula** (spec G3 imza listesi). Ağaç yerleşimi (`GroundArt._plant_trees`) yapıların olduğu şeridi boş bırakır: `front` / `back` mesafesi 1-4 olan karolarda ağaç yok.
- [ ] **Step 4:** field_test TAMAM; ekran görüntüleri 3 farklı krallık eşleşmesi (`-- boss 0`, `-- boss 4`, `-- boss 8`). Gözle onay.
- [ ] **Step 5:** Commit `gorsel: krallık kamp ve kale yapıları`.

### GR7: Efekt ölçeği ve aura (spec G4)

**Files:** Modify `Fetih/scripts/battle/battle_fx.gd`, `Fetih/scripts/battle/squad_view.gd` (aura).

- [ ] **Step 1:** `battle_fx.gd` içindeki boyut sabitlerini oku; minik ölçeğe indir: vuruş kıvılcımı 3-5 px, ölüm tozu 4-6 parçacık 1-2 px, mermi 1 px çizgi + 2x2 parlak uç, büyü topu 3 px + `BLEND_MODE_ADD` parıltı, hasar sayısı boyut 8. Boss vuruşunda parıltı halkası additive.
- [ ] **Step 2:** Aura: `SquadView._draw_under` içinde, bölükte ferman etkisi varsa (SquadState'te bilgi yoksa `SquadView.aura_color: Color` alanı; `BattleController` koşu modunda `RunState.passives` içinden `applies_to` tutan bölüklere krallık rengini atar) bölük merkezinde yassı elips `Color(aura, 0.25)`.
- [ ] **Step 3: Doğrula (Review Focus 4):** `Settings` "vuruş flaşı" ve "sarsıntı" kapalıyken (`battle_showcase` gösterim profili ayarları; `settings_path` test dosyası) efektler sönük/kapalı; ekran görüntüsü normal ve kapalı.
- [ ] **Step 4:** Commit `gorsel: minik ölçek efektler, ferman aurası`.

### GR8: Arayüz teması (spec G5, font hariç)

**Files:** Modify `Fetih/scripts/ui/ui_kit.gd`.

- [ ] **Step 1:** `theme()`: `Panel`/`PanelContainer` stylebox: `bg COLOR_PANEL`, `border 1 px Color("625565")`, köşe 0, `shadow_size 2`, `shadow_color Color(0,0,0,0.5)`. `Button` normal/hover/pressed/disabled stylebox'ları aynı dil; hover kenarı `COLOR_GOLD`. `UiKit.panel()` aynı stylebox'ı kullanır.
- [ ] **Step 2:** Font kancası: `const FONT_PATH := "res://assets/fonts/pixel.ttf"`; dosya varsa `theme.default_font` = `FontFile` (antialiasing kapalı, `hinting NONE`, `subpixel_positioning DISABLED`), yoksa mevcut font (font indirme kullanıcı onayı bekliyor; bkz. GR11).
- [ ] **Step 3:** Ekran görüntüleri: prep, cards, kingdom_select, settings (tema hepsine yansır). Gözle onay.
- [ ] **Step 4:** Commit `arayuz: 9 Kings tarzı panel ve düğme teması`.

### GR9: Oyun içi düzen: üst şerit, kartlar, sonuç paneli (spec G5)

**Files:** Modify `Fetih/scripts/battle/battle_controller.gd` (+ `battle.tscn` HUD konumları), `Fetih/scripts/ui/card_select.gd`, `Fetih/scripts/run/prep_screen.gd` (sadece üst şerit), `Fetih/scripts/ui/ui_kit.gd` (`card_frame(kind)`).

- [ ] **Step 1:** Savaş HUD: sol üst "Savaş n/20 · Rakip" küçük etiket, sağ üst hız + duraklat (mevcut), alt şerit inceltilir (yükseklik 22 px). Sonuç paneli `UiKit.panel` diliyle.
- [ ] **Step 2:** Kartlar: `UiKit.card_frame(kind: CardOffer.Kind, kingdom: KingdomData) -> PanelContainer` — kenar 2 px tür rengi (birlik: `kingdom.color`, yükseltme: `COLOR_GOLD`, ferman: `Color("a884f3")`), üst yarıda büyük resim (birlik: `unit_icon(unit, 4)`; yükseltme: türüne göre 16x16 koddan ikon büyütülmüş; ferman: krallık rengi mühür ikonu), altta ad ve metin. `card_select.gd` kartları bunu kullanır; davranış ve metinler aynı.
- [ ] **Step 3:** Hazırlık ekranı üst şeridi aynı dil (sol savaş/can, sağ krallık). Izgara ve rakip sütunu aynı kalır (Meydan'da değişecek).
- [ ] **Step 4:** Ekran görüntüleri (prep, cards, battle, result). `update_translations.gd` (yeni metin varsa). Commit `arayuz: savaş HUD, tür çerçeveli kartlar, sonuç paneli`.

### GR10: Kapanış

- [ ] Simülasyon testleri: run/boss/upgrade/save çıktıları `base_*` ile aynı.
- [ ] `perf_test.gd -- only=battle5,boss secs=4` (ekranlı): ortalama FPS önceki rapora göre düşmedi (düştüyse en pahalı çizimi bul: `systematic-debugging`).
- [ ] "Sonra" ekran görüntüleri `Fetih/tools/reports/grafik_9k/sonra/` + `README.md` (önce/sonra, 9 Kings karşılaştırma notu); İngilizce bir görüntü.
- [ ] `CLAUDE.md` Teknik bölümü: minik birlik sanatı (`MiniUnitArt`), `KingdomCamp`/`BuildingArt`, düz zemin, ayna kamera, `field_test.gd`; eski "Hazır sprite'lar ... import_sprites" satırı "sadece boss" diye güncellenir.
- [ ] Commit `docs: grafik devrimi raporu ve CLAUDE.md`.

### GR11: Piksel yazı tipi (KULLANICI ONAYI BEKLER)

Font dosyası internetten indirilecek (dış dosya indirme = kullanıcı onayı). Onay gelince: Pixel Operator (CC0) ya da monogram-extended (CC0) indir, `Fetih/assets/fonts/pixel.ttf`, lisans `kaynak_assetler/LISANSLAR.md`. `Fetih/tools/font_test.gd`: `for ch in "ĞğİıŞşÇçÖöÜü": check(ch, font.has_char(ch.unicode_at(0)))`. Font boyutları tasarım boyutunun katlarına yuvarlanır (`UiKit.FONT_SIZE` ve bütün `label(..., size)` çağrıları gözden geçirilir). Ekran görüntüleri, commit.
