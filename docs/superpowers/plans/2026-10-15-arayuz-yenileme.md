# Arayüz yenileme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fetih'e animasyonlu ana menü, görsel krallık seçimi, sade ve koyu şık Meydan arayüzü, krallık başına manzara ve modern düz yazı tipi getirmek (sürüm 0.13.0).

**Architecture:** `UiKit` iki tema (`theme_menu` renkli fantastik, `theme_game` koyu şık), iki font (Cinzel başlık, Nunito metin) ve ortak animasyon yardımcıları sunar. Yeni görsel parçalar küçük, tek görevli `Control`/`RefCounted` sınıflarıdır (`MenuBackdrop`, `KingdomBanner`, `KingdomDiorama`, `RunProgress`, `LivesHearts`, `BannerArt`, `TerrainProps`). Simülasyona dokunulmaz; her şey görüntü katmanı.

**Tech Stack:** Godot 4.7.2 (GDScript, Compatibility renderer), Tween, `_draw`, `Image` ile koddan piksel çizim (Resurrect 64 paleti), FontFile + FontVariation (değişken font `wght` ekseni).

**Spec:** `docs/superpowers/specs/2026-10-15-arayuz-yenileme-design.md`

## Global Constraints

- Motor Godot 4.7.2, dil GDScript; API şüphesinde context7 `/godotengine/godot-docs` (4.7).
- Godot: `C:\Users\Samet PC\Desktop\Godot_v4.7.2-stable_win64.exe` (aşağıda `$G`). Testler: `"$G" --headless --path Fetih -s res://tools/<test>.gd`, çıkış kodu 0 = geçti.
- Fontlar: başlık **Cinzel** (`assets/fonts/Cinzel.ttf`, wght 400–900), metin **Nunito** (`assets/fonts/Nunito.ttf`, wght 200–1000), ikisi OFL; lisans dosyaları yanında, `LISANSLAR.md`'ye yazılır.
- UI metinleri `tr()` (statikte `UiKit.t()`); Türkçe metin `to_upper()` ile büyütülmez (İ/ı bozulur), büyük harf metin olarak yazılır.
- Sahne (birlik, zemin, ağaç, süs, sancak) Nearest filtre ve palet içi kalır; `import_sprites.gd`/`build_ground.gd` ve yeni koddan çizimler `SpritePalette` dışına çıkmaz.
- Savaş deterministik; görüntü kodu `BattleSimulation`'a dokunmaz, seed'li `RandomNumberGenerator` ya da `hash()` kullanır.
- Testler ve araçlar oyuncunun gerçek `user://save.json` / `user://settings.cfg` dosyalarına yazmaz (gösterim/test yolları, `Profile.is_tool_run`).
- Araç scriptleri autoload adlarını derleme anında tanımaz: araç zincirindeki scriptler autoload'a `get_node`, UI sınıflarına `load()` ile erişir.
- Her görev sonunda: ilgili testler + `field_test`, `meydan_test`, `card_fit_test`, `font_test` geçer; commit + `git push origin main` (özel repo).
- Commit mesajları Türkçe, sonunda `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **İngilizce metin taşması:** düz font + EN çeviriler kart/düğme/sancak etiketlerinde taşmamalı → Task 7 `card_fit_test` EN dilinde de koşar, Task 10 `menu_test` sancak etiketi genişliğini ölçer.
2. **Pencere boyutu değişimi:** 1280x720 ve 2560x1440'ta menü manzarası, sancaklar ve Meydan HUD'u boşluk/taşma yapmamalı → Task 8 ve Task 10'da iki boyutta ekran görüntüsü + `MenuBackdrop` `size` değişince yeniden çizim testi.
3. **Yarım koşu varken "Yeni oyun":** onay verilmeden kayıt silinmemeli; iptal edilince "Devam et" durmalı → Task 9 `menu_test`.
4. **Kilitli krallık klavyeyle seçilince:** "Başla" devre dışı, Enter koşu başlatmamalı → Task 10 `menu_test`.
5. **Efektler kapalı (ekran sarsıntısı/flaş kapalı):** logo açılışı ve kalp kırılması kısa/yumuşak sürmeli, tık/tuş açılışı her an geçmeli → Task 9 `menu_test` (`skip_intro`), Task 5 `meydan_test`.

---

### Task 1: Fontlar ve UiKit yazı API'si (UI1a)

**Files:**
- Create: `Fetih/assets/fonts/Cinzel.ttf`, `Fetih/assets/fonts/Cinzel_OFL.txt`, `Fetih/assets/fonts/Nunito.ttf`, `Fetih/assets/fonts/Nunito_OFL.txt` (indirildi: scratchpad `fonts_dl/`)
- Modify: `Fetih/scripts/ui/ui_kit.gd` (FONT_* sabitleri, `theme`, `pixel_font`, `font_spec`, `set_font_size`, `label`)
- Modify: `Fetih/scripts/battle/battle_fx.gd:560`, `Fetih/scripts/battle/squad_view.gd:440`, `Fetih/scripts/ui/run_map.gd:19` (`pixel_font` → `ui_font`)
- Modify: `kaynak_assetler/LISANSLAR.md` (Cinzel, Nunito OFL satırı)
- Rewrite: `Fetih/tools/font_test.gd`

**Interfaces:**
- Produces: `UiKit.ui_font(weight := 500) -> Font` (Nunito, `FontVariation` `wght`), `UiKit.heading_font(weight := 700) -> Font` (Cinzel), `UiKit.label(text, size := FONT_SIZE, color := COLOR_TEXT, heading := false) -> Label`, `UiKit.set_font_size(control, size, heading := false)`. `UiKit.pixel_font` ve `UiKit.font_spec` silinir.

- [ ] **Step 1: font_test'i yeni fonta göre yaz (başarısız olmalı)**

```gdscript
extends SceneTree
## Arayüz yazı tiplerinde (Cinzel başlık, Nunito metin) Türkçe ve arayüz karakterleri var mı;
## UiKit yazı API'si doğru fontu ve ağırlığı veriyor mu.
## Çalıştırma: godot --headless --path Fetih -s res://tools/font_test.gd

const FONTS := ["res://assets/fonts/Cinzel.ttf", "res://assets/fonts/Nunito.ttf"]
const CHARS := "ĞğİıŞşÇçÖöÜüÂâÎîÛû·•%-"

var failures := 0


func check(name: String, ok: bool) -> void:
	print("%s  %s" % ["TAMAM " if ok else "HATA  ", name])
	if not ok:
		failures += 1


func _initialize() -> void:
	for path in FONTS:
		var font: FontFile = load(path)
		check("%s yüklendi" % path.get_file(), font != null)
		if font == null:
			continue
		var missing := ""
		for i in CHARS.length():
			if not font.has_char(CHARS.unicode_at(i)):
				missing += CHARS[i]
		check("%s eksik: [%s]" % [path.get_file(), missing], missing == "")
	var kit: GDScript = load("res://scripts/ui/ui_kit.gd")
	var body: Font = kit.ui_font(700)
	check("ui_font FontVariation", body is FontVariation)
	check("ui_font Nunito", (body as FontVariation).base_font.resource_path.ends_with("Nunito.ttf"))
	check("ui_font ağırlık 700", (body as FontVariation).variation_opentype.get(TextServerManager.get_primary_interface().name_to_tag("wght")) == 700)
	var head: Font = kit.heading_font()
	check("heading_font Cinzel", (head as FontVariation).base_font.resource_path.ends_with("Cinzel.ttf"))
	var l: Label = kit.label("Fetih", 14, Color.WHITE, true)
	check("label başlık fontu", l.get_theme_font("font") == head)
	check("label boyutu aynen", l.get_theme_font_size("font_size") == 14)
	l.free()
	print("Hata: %d" % failures)
	quit(1 if failures > 0 else 0)
```

- [ ] **Step 2: Çalıştır, HATA görmeli**

Run: `"$G" --headless --path Fetih -s res://tools/font_test.gd`
Expected: `Cinzel.ttf yüklendi` HATA (dosya yok), çıkış 1.

- [ ] **Step 3: Fontları kopyala, içe aktar**

```bash
S="C:/Users/SAMETP~1/AppData/Local/Temp/claude/C--Users-Samet-PC-Desktop-claude-2B-oyunprojesi/7b043256-5732-453e-b50d-313809d637ae/scratchpad/fonts_dl"
cp "$S"/Cinzel.ttf "$S"/Cinzel_OFL.txt "$S"/Nunito.ttf "$S"/Nunito_OFL.txt Fetih/assets/fonts/
"$G" --headless --path Fetih --import
```

- [ ] **Step 4: UiKit yazı API'sini değiştir**

`ui_kit.gd` başındaki piksel font sabitleri ve fonksiyonları şununla değişir:

```gdscript
## Arayüz yazı tipleri (OFL, Google Fonts): Cinzel başlık (fantastik büyük harf), Nunito metin.
## İkisi değişken font (wght ekseni): aynı dosyadan FontVariation ile kalınlık türetilir.
## Godot: stretch canvas_items metni pencere çözünürlüğünde çizer; kenar yumuşatma açık, hafif hinting.
const FONT_BODY_PATH := "res://assets/fonts/Nunito.ttf"
const FONT_HEADING_PATH := "res://assets/fonts/Cinzel.ttf"

static var _fonts := {}  ## "yol|ağırlık" -> Font


static func ui_font(weight := 500) -> Font:
	return _font(FONT_BODY_PATH, weight)


static func heading_font(weight := 700) -> Font:
	return _font(FONT_HEADING_PATH, weight)


static func _font(path: String, weight: int) -> Font:
	var key := "%s|%d" % [path, weight]
	if not _fonts.has(key):
		if not ResourceLoader.exists(path):
			_fonts[key] = ThemeDB.fallback_font
		else:
			var file: FontFile = load(path)
			file.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			file.hinting = TextServer.HINTING_LIGHT
			var v := FontVariation.new()
			v.base_font = file
			v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
			_fonts[key] = v
	return _fonts[key]


static func set_font_size(control: Control, size: int, heading := false) -> void:
	control.add_theme_font_override("font", heading_font() if heading else ui_font())
	control.add_theme_font_size_override("font_size", size)


static func label(text: String, size := FONT_SIZE, color := COLOR_TEXT, heading := false) -> Label:
	var l := Label.new()
	l.text = text
	set_font_size(l, size, heading)
	l.add_theme_color_override("font_color", color)
	return l
```

`theme()` içinde `font_spec` satırları: `_theme.default_font = ui_font()`, `_theme.default_font_size = FONT_SIZE`. `wrapped`/`centered` imzaları değişmez. `battle_fx.gd:560`, `squad_view.gd:440`, `run_map.gd:19`: `UiKit.pixel_font(true)` → `UiKit.ui_font(700)`.

- [ ] **Step 5: Testler**

Run: `font_test.gd`, `card_fit_test.gd`, `meydan_test.gd`, `field_test.gd` → hepsi çıkış 0. Ekran: `"$G" --path Fetih --write-movie <scratch>/f.png --quit-after 60 -s res://tools/battle_showcase.gd -- meydan prep 2 3 notips`; son kareye bak: yazılar düz font, net.

- [ ] **Step 6: Commit**

```bash
git add Fetih/assets/fonts Fetih/scripts Fetih/tools/font_test.gd kaynak_assetler/LISANSLAR.md
git commit -m "arayuz: Cinzel + Nunito yazı tipleri (OFL), piksel font kalktı"
git push origin main
```

---

### Task 2: İki tema, düğme türleri, animasyon yardımcıları (UI1b)

**Files:**
- Modify: `Fetih/scripts/ui/ui_kit.gd`
- Create: `Fetih/tools/ui_test.gd`

**Interfaces:**
- Consumes: `UiKit.ui_font`, `UiKit.heading_font` (Task 1).
- Produces:
  - Renk sabitleri: `COLOR_SKY := Color("1e2a4a")`, `COLOR_PARCHMENT := Color("f2e3c0")`, `COLOR_INK := Color("3b2a1e")`, `COLOR_GAME_PANEL := Color(0.07, 0.08, 0.10, 0.82)`.
  - `UiKit.theme_menu() -> Theme`, `UiKit.theme_game() -> Theme`, `UiKit.theme() -> Theme` (= `theme_game()`).
  - `UiKit.button_primary(text, on_pressed) -> Button`, `UiKit.button_ghost(text, on_pressed) -> Button`, `UiKit.button(text, on_pressed) -> Button` (aynı).
  - `UiKit.game_panel(alpha := 0.82) -> PanelContainer`, `UiKit.menu_panel() -> PanelContainer`.
  - `UiKit.fade_in(node: CanvasItem, delay := 0.0, time := 0.25) -> Tween`, `UiKit.slide_in(control: Control, from: Vector2, delay := 0.0, time := 0.3) -> Tween`, `UiKit.pop(control: Control, time := 0.2) -> Tween`, `UiKit.anim_scale() -> float` (efektler kapalıysa 0.5, açıksa 1.0; `Settings.screen_shake` ve `flash_effects` ikisi kapalıysa 0.5).
  - `UiKit.screen_root(screen, margin := 10, menu := false)`: `menu` true ise `theme_menu()` ve arka plan yok (ekran kendi `MenuBackdrop`'unu koyar).

- [ ] **Step 1: ui_test yaz (başarısız)**

```gdscript
extends SceneTree
## UiKit temaları, düğme türleri ve animasyon yardımcıları.
## Çalıştırma: godot --headless --path Fetih -s res://tools/ui_test.gd

var failures := 0


func check(name: String, ok: bool) -> void:
	print("%s  %s" % ["TAMAM " if ok else "HATA  ", name])
	if not ok:
		failures += 1


func _initialize() -> void:
	var kit: GDScript = load("res://scripts/ui/ui_kit.gd")
	var menu: Theme = kit.theme_menu()
	var game: Theme = kit.theme_game()
	check("iki ayrı tema", menu != game)
	check("theme() = oyun teması", kit.theme() == game)
	for t: Theme in [menu, game]:
		check("düğme odak stili tek tip", t.get_stylebox("focus", "Button") == t.get_stylebox("focus", "CheckButton"))
		check("sürgü teması var", t.has_stylebox("slider", "HSlider"))
		var box := t.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
		check("panel köşesi yuvarlak", box.corner_radius_top_left >= 4)
	var p: Button = kit.button_primary("Başla", func() -> void: pass)
	var g: Button = kit.button_ghost("Geç", func() -> void: pass)
	check("birincil düğme dolgulu", (p.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.a > 0.9)
	check("hayalet düğme saydam", (g.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.a < 0.2)
	var c := Control.new()
	root.add_child(c)
	var tw: Tween = kit.pop(c)
	check("pop tween döner", tw != null and tw.is_valid())
	await tw.finished
	check("pop sonunda ölçek 1", c.scale.is_equal_approx(Vector2.ONE))
	c.queue_free()
	p.free()
	g.free()
	print("Hata: %d" % failures)
	quit(1 if failures > 0 else 0)
```

- [ ] **Step 2: Çalıştır, HATA görmeli** (`theme_menu` yok → derleme hatası, çıkış ≠ 0).

- [ ] **Step 3: Uygula**

Temalar ortak bir kurucu ile:

```gdscript
static var _theme_menu: Theme
static var _theme_game: Theme


static func theme() -> Theme:
	return theme_game()


## Koyu şık: %82 saydam koyu panel, 1 px ince altın kenar, 4 px köşe, yumuşak gölge.
static func theme_game() -> Theme:
	if _theme_game == null:
		_theme_game = _build_theme(COLOR_GAME_PANEL, Color(COLOR_GOLD, 0.55), 1, 4, COLOR_TEXT)
	return _theme_game


## Renkli fantastik: parşömen panel, 2 px altın kenar, 8 px köşe, koyu mürekkep yazı.
static func theme_menu() -> Theme:
	if _theme_menu == null:
		_theme_menu = _build_theme(COLOR_PARCHMENT, COLOR_GOLD, 2, 8, COLOR_INK)
	return _theme_menu


static func _build_theme(panel: Color, edge: Color, border: int, radius: int, text: Color) -> Theme:
	var t := Theme.new()
	t.default_font = ui_font()
	t.default_font_size = FONT_SIZE
	var box := _box(panel, edge, border, radius, 8)
	t.set_stylebox("panel", "PanelContainer", box)
	t.set_stylebox("panel", "Panel", box)
	t.set_stylebox("panel", "TooltipPanel", _box(Color(0.05, 0.05, 0.07, 0.95), Color(COLOR_GOLD, 0.6), 1, 4, 4))
	t.set_color("font_color", "Label", text)
	t.set_color("font_color", "TooltipLabel", COLOR_TEXT)
	var focus := _box(Color(0, 0, 0, 0), COLOR_GOLD, 1, radius, 0)
	for type in ["Button", "CheckButton", "OptionButton", "HSlider", "TabBar"]:
		t.set_stylebox("focus", type, focus)
	t.set_stylebox("normal", "Button", _box(panel.darkened(0.15), edge, border, radius, 6))
	t.set_stylebox("hover", "Button", _box(panel.lightened(0.08), COLOR_GOLD, border, radius, 6))
	t.set_stylebox("pressed", "Button", _box(panel.darkened(0.3), COLOR_GOLD, border, radius, 6))
	t.set_stylebox("disabled", "Button", _box(panel.darkened(0.4), edge.darkened(0.5), border, radius, 6))
	t.set_color("font_color", "Button", text)
	t.set_color("font_hover_color", "Button", COLOR_GOLD if text == COLOR_TEXT else COLOR_INK.darkened(0.3))
	t.set_color("font_disabled_color", "Button", COLOR_MUTED)
	t.set_stylebox("slider", "HSlider", _box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 3, 2))
	t.set_stylebox("grabber_area", "HSlider", _box(COLOR_GOLD, Color(0, 0, 0, 0), 0, 3, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(COLOR_GOLD.lightened(0.2), Color(0, 0, 0, 0), 0, 3, 2))
	return t


static func _box(bg: Color, edge: Color, border: int, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 2)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s
```

`button_primary`: `button()` + `add_theme_stylebox_override("normal", _box(COLOR_GOLD, COLOR_GOLD.lightened(0.3), 2, 6, 8))` (hover/pressed açık/koyu tonları), font `ui_font(800)`, boyut 13, yazı `COLOR_INK`. `button_ghost`: normal `_box(Color(1,1,1,0.06), Color(COLOR_GOLD,0.5), 1, 6, 6)`. `button()` artık `focus_mode = FOCUS_ALL` (klavye), fare tıkında `release_focus()`; hover'da `hover_scale` + `self_modulate` 1.15 parlama.
Animasyonlar:

```gdscript
static func anim_scale() -> float:
	var settings := (Engine.get_main_loop() as SceneTree).root.get_node_or_null(^"Settings")
	if settings and not settings.screen_shake and not settings.flash_effects:
		return 0.5
	return 1.0


static func fade_in(node: CanvasItem, delay := 0.0, time := 0.25) -> Tween:
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_interval(delay * anim_scale())
	tw.tween_property(node, "modulate:a", 1.0, time * anim_scale())
	return tw


static func slide_in(control: Control, from: Vector2, delay := 0.0, time := 0.3) -> Tween:
	var target := control.position
	control.position = target + from
	var tw := fade_in(control, delay, time)
	tw.parallel().tween_property(control, "position", target, time * anim_scale()) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tw


static func pop(control: Control, time := 0.2) -> Tween:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2.ONE * 0.85
	var tw := control.create_tween()
	tw.tween_property(control, "scale", Vector2.ONE, time * anim_scale()) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw
```

`slide_in` kapsayıcı (Box/Grid) içindeki düğümde konumu kapsayıcı ezer: sadece serbest konumlu düğümlerde kullanılır; kapsayıcı içindekiler için `fade_in`.
`panel()` → `game_panel()` takma adı kalır (eski çağrılar oyun temasını alır).

- [ ] **Step 4: Testler** — `ui_test`, `font_test`, `card_fit_test`, `meydan_test` → 0.
- [ ] **Step 5: Commit** — `arayuz: iki tema (menü/oyun), düğme türleri, animasyon yardımcıları` + push.

---

### Task 3: Kamp kalkar, ordu sancağı (UI7a)

**Files:**
- Create: `Fetih/scripts/battle/unit_art/banner_art.gd` (`class_name BannerArt`)
- Modify: `Fetih/scripts/battle/battlefield.gd` (`_camps`→`_banners`, `set_camps`→`set_banners`, `camps_rect`→`banners_rect`, `_setup_camera` pad 3→2)
- Modify: `Fetih/scripts/battle/battle_runner.gd:97`, `Fetih/scripts/battle/battle_controller.gd:84`, `Fetih/scripts/run/run_field.gd:10`
- Modify: `Fetih/scripts/battle/ground_art.gd` (`tree_allowed` yapı şeridi 4→2 karo, yorum)
- Delete: `Fetih/scripts/battle/kingdom_camp.gd`, `Fetih/scripts/battle/unit_art/building_art.gd` (+ `.uid`)
- Modify: `Fetih/tools/field_test.gd` (`test_buildings` → `test_banners`)

**Interfaces:**
- Produces: `BannerArt.frames(kingdom: KingdomData) -> Array[Image]` (3 dalga karesi, 24x40 tuval, `ANCHOR := Vector2i(4, 39)` direk dibi), `BannerArt.emblem(image: Image, kingdom_id: StringName, origin: Vector2i, color: Color)` (Task 10 da kullanır), `BannerArt.texture(kingdom, frame) -> Texture2D` (önbellekli). `Battlefield.set_banners(player: KingdomData, enemy: KingdomData)`, `Battlefield.banners_rect() -> Rect2`. Sancak düğümü `AnimatedSprite2D` (SpriteFrames, 4 fps).
- Amblem tablosu (`BannerArt.EMBLEMS`): humans taç, elves yaprak, orcs balta, dwarves çekiç, undead kafatası, demons boynuz, slimes damla, mud dalga, golems kristal, centaurs at nalı. Her biri 7x7 piksel maske (`PackedStringArray`, `#` dolu).

- [ ] **Step 1: field_test'te kamp testini sancak testiyle değiştir (başarısız)**

```gdscript
func test_banners() -> void:
	for k in KingdomCatalog.all():
		var frames := BannerArt.frames(k)
		check("%s sancak 3 kare" % k.id, frames.size() == 3)
		check("%s sancak dolu" % k.id, frames[0].get_used_rect().size.y >= 30)
		check("%s sancak palette" % k.id, SpritePalette.off_palette_count(frames[0], Color(-1, -1, -1)) == 0)
		check("%s kareler farklı (dalga)" % k.id, frames[0].get_data() != frames[1].get_data())
	var d := Battlefield.FIELD_DEPTH
	check("ağaç sancak arkasında yok", not GroundArt.tree_allowed(Vector2i(4, d + 1)))
	check("ağaç rakip sancağında yok", not GroundArt.tree_allowed(Vector2i(4, -2)))
	check("ağaç alanın içinde yok", not GroundArt.tree_allowed(Vector2i(4, 8)))
	var scene: PackedScene = load("res://scenes/battle/battlefield.tscn")
	var field: Battlefield = scene.instantiate()
	root.add_child(field)
	var humans := KingdomCatalog.get_kingdom(&"humans")
	field.set_banners(humans, KingdomCatalog.get_kingdom(&"orcs"))
	var rect := field.banners_rect()
	check("iki sancak kutusu", rect.has_area())
	field.set_banners(humans, null)
	check("yeniden kurunca eski silinir (tek sancak)", field.banners_rect().size.x < rect.size.x)
	field.queue_free()
```

`_initialize` içinde `test_buildings()` → `test_banners()`.

- [ ] **Step 2: Çalıştır** → `BannerArt` yok, HATA.

- [ ] **Step 3: `banner_art.gd` yaz**

Tuval 24x40: direk x=4 (2 px, `694f62` koyu kahve + `9babb2` uç topuz y=0..1), bez x=6..21, y=3..22: `kingdom.color` dolgu, alt kenarda 2 px `accent_color` saçak, ortada amblem (`accent_color`, 1 px koyu kontur yok, `_add_outline` benzeri). Dalga: kare `f` için her bez sütunu `x` dikeyde `roundi(sin((x - 6) * 0.45 + f * TAU / 3.0) * 1.5)` kaydırılır. Renkler `SpritePalette.nearest()` ile palete oturtulur. `_add_outline(image, Color("2e222f"))` kenar.

- [ ] **Step 4: Battlefield ve çağıranlar**

```gdscript
var _banners: Array[Node2D] = []  ## Ordu sancakları (BannerArt), set_banners yeniler.


## Her ordunun arkasında, arka kenarın ortasında kendi renginde tek sancak (sadece görüntü).
func set_banners(player_kingdom: KingdomData, enemy_kingdom: KingdomData) -> void:
	for b in _banners:
		b.queue_free()
	_banners.clear()
	if player_kingdom != null:
		_banners.append(_add_banner(player_kingdom, Vector2((FIELD_WIDTH - 1) / 2.0, FIELD_DEPTH + 0.6)))
	if enemy_kingdom != null:
		_banners.append(_add_banner(enemy_kingdom, Vector2((FIELD_WIDTH - 1) / 2.0, -1.6)))


func _add_banner(kingdom: KingdomData, field_pos: Vector2) -> Node2D:
	var sprite := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 4.0)
	for i in 3:
		frames.add_frame(&"default", BannerArt.texture(kingdom, i))
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = -Vector2(BannerArt.ANCHOR)
	sprite.position = field_to_world(field_pos).round()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	units.add_child(sprite)
	sprite.play()
	return sprite


func banners_rect() -> Rect2:
	var rect := Rect2()
	for i in _banners.size():
		var box := Rect2(_banners[i].position - Vector2(BannerArt.ANCHOR), Vector2(BannerArt.SIZE))
		rect = box if i == 0 else rect.merge(box)
	return rect
```

`battle_runner.gd:97` `camps_rect` → `banners_rect`, yorum güncellenir. `run_field.gd:10` ve `battle_controller.gd:84` `set_camps` → `set_banners`. `RunField` sınıf yorumu: "krallık kampları" → "ordu sancakları". `tree_allowed` yapı şeridi: `cell.x >= 2 and cell.x <= w - 3` ve `(cell.y >= d and cell.y <= d + 1) or (cell.y <= -1 and cell.y >= -2)` (sadece sancak çevresi). `_setup_camera` `pad := 2.0`, yorum "ordu sancakları".
Sil: `git rm Fetih/scripts/battle/kingdom_camp.gd* Fetih/scripts/battle/unit_art/building_art.gd*`.

- [ ] **Step 5: Testler** — `--import` (sınıf önbelleği), `field_test`, `meydan_test` → 0. Ekran: `-- meydan prep 0 0 notips` ve `-- meydan battle 2 3 notips`: evler yok, iki sancak dalgalanıyor.
- [ ] **Step 6: Commit** — `gorsel: kamp evleri kalktı, her ordunun arkasında dalgalanan krallık sancağı` + push.

---

### Task 4: Krallık manzara süsleri (UI7b)

**Files:**
- Create: `Fetih/scripts/battle/unit_art/terrain_props.gd` (`class_name TerrainProps`)
- Modify: `Fetih/scripts/battle/ground_art.gd` (`BIOMES[*].props`, `_plant_props`, nefes alan parıltı)
- Modify: `Fetih/tools/field_test.gd` (`test_props`)

**Interfaces:**
- Produces: `TerrainProps.KINDS: Dictionary` (kind → {size: Vector2i, glow: bool}), `TerrainProps.image(kind: StringName, variant: int) -> Image` (palet içi, şeffaf zemin, alt orta = yere değen nokta), `TerrainProps.glow_image(kind, variant) -> Image` (sadece `glow` türlerinde parlak kısım), `TerrainProps.texture(kind, variant, glow := false) -> Texture2D` (önbellek). `GroundArt.prop_allowed(cell: Vector2i) -> bool` (static; ağaç kuralı + yerleşim bölgesi ve alan içi yasak). `GroundArt.props_of(biome_id) -> Array[StringName]`.
- Süs türleri ve krallıkları (`BIOMES[id].props`):
  - humans: `&"wheat"`, `&"fence"`, `&"hay"` · elves: `&"giant_tree"`, `&"mushroom"`, `&"firefly"`(glow)
  - orcs: `&"bones"`, `&"spikes"`, `&"dry_bush"` · dwarves: `&"rock"`, `&"minecart"`, `&"crystal_vein"`(glow)
  - undead: `&"tombstone"`, `&"dead_tree"`, `&"fog"` · demons: `&"lava_crack"`(glow), `&"obsidian"`, `&"bones"`
  - slimes: `&"pond"`, `&"bubble"`(glow) · mud: `&"puddle"`, `&"reeds"`
  - golems: `&"crystal"`(glow), `&"ruin_pillar"` · centaurs: `&"savanna_grass"`, `&"acacia"`
  - default: `&"rock"`, `&"dry_bush"`

- [ ] **Step 1: test_props yaz (başarısız)**

```gdscript
func test_props() -> void:
	for id in GroundArt.BIOMES:
		var kinds := GroundArt.props_of(id)
		check("%s en az 2 süs türü" % id, kinds.size() >= 2)
		for kind in kinds:
			var img := TerrainProps.image(kind, 0)
			var used := img.get_used_rect()
			check("%s/%s dolu" % [id, kind], used.size.x >= 4 and used.size.y >= 3)
			check("%s/%s palette" % [id, kind], SpritePalette.off_palette_count(img, Color(-1, -1, -1)) == 0)
			if TerrainProps.KINDS[kind].glow:
				check("%s/%s parıltı resmi" % [id, kind], TerrainProps.glow_image(kind, 0).get_used_rect().has_area())
	var d := Battlefield.FIELD_DEPTH
	check("süs alan içinde yok", not GroundArt.prop_allowed(Vector2i(5, 8)))
	check("süs oyuncu yerleşiminde yok", not GroundArt.prop_allowed(Vector2i(5, d - 2)))
	check("süs sancak yerinde yok", not GroundArt.prop_allowed(Vector2i(4, d)))
	check("süs uzak kenarda olabilir", GroundArt.prop_allowed(Vector2i(-6, 8)))
	check("süs çizimi deterministik", TerrainProps.image(&"tombstone", 1).get_data() == TerrainProps.image(&"tombstone", 1).get_data())
```

- [ ] **Step 2: Çalıştır** → HATA.

- [ ] **Step 3: `terrain_props.gd`**: her tür için küçük `_draw_<kind>(img, rng)` fonksiyonu (8–32 px, `RandomNumberGenerator.seed = hash([kind, variant])`), renkler sabit Resurrect 64 hex'leri (ör. mezar `9babb2`/`625565`, lav `f9c22b`/`fb6b1d`/`e83b3b`, kristal `4d9be6`/`8fd3ff`, gölcük `0eaf9b`/`30e1b9`, buğday `f9c22b`/`ab947a`, mantar `e83b3b`/`f2e3c0` vb.), her resim `_add_outline(img, Color("2e222f"))` (fog, firefly, lava_crack hariç: kontursuz). 3 varyant.
- [ ] **Step 4: GroundArt**: `BIOMES` her girdisine `props = [...]` (listeyi yukarıdan). `_plant_props(parent)`: `_plant_trees` ile aynı kaba hücre döngüsü, ayrı seed tuzu (`_cell_rng(cell, 7)`), hücre başına `PROP_CHANCE := 0.45`, 1–3 süs; `prop_allowed` geçen karoya `Sprite2D` (Nearest, tam piksel, `y_sort` için `units`'e). `glow` türünde çocuk `Sprite2D` (`glow_image`) `modulate:a` 0.55↔1.0 sonsuz Tween (1.4 sn; `firefly` ayrıca 2 px yukarı-aşağı süzülür). `fog` ve `lava_crack` zemin hizasında: `z_index = -1` (birliklerin altında), `y_sort` dışı `self` çocuğu. Yeniden kurulumda `_props` temizlenir (`setup` → `_clear_props`).

```gdscript
static func prop_allowed(cell: Vector2i) -> bool:
	var w := Battlefield.FIELD_WIDTH
	var d := Battlefield.FIELD_DEPTH
	if cell.x >= -1 and cell.x <= w and cell.y >= -1 and cell.y <= d:
		return false  # alan + 1 karo kenar: bölükler ve sancaklar serbest
	return tree_allowed(cell) or (absi(cell.x - w / 2) > w / 2 + 2)
```

- [ ] **Step 5: Testler** — `--import`, `field_test`, `meydan_test` → 0. Ekran: her krallık için `-- meydan prep <0..9> 0 notips` (rakip 0. savaşın krallığı; farklı biyomlar için `-- meydan prep 0 <n>` ile 0..6 savaş) → 10 biyomun hepsini kolajda gör (`uvx --from pillow python -I` ile 5x2 kolaj, scratchpad).
- [ ] **Step 6: Commit** — `gorsel: krallık başına manzara süsleri (mezar, lav, kristal, gölcük...)` + push.

---

### Task 5: Meydan sadeleştirme — sayılar, sıra çubuğu kalkar; kalpler ve aşama göstergesi (UI5a)

**Files:**
- Create: `Fetih/scripts/ui/lives_hearts.gd` (`class_name LivesHearts`), `Fetih/scripts/ui/run_progress.gd` (`class_name RunProgress`)
- Delete: `Fetih/scripts/ui/run_map.gd` (+ `.uid`)
- Modify: `Fetih/scripts/battle/squad_view.gd` (`_draw_count_label`, `_count_pulse`, `_last_count`, `COUNT_PULSE_*`, `LABEL_*` kalkar; `_draw_over` sadece boss çubuğu; `over_key` sadece boss)
- Modify: `Fetih/scripts/run/squad_info.gd` (`top_bar` silinir)
- Modify: `Fetih/scripts/run/prep_layer.gd` (üst şerit: `LivesHearts` sol üst, `RunProgress` üst orta)
- Modify: `Fetih/scripts/run/battle_hud.gd` (sol üstte aynı `LivesHearts` + `RunProgress`)
- Modify: `Fetih/tools/meydan_test.gd`

**Interfaces:**
- Produces:
  - `LivesHearts.new(lives: int, max_lives: int)` (`Control`), `set_lives(n: int, animate := true)`; kırılma animasyonu `break_heart(index)`; `HEART := 12` (px, 640x360 düzende), kalpler koddan `Image` (12x11, `e83b3b`/`f04f78` + `2e222f` kontur), boş kalp sadece kontur `625565`. Nefes: tam kalpler ölçek 1.0↔1.06, 1.2 sn, sırayla 0.15 sn gecikmeli.
  - `RunProgress.new()` (`Control`), `refresh()`; `current_index() -> int` (= `RunState.battle_index`); 20 nokta, aralık `DOT_GAP := 9`, boss noktası (`(i + 1) % Balance.BOSS_EVERY == 0`) taç simgesi; geçilen = altın dolu, kaybedilen = kırmızı dolu (`RunState.results[i]`; alan adı `RunState`'te `history`/`results` ne ise o — `run_map.gd`'nin kullandığı alanı aynen al), şu anki = 1.4x, nabız (`modulate` 0.7↔1.0). `_get_tooltip(at)`: "Savaş %d · %s" (+ "BOSS" / "BÜYÜK FETİH"). Rakip baş harfi yok.

- [ ] **Step 1: meydan_test'e kontroller ekle (başarısız)**

`_initialize` içinde PREP açıldıktan sonra:

```gdscript
	var hearts: Control = _find(meydan.prep, "LivesHearts")
	check("kalpler hazırlıkta", hearts != null and hearts.full_count() == run.lives)
	var progress: Control = _find(meydan.prep, "RunProgress")
	check("aşama göstergesi şu anki savaş", progress != null and progress.current_index() == run.battle_index)
	check("sıra çubuğu (RunMap) yok", _find(meydan.prep, "RunMap") == null)
	var view: SquadView = meydan.player_views()[0]
	check("bölükte sayı etiketi yok", not view.has_method("_draw_count_label"))
```

Yardımcı:

```gdscript
func _find(node: Node, cls: String) -> Node:
	for child in node.find_children("*", "", true, false):
		var s: Script = child.get_script()
		if s and s.get_global_name() == cls:
			return child
	return null
```

Can kaybı kontrolü (mevcut kaybedilen savaş adımından sonra): `hearts.set_lives(run.lives)` sonrası `full_count() == run.lives`.

- [ ] **Step 2: Çalıştır** → HATA.
- [ ] **Step 3: `lives_hearts.gd`, `run_progress.gd` yaz; `squad_view.gd`'den sayı etiketini, `squad_info.gd`'den `top_bar`'ı, `run_map.gd`'yi sil; `prep_layer.gd` üst kısmı:**

```gdscript
	var top := UiKit.hbox(10)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = 6
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_hearts = LivesHearts.new(RunState.lives, RunState.max_lives)
	top.add_child(_hearts)
	top.add_child(UiKit.spacer())
	_progress = RunProgress.new()
	top.add_child(_progress)
	top.add_child(UiKit.spacer())
	top.add_child(Control.new())  # sağ denge: kalp genişliği kadar boşluk
```

`refresh()` → `_hearts.set_lives(RunState.lives, false)`, `_progress.refresh()`. Sol panel `position.y` 62 → 30. `Meydan.FRAME_PAD_TOP` 56 → 26. `battle_hud.gd`: sol üst eşleşme kutusu yerine aynı `LivesHearts` + `RunProgress` satırı (`show_matchup` yalnız test modunda kullanılır: test modunda kutu kalır, koşuda gizli). Can kaybı (`finish_battle(false)`) sonrası HUD'da `set_lives(RunState.lives, true)` → kırılma.
- [ ] **Step 4: Testler** — `--import`, `meydan_test`, `field_test`, `card_fit_test` → 0. Ekran `-- meydan prep 2 3 notips`, `-- meydan battle 2 3 notips`: sayı yok, sıra çubuğu yok, kalpler + noktalar var.
- [ ] **Step 5: Commit** — `meydan: asker sayıları ve rakip sırası kalktı; animasyonlu kalpler ve aşama göstergesi` + push.

---

### Task 6: Rakip kartı, bölük kartı, açıklama metinleri kalkar (UI5b)

**Files:**
- Modify: `Fetih/scripts/run/squad_info.gd` (`fill_opponent` → simgeli kompakt kart; `squad_card(squad) -> Control`)
- Modify: `Fetih/scripts/run/prep_layer.gd` (sabit `_info` ipucu metni kalkar; fare altı bölük kartı imleç yanında)
- Modify: `Fetih/scripts/meta/tips.gd` (PREP ipucu metnine "Bir bölüğün üstüne gelince ayrıntısı görünür." eklenir)
- Modify: `Fetih/tools/meydan_test.gd`

**Interfaces:**
- Consumes: `UiKit.game_panel`, `UiKit.unit_icon`, `BannerArt.emblem` (Task 3; 7x7 amblem → `ImageTexture` 2x).
- Produces: `SquadInfo.fill_opponent(box: VBoxContainer, width := 0.0)` aynı imza, içerik: satır 1 amblem + krallık adı (14, `heading=true`, krallık rengi) + güç (11, altın); satır 2 bölük simgeleri (`unit_icon(unit, 1)` + altında seviye noktaları), fermanlar küçük mühür simgeleri (`card_icon_texture(&"passive"...)` 1x), her simgenin `tooltip_text`'i adı + açıklaması. `SquadInfo.squad_card(squad: ArmySquad) -> PanelContainer` (ad 12, `level_text`, rol, iki ince çubuk can/hasar oranı birim maksimuma göre). `PrepLayer.hover_card: PanelContainer` (fare bölük üstündeyken görünür, imleç +12 px).

- [ ] **Step 1: meydan_test kontrolü (başarısız)**

```gdscript
	check("sabit ipucu metni yok", not _has_text(meydan.prep, "Bir bölüğün üstüne gel"))
	meydan.prep.show_hover(0)
	check("bölük kartı görünür", meydan.prep.hover_card.visible)
	meydan.prep.show_hover(-1)
	check("bölük kartı gizlenir", not meydan.prep.hover_card.visible)
```

```gdscript
func _has_text(node: Node, part: String) -> bool:
	for child in node.find_children("*", "Label", true, false):
		if (child as Label).text.contains(part):
			return true
	return false
```

- [ ] **Step 2: Çalıştır** → HATA (`show_hover` yok).
- [ ] **Step 3: Uygula.** `PrepLayer.show_hover(index: int)`: `index < 0` gizler; değilse kartın içeriğini `SquadInfo.squad_card(RunState.army[index])` ile yeniler, `position = _mouse + Vector2(12, 12)` ekran içine kıstırılır. Mevcut fare-altı algılama (`_info` güncelleyen kod) `show_hover` çağırır. Rakip paneli genişliği `SIDE_WIDTH` 150 → 132.
- [ ] **Step 4: Testler** — `meydan_test`, `card_fit_test` → 0; ekran `-- meydan prep 2 3 notips`.
- [ ] **Step 5: Commit** — `meydan: simgeli rakip kartı, fare altı bölük kartı, sabit ipucu metni kalktı` + push.

---

### Task 7: Savaş HUD'u, kart paneli, duraklat menüsü koyu şık (UI6)

**Files:**
- Modify: `Fetih/scripts/run/battle_hud.gd` (hız düğmeleri simge, süre şeridi koşuda gizli, sonuç paneli pop)
- Modify: `Fetih/scripts/run/card_layer.gd` (kart görünümü, sırayla gelme, başlık "Ganimet seç", "Kart alma, devam et" hayalet düğme)
- Modify: `Fetih/scripts/ui/ui_kit.gd` (`card_frame`: oyun teması, 6 px köşe, tür renginde 3 px üst şerit, gövde koyu)
- Modify: `Fetih/scripts/ui/pause_menu.gd` (oyun teması, `button_primary` "Devam", diğerleri `button`)
- Modify: `Fetih/tools/card_fit_test.gd` (EN dilinde de koş)

**Interfaces:**
- Consumes: `UiKit.theme_game`, `button_primary`, `button_ghost`, `pop`, `fade_in` (Task 2).
- Produces: `BattleHud.speed_icon(speed: int) -> Texture2D` (koddan 12x10 üçgen sayısı = hız; duraklat iki çubuk), düğmeler 22x22 yuvarlak (`_box(..., radius 11)`), `tooltip_text` "x1"/"x2"/"x4"/"Duraklat". `CardLayer.show_offers()` kartları `fade_in(card, i * 0.08)` + kart `position` değil `custom_minimum_size` sabit (kapsayıcıda); üstüne gelince kart `hover_scale(card, true, 1.03)`.

- [ ] **Step 1: card_fit_test'e EN döngüsü ekle (taşma varsa başarısız)**

Testin mevcut ölçüm gövdesini `_check_all()` fonksiyonuna al; `_initialize` sonunda:

```gdscript
	TranslationServer.set_locale("en")
	_check_all("EN")
	TranslationServer.set_locale("tr")
```

(`_check_all(tag := "TR")` kontrol adlarına `tag` ekler.)

- [ ] **Step 2: Çalıştır** — yeni font + EN ile taşan kart varsa HATA; yoksa önce kart düzeni değişikliğinden sonra yine koşulur.
- [ ] **Step 3: Uygula** (yukarıdaki arayüzler). Süre şeridi: koşuda (`info_text` boş) gizli, test modunda seed yazısı görünür; `Meydan._set_frame_pads` BATTLE için `frame_pad_bottom` 22 → 0 (koşuda). Sonuç paneli: "ZAFER!" / "YENİLGİ" `heading=true` 28, altın/kırmızı, `pop()`; altında "Devam" `button_primary`.
- [ ] **Step 4: Testler** — `card_fit_test`, `meydan_test`, `ui_test` → 0; ekran `-- meydan battle 2 3 notips`, `-- meydan cards 2 3 notips`, `-- en meydan cards 2 3 notips`, `-- meydan prep 2 3 notips` + duraklat (`scene` modu yok: `battle_showcase` `pause` argümanı Meydan'da da çalışacak şekilde genişletilir: `meydan` dalında `args.has("pause")` → `_pause_menu.open()`).
- [ ] **Step 5: Commit** — `meydan: koyu şık savaş HUD'u, kart paneli ve duraklat menüsü` + push.

---

### Task 8: Canlı menü manzarası (UI2a)

**Files:**
- Create: `Fetih/scripts/ui/menu_backdrop.gd` (`class_name MenuBackdrop`)
- Create: `Fetih/tools/menu_test.gd` (bu görevde sadece manzara kısmı)

**Interfaces:**
- Produces: `MenuBackdrop.new()` (`Control`, tam ekran, `mouse_filter = IGNORE`), `dim: float` (0..1, krallık seçiminde 0.35 karartma), `parallax := true`. Katmanlar `_draw`'da: gökyüzü degrade (`1e2a4a` → `4d65b4` → `f9c22b` ufuk), güneş/ay daire, 3 bulut katmanı (koddan yumuşak piksel bulut `Image`, x hızı 4/8/14 px/sn, sarmalı), uzak dağlar (palet morları, `sin` toplamı silüet, seed sabit), kale silueti (sağ tepe; burçlar, 3 küçük dalgalanan sancak `BannerArt.texture(KingdomCatalog.all()[i], frame)`), ön tepe yeşili + `assets/terrain/px/plants` ağaçları (3–6 adet, sabit konum), kuş sürüsü (5–7 "v", 18 sn'de bir soldan sağa, kanat 2 kare). Paralaks: fare konumu merkezden sapma × katman katsayısı (0, 1, 2, 4, 8 px), `lerp` ile yumuşak. Tüm konumlar `size`'a oranlı; `NOTIFICATION_RESIZED` → önbellekli katman resimleri yeniden kurulur. Sahne öğeleri Nearest, degrade `draw_rect` şeritleri.

- [ ] **Step 1: menu_test (manzara) yaz (başarısız)**

```gdscript
extends SceneTree
## Ana menü, krallık seçimi ve ayarlar testi (ekransız). Oyuncunun kaydına/ayarına yazmaz.
## Çalıştırma: godot --headless --path Fetih -s res://tools/menu_test.gd

const TEST_SAVE := "user://menu_test_save.json"
const TEST_SETTINGS := "user://menu_test_settings.cfg"
var failures := 0


func check(name: String, ok: bool) -> void:
	print("%s  %s" % ["TAMAM " if ok else "HATA  ", name])
	if not ok:
		failures += 1


func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node.get_parent() != root:
		return
	if node.name == "Profile":
		node.save_path = TEST_SAVE
	elif node.name == "Settings":
		node.settings_path = TEST_SETTINGS


func _initialize() -> void:
	await process_frame
	await test_backdrop()
	print("Hata: %d" % failures)
	quit(1 if failures > 0 else 0)


func test_backdrop() -> void:
	var bd: Control = load("res://scripts/ui/menu_backdrop.gd").new()
	bd.size = Vector2(640, 360)
	root.add_child(bd)
	await process_frame
	var clouds_before: float = bd.cloud_offset(0)
	await create_timer(0.3).timeout
	check("bulutlar kayıyor", bd.cloud_offset(0) != clouds_before)
	bd.size = Vector2(853, 480)
	await process_frame
	check("boyut değişince katmanlar yeniden kuruldu", bd.layer_width() == 853)
	bd.queue_free()
```

`MenuBackdrop.cloud_offset(layer: int) -> float`, `layer_width() -> int` test kancaları.
(Settings `settings_path` adı `scripts/meta/settings.gd`'deki gerçek alan adıyla doğrulanır; farklıysa testte o kullanılır.)

- [ ] **Step 2: Çalıştır** → HATA.
- [ ] **Step 3: `menu_backdrop.gd` yaz.**
- [ ] **Step 4: Test + ekran** — `menu_test` → 0. Geçici gösterim: `-- scene res://scenes/ui/main_menu.tscn` henüz yok; Task 9'da bakılır. Şimdilik `tools/backdrop_preview.gd` gerekmez, ekran Task 9'da.
- [ ] **Step 5: Commit** — `arayuz: canlı menü manzarası (bulut, dağ, kale, sancak, kuş, paralaks)` + push.

---

### Task 9: Ana menü, logo açılışı, istatistikler (UI2b)

**Files:**
- Create: `Fetih/scenes/ui/main_menu.tscn` (kök `Control` + `main_menu.gd`), `Fetih/scripts/ui/main_menu.gd`, `Fetih/scripts/ui/stats_panel.gd` (`class_name StatsPanel`)
- Modify: `Fetih/project.godot` (`run/main_scene="res://scenes/ui/main_menu.tscn"`)
- Modify: `Fetih/scripts/ui/screens.gd` (`MAIN_MENU`; `resume_saved_run` hata yolunda `MAIN_MENU`)
- Modify: `Fetih/scripts/ui/treasury.gd`, `Fetih/scripts/ui/run_end.gd`, `Fetih/scripts/ui/pause_menu.gd` ("ana menü" → `MAIN_MENU`; krallık seçimine dönen yerler `MAIN_MENU`)
- Modify: `Fetih/tools/menu_test.gd`

**Interfaces:**
- Consumes: `MenuBackdrop`, `UiKit.theme_menu/button_primary/button/fade_in/slide_in`, `Overlay`.
- Produces: `MainMenu` (script `main_menu.gd`): `static var intro_done := false` (oyun açılışında bir kez), `skip_intro()`, `buttons() -> Array[Button]` (sırayla), `_on_new_game()` (kayıt varsa `Overlay` onayı; onay → `Profile.clear_run()` + `Screens.goto(KINGDOM_SELECT)`; iptal → hiçbir şey). `StatsPanel.open(parent: Control)`. `Screens.MAIN_MENU := "res://scenes/ui/main_menu.tscn"`.
- Düzen (640x360): sol %40 sütun; logo "FETİH" `heading=true` 44, altın, 1 px koyu gölge + yavaş parıltı (shader yok: üstünde `modulate` Tween'li ince ışık şeridi `ColorRect` maskesiz, sadece logo kutusunda soldan sağa 3 sn'de bir); alt başlık `tr("Krallıkları fethet")` 12. Düğmeler (genişlik 150): Devam et (`button_primary`, altında küçük `"%s · savaş %d"`), Yeni oyun (kayıt yoksa `button_primary`), Hazine, İstatistikler, Ayarlar, Çık (`button_ghost`). Sağ alt: Şan simgesi + sayı, sürüm `v0.13.0` (10, soluk).
- Logo açılışı: siyah `ColorRect` üstünde "FETİH" harfleri ayrı `Label`'lar, her biri 0.12 sn arayla yukarıdan düşer (`TRANS_BOUNCE`), sonra kılıç parıltısı (`ColorRect` 2 px yükseklik, beyaz → saydam) logonun üstünden geçer, 0.4 sn sonra siyah perde solar, menü düğmeleri `fade_in(i * 0.06)`. Toplam ≤ 2.5 sn × `anim_scale()`. Herhangi bir tık/tuş → `skip_intro()` (tween'leri öldürür, son duruma atlar). İkinci kez (krallık seçiminden dönüş) açılış yok.

- [ ] **Step 1: menu_test'e ana menü testleri ekle (başarısız)**

```gdscript
func test_main_menu() -> void:
	var profile := root.get_node("Profile")
	profile.clear_run()
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.skip_intro()
	var names := menu.buttons().map(func(b: Button) -> String: return b.text)
	check("kayıt yokken Devam yok", not names.any(func(n: String) -> bool: return n.begins_with(tr("Devam et"))))
	check("6'dan az düğme (Devam yok)", names.size() == 5)
	menu.queue_free()
	await process_frame
	# Yarım koşu kaydı varken
	var run := root.get_node("RunState")
	run.start_run(KingdomCatalog.all()[0], 77)
	profile.store_run(run.to_dict("prep"))
	menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.skip_intro()
	check("kayıt varken ilk düğme Devam", menu.buttons()[0].text.begins_with(tr("Devam et")))
	menu._on_new_game()
	await process_frame
	check("Yeni oyun onay soruyor, kayıt duruyor", profile.has_saved_run())
	menu.cancel_confirm()
	check("iptal sonrası kayıt duruyor", profile.has_saved_run())
	menu.queue_free()
	profile.clear_run()
```

`_initialize`'a `await test_main_menu()` ekle. `MainMenu.cancel_confirm()` onay penceresini kapatır (test kancası, iptal düğmesinin yaptığı).

- [ ] **Step 2: Çalıştır** → HATA.
- [ ] **Step 3: Uygula** (`main_menu.gd`, `stats_panel.gd`, `screens.gd`, `project.godot`, dönüş yolları). `kingdom_select.gd` başlığındaki Hazine/Ayarlar/Çık/Devam düğmeleri Task 10'da kalkar; bu görevde krallık seçimine "Geri" (`button_ghost`, Esc) eklenir → `MAIN_MENU`.
- [ ] **Step 4: Testler + ekran** — `--import`, `menu_test`, `meydan_test` → 0. Ekran: `-- scene res://scenes/ui/main_menu.tscn notips` 40. kare (açılış ortası) ve 200. kare (menü), `--resolution 1280x720` ve `2560x1440` ile 200. kare. `StatsPanel`: `battle_showcase` `scene` dalına `stats` argümanı (`StatsPanel.open(screen)`).
- [ ] **Step 5: Commit** — `arayuz: animasyonlu ana menü, logo açılışı, istatistik penceresi` + push.

---

### Task 10: Krallık seçimi — sancaklar, diorama, bilgi kartı (UI3)

**Files:**
- Create: `Fetih/scripts/ui/kingdom_banner.gd` (`class_name KingdomBanner`), `Fetih/scripts/ui/kingdom_diorama.gd` (`class_name KingdomDiorama`)
- Rewrite: `Fetih/scripts/ui/kingdom_select.gd`
- Modify: `Fetih/tools/menu_test.gd`

**Interfaces:**
- Consumes: `BannerArt.emblem`, `BannerArt.texture` (Task 3), `TerrainProps.texture`, `GroundArt.BIOMES`/`props_of` (Task 4), `MiniUnitArt`/`UnitSprites.sheet_for(unit, team)`, `MenuBackdrop` (Task 8), `UiKit` tema/düğme/animasyon.
- Produces:
  - `KingdomBanner.new(kingdom: KingdomData, unlocked: bool)` (`Control`, 48x80 düzen pikseli): `selected: bool` (setter: 8 px yukarı kalkar + parlama, `Tween`), `signal picked(kingdom)`; bez `_draw` ile `sin` dalgası (zaman `_process`), amblem ortada (2x), kilitliyse gri bez + zincir (2 çapraz çizgi) + kilit simgesi; adı altında `label(..., 10)` genişliğe sığdırılır (`text_overrun_behavior = OVERRUN_TRIM_ELLIPSIS`, `clip_text`). Fare üstünde 2° sallanma.
  - `KingdomDiorama.new()` (`Control`): `show_kingdom(kingdom: KingdomData, direction := 1)` (eski sahne `direction` yönüne kayarak çıkar, yenisi gelir, 0.35 sn); içerik: izometrik küçük yer parçası (`BIOMES[id].ramp` renkleri, 7x4 karo baklava), 4–6 süs, sağ arkada krallık sancağı, ortada başlangıç birliklerinden 8 figür (`UnitSprites.sheet_for(unit, PLAYER)`; durma/yürüme karesi zamanla), 2x tam sayı ölçek, Nearest. Kilitliyse figürler siyah silüet (`modulate = Color(0,0,0,0.8)`).
  - `kingdom_select.gd`: `select(kingdom)`, `selected() -> KingdomData`, `start_button() -> Button`, `_unhandled_input`: ←/→ (`ui_left`/`ui_right`) komşu krallık, `ui_accept` başlat (kilitliyse yok), `ui_cancel` ana menü.
- Düzen (640x360): arka `MenuBackdrop` (`dim = 0.35`); üst şerit: "Geri" (ghost) sol, başlık "KRALLIĞINI SEÇ" (`heading`, 18) orta, Şan sağ; sancak sırası (10 × 52 px, ortalı, y=34); alt bölüm y=128..352: sol diorama (360x220, `menu_panel` çerçeveli), sağ bilgi kartı (`menu_panel`, 240 genişlik): ad (`heading` 20, krallık rengi koyulaştırılmış → parşömende okunur), uzmanlık rozeti (renkli küçük panel), açıklama `wrapped` 11 (en çok 3 satır), "Başlangıç fermanı" simge + ad, birlik simge sırası (`unit_icon(unit, 1)`, tooltip ad + rol), boss simgesi + ad, bu krallıkla fetih sayısı (varsa), altta `button_primary` "%s ile başla" (kilitliyse devre dışı + tek satır kilit koşulu 10, `COLOR_BAD`). Kart değişimde `fade_in`.

- [ ] **Step 1: menu_test'e krallık seçimi testleri (başarısız)**

```gdscript
func test_kingdom_select() -> void:
	var screen: Control = load("res://scenes/ui/kingdom_select.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	var profile := root.get_node("Profile")
	var all := KingdomCatalog.all()
	check("ilk açık krallık seçili", profile.is_unlocked(screen.selected().id))
	var locked: KingdomData = null
	for k in all:
		if not profile.is_unlocked(k.id):
			locked = k
			break
	if locked:
		screen.select(locked)
		check("kilitli krallıkta Başla devre dışı", screen.start_button().disabled)
		var ev := InputEventAction.new()
		ev.action = &"ui_accept"
		ev.pressed = true
		screen._unhandled_input(ev)
		check("kilitliyle Enter koşu başlatmaz", not root.get_node("RunState").active)
	screen.select(all[0])
	var ev_right := InputEventAction.new()
	ev_right.action = &"ui_right"
	ev_right.pressed = true
	screen._unhandled_input(ev_right)
	check("sağ ok sonraki krallık", screen.selected() == all[1])
	for banner in screen.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is KingdomBanner):
		var name_label: Label = banner.name_label
		check("%s sancak adı sığıyor" % banner.kingdom.id, name_label.get_minimum_size().x <= banner.size.x + 0.5 or name_label.clip_text)
	TranslationServer.set_locale("en")
	screen.queue_free()
	await process_frame
	screen = load("res://scenes/ui/kingdom_select.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	check("EN: başla düğmesi kart içinde", screen.start_button().get_global_rect().end.x <= 640.5)
	TranslationServer.set_locale("tr")
	screen.queue_free()
```

`_initialize`'a `await test_kingdom_select()`. `RunState.active` ilk başta false olmalı (test başında `run.end_run()`).

- [ ] **Step 2: Çalıştır** → HATA.
- [ ] **Step 3: Uygula.**
- [ ] **Step 4: Testler + ekran** — `--import`, `menu_test` → 0. Ekran: `-- scene res://scenes/ui/kingdom_select.tscn notips` (1920x1080, 1280x720), `-- en scene ...`. Tüm krallıklar açık görüntü için `battle_showcase`'e `unlockall` argümanı (gösterim profilinde `Profile.unlocked` = hepsi, dosyaya yazmaz: gösterim kaydı zaten ayrı).
- [ ] **Step 5: Commit** — `arayuz: krallık seçimi yenilendi (dalgalanan sancaklar, canlı diorama, bilgi kartı)` + push.

---

### Task 11: Ayarlar, koşu sonu, hazine menü temasında (UI4)

**Files:**
- Rewrite: `Fetih/scripts/ui/settings_panel.gd`
- Modify: `Fetih/scripts/ui/run_end.gd`, `Fetih/scripts/ui/treasury.gd` (menü teması + `MenuBackdrop` `dim = 0.5`, düğme türleri)
- Modify: `Fetih/tools/menu_test.gd`

**Interfaces:**
- Consumes: `UiKit.theme_menu/theme_game`, `Overlay`, `Settings` alanları (mevcut: ses düzeyleri, `fullscreen`, pencere boyutu, savaş hızı, `screen_shake`, `flash_effects`, hasar sayıları, vuruş duraklaması, dil).
- Produces: `SettingsPanel.open(parent: Control, menu := true) -> Control` (aynı çağrı imzası; `menu` false → oyun teması), panel içinde `TabBar` (Ses / Görüntü / Oyun / Dil) + `tab_content() -> Control`, `select_tab(i: int)`; `slider_for(key: StringName) -> HSlider`. Satır: sol etiket (12), sağ kontrol sabit 180 genişlik, satır yüksekliği 26; açma/kapama `CheckButton` (tema odak stili tek tip: Task 2), sürgü yanında `"%d%%"` etiketi. Sekme değişince içerik `fade_in` (0.15).
- Hata düzeltmeleri: sürgü başlangıç değeri `Settings`'teki gerçek değer (`set_value_no_signal`); sarı çerçeve yalnız klavye odağında (fareyle tıklanınca `release_focus()`).

- [ ] **Step 1: menu_test'e ayarlar testleri (başarısız)**

```gdscript
func test_settings() -> void:
	var settings := root.get_node("Settings")
	settings.music_volume = 0.6
	var host := Control.new()
	root.add_child(host)
	var panel: Control = load("res://scripts/ui/settings_panel.gd").open(host, true)
	await process_frame
	panel.select_tab(0)
	check("müzik sürgüsü gerçek değeri gösterir", is_equal_approx(panel.slider_for(&"music_volume").value, 0.6 * 100.0))
	panel.select_tab(2)
	var checks := panel.tab_content().find_children("*", "CheckButton", true, false)
	check("oyun sekmesinde açma/kapamalar", checks.size() >= 4)
	var normal_styles := {}
	for c: CheckButton in checks:
		normal_styles[c.get_theme_stylebox("normal")] = true
	check("açma/kapama stilleri tek tip", normal_styles.size() == 1)
	host.queue_free()
```

(Alan adları `settings.gd`'deki gerçek adlarla eşlenir: ör. `music_volume` farklıysa o.)

- [ ] **Step 2: Çalıştır** → HATA.
- [ ] **Step 3: Uygula.** `PauseMenu` ayarları `SettingsPanel.open(self, false)` ile açar.
- [ ] **Step 4: Testler + ekran** — `menu_test`, `meydan_test` → 0; ekran `-- scene res://scenes/ui/main_menu.tscn settings notips` (dört sekme için `settings_tab=<i>` argümanı), `-- scene res://scenes/ui/run_end.tscn notips`, `-- scene res://scenes/ui/treasury.tscn notips`.
- [ ] **Step 5: Commit** — `arayuz: sekmeli ayarlar, koşu sonu ve hazine menü temasında; odak/sürgü hataları` + push.

---

### Task 12: Çeviri, belgeler, sürüm 0.13.0 (UI8)

**Files:**
- Modify: `Fetih/i18n/en.po` (ve `.pot` varsa), `CLAUDE.md`, `Fetih/project.godot` (`config/version="0.13.0"`), `yayin/` ekran görüntüleri (varsa güncellenir)
- Modify: memory `fetih-bekleyen-istekler.md`

- [ ] **Step 1:** `"$G" --headless --path Fetih -s res://tools/update_translations.gd` → listelenen boş msgstr'leri doğal oyun İngilizcesiyle doldur ("Krallığını seç" → "Choose your kingdom", "Ganimet seç" → "Choose your spoils", "Yeni oyun" → "New game", "İstatistikler" → "Statistics", "Krallıkları fethet" → "Conquer the kingdoms"…); kullanılmayan msgid'leri sil.
- [ ] **Step 2:** `CLAUDE.md`: "Yazı tipi: Pixel Operator…" satırı → "Yazı tipi: Cinzel (başlık) + Nunito (metin), OFL, `Fetih/assets/fonts/`; `UiKit.ui_font(weight)`, `UiKit.heading_font()`, `UiKit.label(text, size, color, heading)`. İki tema: `UiKit.theme_menu()` (menü ekranları, renkli fantastik) ve `UiKit.theme_game()` (Meydan, koyu şık). Test: `res://tools/font_test.gd`, `res://tools/ui_test.gd`, `res://tools/menu_test.gd`."; ekran akışı başına "ana menü (`main_menu`, logo açılışı + `MenuBackdrop`) →"; `KingdomCamp` + `building_art.gd` cümlesi → "Her ordunun arkasında krallık sancağı (`unit_art/banner_art.gd`, `Battlefield.set_banners`); krallık manzara süsleri `unit_art/terrain_props.gd` + `GroundArt.BIOMES[*].props`."; "Görsel dil: 9 Kings" satırına bu spec eklenir; `RunMap` → `RunProgress` + `LivesHearts`.
- [ ] **Step 3:** Tam test turu: `font_test`, `ui_test`, `menu_test`, `meydan_test`, `field_test`, `card_fit_test`, `mini_art_test`, `save_test`, `run_test` (fetih oranı öncekiyle aynı, ~%56) → hepsi 0.
- [ ] **Step 4:** Sürüm 0.13.0; export: `"$G" --headless --path Fetih --export-release "Windows Desktop"` (şablon yoksa `--export-pack ... build/test/Fetih.pck` dene), zip `Fetih/build/Fetih-0.13.0-windows.zip`.
- [ ] **Step 5:** Commit `surum: 0.13.0 (arayüz yenileme: ana menü, krallık seçimi, sade Meydan, krallık manzaraları)` + push; memory durum notu güncellenir.

---

## Self-review notları

- Spec kapsamı: §1 → T1–T2; §2 → T8–T9; §3 → T10; §4 → T11 (+ PauseMenu T7/T11); §5 → T3–T4; §6 → T5–T7; §7 → T12. "Koşu sonu menü temasına geçer" → T11. "Süre şeridi kalkar" → T7. Eksik yok.
- Sıra spec ile aynı: UI1 (T1–T2) → UI7 (T3–T4) → UI5 (T5–T6) → UI6 (T7) → UI2 (T8–T9) → UI3 (T10) → UI4 (T11) → UI8 (T12).
- Doğrulanacak gerçek adlar (planın tahmin ettiği): `Settings.settings_path` ve ses alanı adları (T8, T11), `RunState`'in savaş sonuç listesi (T5; `run_map.gd` ne kullanıyorsa), `Tips` PREP metni (T6). Uygulayan kişi görev başında bu dosyalara bakar.
