class_name UiKit
## Arayüz yardımcıları: bütün ekranlar aynı yazı tiplerini, renkleri ve kutuları kullansın.
## İki tema: theme_menu() (menü ekranları, renkli fantastik) ve theme_game() (Meydan, koyu şık).

const FONT_SIZE := 11
const COLOR_BG := Color("1a1714")
const COLOR_PANEL := Color("2a2622")
const COLOR_SLOT_EMPTY := Color("211e1b")
const COLOR_TEXT := Color("e8e2d0")
const COLOR_MUTED := Color("9a9484")
const COLOR_GOOD := Color("8fd47f")
const COLOR_BAD := Color("e06a5a")
const COLOR_GOLD := Color("e8c25a")

## Menü teması (renkli fantastik): gece mavisi gök, parşömen panel, koyu mürekkep yazı.
const COLOR_SKY := Color("1e2a4a")
const COLOR_PARCHMENT := Color("f2e3c0")
const COLOR_INK := Color("3b2a1e")
## Oyun teması (koyu şık): saydam koyu panel.
const COLOR_GAME_PANEL := Color(0.07, 0.08, 0.10, 0.82)

## Panel ve düğme kenarı (Resurrect 64 gri-mor): 9 Kings tarzı koyu kutu, ince açık kenar.
const COLOR_EDGE := Color("625565")
## Arayüz yazı tipleri (OFL, Google Fonts): Cinzel başlık (fantastik büyük harf), Nunito metin.
## İkisi değişken font (wght ekseni): aynı dosyadan FontVariation ile kalınlık türetilir.
## Godot: stretch canvas_items metni pencere çözünürlüğünde çizer; kenar yumuşatma açık, hafif hinting.
## Dosya yoksa Godot'un varsayılan yazı tipi kullanılır.
const FONT_BODY_PATH := "res://assets/fonts/Nunito.ttf"
const FONT_HEADING_PATH := "res://assets/fonts/Cinzel.ttf"

static var _fonts := {}  ## "yol|ağırlık" -> Font


static var _theme_menu: Theme
static var _theme_game: Theme


## Ekranların kök düğümüne verilir; tüm alt düğümler bu yazı tipini, kutuları ve düğmeleri kullanır.
## Godot: Theme, Control'lere tür adına göre (Button, PanelContainer...) stil verir; alt düğümler
## temayı ebeveynden devralır, bu yüzden kökteki tek tema bütün ekranı boyar.
## theme(): oyun içi (Meydan) koyu şık tema. Menü ekranları theme_menu() kullanır.
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


static func _build_theme(panel_color: Color, edge: Color, border: int, radius: int, text: Color) -> Theme:
	var t := Theme.new()
	t.default_font = ui_font()
	t.default_font_size = FONT_SIZE
	var box := _box(panel_color, edge, border, radius, 8)
	t.set_stylebox("panel", "PanelContainer", box)
	t.set_stylebox("panel", "Panel", box)
	t.set_stylebox("panel", "TooltipPanel", _box(Color(0.05, 0.05, 0.07, 0.95), Color(COLOR_GOLD, 0.6), 1, 4, 4))
	t.set_color("font_color", "Label", text)
	t.set_color("font_color", "TooltipLabel", COLOR_TEXT)
	# Odak çerçevesi tek tip ve ince: sadece klavyeyle gezilirken görünür (fareyle tıklanınca odak bırakılır).
	var focus := _box(Color(0, 0, 0, 0), COLOR_GOLD, 1, radius, 0)
	focus.shadow_size = 0
	for type in ["Button", "CheckButton", "CheckBox", "OptionButton", "HSlider", "TabBar"]:
		t.set_stylebox("focus", type, focus)
	var button_bg := panel_color.darkened(0.15) if text == COLOR_INK else Color(0.12, 0.13, 0.16, 0.9)
	t.set_stylebox("normal", "Button", _box(button_bg, edge, border, radius, 6))
	t.set_stylebox("hover", "Button", _box(button_bg.lightened(0.1), COLOR_GOLD, border, radius, 6))
	t.set_stylebox("pressed", "Button", _box(button_bg.darkened(0.25), COLOR_GOLD, border, radius, 6))
	t.set_stylebox("disabled", "Button", _box(Color(button_bg.darkened(0.3), 0.7), edge.darkened(0.5), border, radius, 6))
	var empty := StyleBoxEmpty.new()
	for type in ["CheckButton", "CheckBox"]:  # açma/kapama: zeminsiz, hepsi aynı stil
		for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
			t.set_stylebox(state, type, empty)
	t.set_color("font_color", "Button", text)
	t.set_color("font_hover_color", "Button", COLOR_GOLD if text == COLOR_TEXT else COLOR_INK.darkened(0.4))
	t.set_color("font_pressed_color", "Button", COLOR_GOLD if text == COLOR_TEXT else COLOR_INK)
	t.set_color("font_focus_color", "Button", text)
	t.set_color("font_disabled_color", "Button", COLOR_MUTED)
	for type in ["CheckButton", "CheckBox", "OptionButton"]:
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			t.set_color(key, type, text)
	t.set_stylebox("slider", "HSlider", _box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 3, 2))
	t.set_stylebox("grabber_area", "HSlider", _box(COLOR_GOLD, Color(0, 0, 0, 0), 0, 3, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(COLOR_GOLD.lightened(0.2), Color(0, 0, 0, 0), 0, 3, 2))
	return t


## Yuvarlak köşeli, gölgeli kutu (temaların ve düğme türlerinin ortak yapı taşı).
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
	s.content_margin_top = mini(margin, 3)
	s.content_margin_bottom = mini(margin, 3)
	s.anti_aliasing = true
	return s


## Metin yazı tipi (Nunito), weight: 200-1000 (400 normal, 700 kalın).
static func ui_font(weight := 500) -> Font:
	return _font(FONT_BODY_PATH, weight)


## Başlık yazı tipi (Cinzel), weight: 400-900.
static func heading_font(weight := 700) -> Font:
	return _font(FONT_HEADING_PATH, weight)


## Godot: FontVariation bir FontFile'ı sarar ve OpenType eksen değeri (burada wght) verir; her ağırlık
## bir kez kurulur, önbellekten paylaşılır.
static func _font(path: String, weight: int) -> Font:
	var key := "%s|%d" % [path, weight]
	if not _fonts.has(key):
		if not ResourceLoader.exists(path):
			_fonts[key] = ThemeDB.fallback_font
		else:
			var file: FontFile = load(path)
			file.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			file.hinting = TextServer.HINTING_LIGHT
			var variation := FontVariation.new()
			variation.base_font = file
			variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
			if path == FONT_BODY_PATH:  # Nunito'nun satır aralığı geniş: küçük arayüz yazısında 2 px sıkılaştır
				variation.spacing_top = -1
				variation.spacing_bottom = -1
			_fonts[key] = variation
	return _fonts[key]


## Bir Control'ün yazı tipini ve boyutunu ayarlar (Label, Button...). heading: başlık fontu.
static func set_font_size(control: Control, size: int, heading := false) -> void:
	control.add_theme_font_override("font", heading_font() if heading else ui_font())
	control.add_theme_font_size_override("font_size", size)


## Koyu kutu: 1 px kenar, keskin köşe, altta 2 px gölge (9 Kings panelleri gibi).
static func panel_style(color := COLOR_PANEL, margin := 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(1)
	style.border_color = COLOR_EDGE
	style.set_corner_radius_all(0)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 2)
	style.set_content_margin_all(margin)
	return style


static func _button_style(color: Color, edge: Color) -> StyleBoxFlat:
	var style := panel_style(color, 0)
	style.border_color = edge
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	return style


## Ekranı kaplayan arka plan + kenar boşluklu içerik kutusu. İçeriği döndürür.
## menu: renkli fantastik tema, arka plan eklenmez (ekran kendi MenuBackdrop'unu koyar).
static func screen_root(screen: Control, margin := 10, menu := false) -> VBoxContainer:
	screen.theme = theme_menu() if menu else theme()
	if not menu:
		var bg := ColorRect.new()
		bg.color = COLOR_BG
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen.add_child(bg)
	var margin_box := MarginContainer.new()
	margin_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin_box.add_theme_constant_override(side, margin)
	screen.add_child(margin_box)
	var content := vbox(6)
	margin_box.add_child(content)
	return content


static func label(text: String, size := FONT_SIZE, color := COLOR_TEXT, heading := false) -> Label:
	var l := Label.new()
	l.text = text
	set_font_size(l, size, heading)
	l.add_theme_color_override("font_color", color)
	return l


## Kutuya sığmayınca alt satıra geçen yazı.
static func wrapped(text: String, size := FONT_SIZE, color := COLOR_TEXT) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func centered(text: String, size := FONT_SIZE, color := COLOR_TEXT) -> Label:
	var l := label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Normal düğme (temadan stil alır). Klavyeyle odaklanabilir; fareyle tıklanınca odak bırakılır,
## böylece odak çerçevesi sadece klavye/gamepad ile gezilirken görünür.
static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.pressed:
			b.release_focus())
	b.pressed.connect(click_sound)
	b.pressed.connect(on_pressed)
	b.mouse_entered.connect(hover_scale.bind(b, true))
	b.mouse_exited.connect(hover_scale.bind(b, false))
	return b


## Birincil düğme: altın dolgu, kalın yazı (Başla, Devam et gibi ana eylem).
static func button_primary(text: String, on_pressed: Callable) -> Button:
	var b := button(text, on_pressed)
	b.add_theme_stylebox_override("normal", _box(COLOR_GOLD, COLOR_GOLD.lightened(0.35), 2, 6, 8))
	b.add_theme_stylebox_override("hover", _box(COLOR_GOLD.lightened(0.15), Color.WHITE, 2, 6, 8))
	b.add_theme_stylebox_override("pressed", _box(COLOR_GOLD.darkened(0.15), COLOR_GOLD, 2, 6, 8))
	b.add_theme_stylebox_override("disabled", _box(Color(COLOR_MUTED, 0.6), COLOR_MUTED, 2, 6, 8))
	b.add_theme_font_override("font", ui_font(800))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, COLOR_INK)
	return b


## Hayalet düğme: saydam zemin, ince altın kenar (ikincil eylem: Geç, Geri).
static func button_ghost(text: String, on_pressed: Callable) -> Button:
	var b := button(text, on_pressed)
	b.add_theme_stylebox_override("normal", _box(Color(1, 1, 1, 0.06), Color(COLOR_GOLD, 0.5), 1, 6, 6))
	b.add_theme_stylebox_override("hover", _box(Color(1, 1, 1, 0.14), COLOR_GOLD, 1, 6, 6))
	b.add_theme_stylebox_override("pressed", _box(Color(0, 0, 0, 0.2), COLOR_GOLD, 1, 6, 6))
	return b


## Fare üstüne gelince hafifçe büyür, çıkınca geri döner (Tween ile 0.08 sn).
## pivot_offset ortaya alınır ki ortadan büyüsün. Kapsayıcılar (HBox, VBox) yeniden dizilince
## ölçeği 1'e çeker; bu sadece anlık bir vurgu olduğu için sorun değil.
static func hover_scale(control: Control, on: bool, amount := 1.04) -> void:
	if on and control is BaseButton and control.disabled:
		return
	control.pivot_offset = control.size / 2.0
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE * (amount if on else 1.0), 0.08)


## Düğme sesi. Audio autoload'una düğüm yolundan ulaşılır: araç scriptleri (-s) UiKit'i
## autoload'lar kurulmadan derler, doğrudan "Audio" adı orada derleme hatası verir.
static func click_sound() -> void:
	var audio := (Engine.get_main_loop() as SceneTree).root.get_node_or_null(^"Audio")
	if audio:
		audio.play("click", -2.0, 0.05)


## Birliğin sprite'ı (durma karesi), piksel sanat bozulmasın diye tam sayı katıyla büyütülür.
## scale, 24 piksellik bir figürün katıdır: küçük figür daha çok, büyük figür daha az büyür,
## böylece ikonlar aşağı yukarı aynı kutuya sığar.
static func unit_icon(unit: UnitData, scale := 2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = UnitSprites.icon(unit)
	var size := icon.texture.get_size()
	var fit := maxi(1, floori(24.0 * scale / maxf(size.x, size.y)))
	icon.custom_minimum_size = size * fit
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## Koyu şık oyun paneli. color verilirse o zemin (eski çağrılar), yoksa saydam koyu.
static func panel(color := COLOR_GAME_PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(color, Color(COLOR_GOLD, 0.45), 1, 4, 6))
	return p


static func game_panel(alpha := 0.82) -> PanelContainer:
	return panel(Color(COLOR_GAME_PANEL, alpha))


## Renkli fantastik menü paneli: parşömen, 2 px altın kenar, 8 px köşe.
static func menu_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(COLOR_PARCHMENT, COLOR_GOLD, 2, 8, 10))
	return p


# --- Animasyon (Tween) ---

## Animasyon süre çarpanı: oyuncu ekran sarsıntısını ve flaşı kapattıysa geçişler yarı sürede biter.
## Settings autoload'una düğüm yolundan ulaşılır (araç scriptleri adı derleme anında tanımaz).
static func anim_scale() -> float:
	var settings := (Engine.get_main_loop() as SceneTree).root.get_node_or_null(^"Settings")
	if settings and not settings.screen_shake and not settings.flash_effects:
		return 0.5
	return 1.0


## Saydamdan görünüre solma. delay: başlamadan önce bekleme (sırayla gelen öğeler için).
static func fade_in(node: CanvasItem, delay := 0.0, time := 0.25) -> Tween:
	node.modulate.a = 0.0
	var tw := node.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay * anim_scale())
	tw.tween_property(node, "modulate:a", 1.0, time * anim_scale())
	return tw


## Kayarak gelme (from: başlangıç farkı) + solma. Kapsayıcı (Box/Grid) içindeki düğümde konumu kapsayıcı
## ezer: sadece serbest konumlu düğümlerde kullan, kapsayıcı içindekiler için fade_in.
static func slide_in(control: Control, from: Vector2, delay := 0.0, time := 0.3) -> Tween:
	var target := control.position
	control.position = target + from
	var tw := fade_in(control, delay, time)
	tw.parallel().tween_property(control, "position", target, time * anim_scale()) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tw


## Küçükten yerine "zıplayarak" büyüme (sonuç paneli, seçilen kart).
static func pop(control: Control, time := 0.2) -> Tween:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2.ONE * 0.85
	var tw := control.create_tween()
	tw.tween_property(control, "scale", Vector2.ONE, time * anim_scale()) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


## Üst şerit / küçük etiket kutusu: ince panel (yatay 6, dikey 2 boşluk), hafif saydam zemin.
static func strip_panel(alpha := 0.9) -> PanelContainer:
	var p := PanelContainer.new()
	var style := panel_style(Color(COLOR_PANEL, alpha), 0)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", style)
	return p


## Krallık şeridi (kart/panel üstü): 3 px ana renk, altında 1 px vurgu rengi. Krallık yoksa boş (görünmez).
static func kingdom_strip(kingdom: KingdomData) -> Control:
	var strip := VBoxContainer.new()
	strip.add_theme_constant_override("separation", 0)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kingdom == null:
		return strip
	for part: Array in [[kingdom.color, 3], [kingdom.accent_color, 1]]:
		var bar := ColorRect.new()
		bar.color = part[0]
		bar.custom_minimum_size = Vector2(0, part[1])
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(bar)
	return strip


static func vbox(separation := 4) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func hbox(separation := 4) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


## Kalan boşluğu dolduran görünmez düğüm (düğmeleri sağa/alta itmek için).
static func spacer(vertical := false) -> Control:
	var c := Control.new()
	if vertical:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


# --- Metinler ---

## Çeviri. Düğüm scriptlerinde tr() kullanılır; statik fonksiyonlarda tr() olmadığı için bu.
## İngilizce: i18n/en.po (tools/update_translations.gd t("...") içindeki metinleri de toplar).
static func t(text: String) -> String:
	return TranslationServer.translate(text)


static func num(value: float) -> String:
	return String.num(value, 2)


static func unit_stats(unit: UnitData) -> String:
	return t("Can %s   Hasar %s   Saldırı %s/sn\nMenzil %s   Hız %s   Zırh %s") % [
			num(unit.hp), num(unit.damage), num(unit.attack_speed),
			num(unit.attack_range), num(unit.move_speed), num(unit.armor)]


## Derinlik bandı adı (hazırlıkta sürüklerken ve bölük ayrıntısında).
static func band_name(band: ArmySquad.Band) -> String:
	match band:
		ArmySquad.Band.FRONT:
			return t("Ön cephe")
		ArmySquad.Band.BACK:
			return t("Arka saf")
	return t("Orta")


static func role_name(role: StringName) -> String:
	return t(RoleRules.ROLE_NAMES.get(role, String(role)))


static func upgrade_name(kind: ArmySquad.Upgrade) -> String:
	match kind:
		ArmySquad.Upgrade.ATTACK:
			return t("Saldırı eğitimi")
		ArmySquad.Upgrade.DEFENSE:
			return t("Savunma eğitimi")
	return t("Takviye")


## Bu yükseltmenin bölüğe etkisi: o türdeki seviye sayısı k'dan k+1'e çıkınca.
static func upgrade_effect(squad: ArmySquad, kind: ArmySquad.Upgrade) -> String:
	var k := squad.upgrade_level(kind)
	var before := Balance.level_multiplier(k)
	var after := Balance.level_multiplier(k + 1)
	match kind:
		ArmySquad.Upgrade.ATTACK:
			return t("Hasar x%s -> x%s") % [num(before * before), num(after * after)]
		ArmySquad.Upgrade.DEFENSE:
			return t("Alınan hasar %%%d -> %%%d") % [roundi(100.0 / (before * before)),
					roundi(100.0 / (after * after))]
	var count_after := UnitCatalog.count_for_budget(squad.unit, squad.base_power * after)
	return t("Asker %d -> %d") % [squad.count, count_after]


static func level_text(squad: ArmySquad) -> String:
	return t("Sv %d/%d") % [squad.level(), Balance.MAX_LEVEL]


## Birliğin özel yetenekleri, okunur cümleler olarak.
static func unit_traits(unit: UnitData) -> PackedStringArray:
	var traits: PackedStringArray = []
	var beats: PackedStringArray = []
	for role in RoleRules.COUNTERS.get(unit.role, []):
		beats.append(role_name(role))
	if not beats.is_empty():
		traits.append(t("%s birliklerine +%%25 hasar") % ", ".join(beats))
	if unit.ignores_armor:
		traits.append(t("Zırhı deler"))
	if unit.splash_radius > 0.0:
		traits.append(t("Alan hasarı"))
	if unit.charge_multiplier > 1.0:
		traits.append(t("Hücum: ilk vuruş x%s") % num(unit.charge_multiplier))
	if unit.prefers_ranged_targets:
		traits.append(t("Önce okçu ve büyücüleri avlar"))
	if unit.role == RoleRules.SPEARMAN:
		traits.append(t("Süvari hücumunu karşılar"))
	if unit.burn_ratio > 0.0:
		traits.append(t("Yakar: +%%%d ateş hasarı (3 sn)") % roundi(unit.burn_ratio * 100))
	if unit.slow_amount > 0.0:
		traits.append(t("Yavaşlatır: -%%%d hız (2 sn)") % roundi(unit.slow_amount * 100))
	if unit.regen_ratio > 0.0:
		traits.append(t("Onarır: saniyede canın %%%s'i") % num(unit.regen_ratio * 100))
	if unit.revive_ratio > 0.0:
		traits.append(t("Dirilir: bir kez, %%%d canla") % roundi(unit.revive_ratio * 100))
	if unit.splits:
		traits.append(t("Bölünür: yok olunca iki küçük bölüğe ayrılır"))
	if unit.is_ranged():
		traits.append(t("Yakın dövüşte zayıf"))
	return traits


## Krallığın uzmanlığı: rol adı ya da özel etiket ("Diriliş" gibi).
static func kingdom_specialty(kingdom: KingdomData) -> String:
	if kingdom.specialty_label != "":
		return t(kingdom.specialty_label)
	return role_name(kingdom.specialty_role)


# --- Kartlar (9 Kings tarzı: tür renkli çerçeve, üstte büyük resim) ---

const COLOR_PASSIVE := Color("a884f3")  ## Ferman kartı çerçevesi (Resurrect 64 morunun açığı).
const CARD_ART_HEIGHT := 64  ## Kartın üstündeki resim alanının yüksekliği (piksel).

static var _card_icons := {}  ## Koddan çizilen kart ikonları (tür + renk anahtarlı önbellek).


## Tür renkli çerçeveli kart kabuğu. Birlik: krallık rengi, yükseltme: altın, ferman: mor.
## Üst bölümde büyük resim (birlik: birlik figürü, yükseltme: kılıç/kalkan/artı, ferman: krallık mührü),
## altında metin için gövde kutusu: `card_body(frame)` ile alınır, çağıran içine satır ekler.
## unit: sadece birlik kartında resim için; upgrade: sadece yükseltme kartında (ArmySquad.Upgrade).
## Godot: StyleBoxFlat'in border_width ile çerçeve çizilir; set_meta ile kabuğa gövde kutusu iliştirilir.
static func card_frame(kind: CardOffer.Kind, kingdom: KingdomData, unit: UnitData = null,
		upgrade := ArmySquad.Upgrade.REINFORCE, art_scale := 3, art_height := CARD_ART_HEIGHT) -> PanelContainer:
	var edge := COLOR_GOLD
	match kind:
		CardOffer.Kind.UNIT:
			edge = kingdom.color if kingdom else COLOR_EDGE
		CardOffer.Kind.PASSIVE:
			edge = COLOR_PASSIVE
	var frame := PanelContainer.new()
	# Koyu şık kart: 6 px köşe, 1 px tür renkli kenar, üstte 3 px tür şeridi (resim alanının üst kenarı).
	var style := _box(Color(0.10, 0.11, 0.14, 0.97), Color(edge, 0.85), 1, 6, 1)
	style.border_width_top = 3
	style.border_color = edge
	style.content_margin_top = 3
	frame.add_theme_stylebox_override("panel", style)
	var column := vbox(0)
	frame.add_child(column)
	# Resim alanı: biraz daha koyu zemin (üst köşeleri karta uyar), ortalanmış resim, altında 1 px çizgi.
	var art_bg := Panel.new()
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = Color(0.05, 0.06, 0.08, 1.0)
	art_style.corner_radius_top_left = 3
	art_style.corner_radius_top_right = 3
	art_bg.add_theme_stylebox_override("panel", art_style)
	art_bg.custom_minimum_size = Vector2(0, art_height)
	art_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(art_bg)
	var art: Control
	var icon_scale := maxi(1, floori((art_height - 4) / 16.0))  # 16 px ikon: 64 px alanda 3x, 36 px alanda 2x
	match kind:
		CardOffer.Kind.UNIT:
			art = unit_icon(unit, art_scale)
		CardOffer.Kind.UPGRADE:
			art = _card_icon_rect(card_icon_texture(&"upgrade", upgrade, COLOR_GOLD, COLOR_GOLD), icon_scale)
		CardOffer.Kind.PASSIVE:
			var main := kingdom.color if kingdom else COLOR_PASSIVE
			var accent := kingdom.accent_color if kingdom else COLOR_GOLD
			art = _card_icon_rect(card_icon_texture(&"passive", 0, main, accent), icon_scale)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(art)
	art_bg.add_child(center)
	var line := ColorRect.new()
	line.color = Color(edge, 0.5)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(line)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 6)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 4)
	column.add_child(margin)
	var body := vbox(1)
	margin.add_child(body)
	frame.set_meta("body", body)
	return frame


## card_frame'in metin gövdesi (ad, açıklama, düğme buraya eklenir).
static func card_body(frame: PanelContainer) -> VBoxContainer:
	return frame.get_meta("body")


static func _card_icon_rect(texture: Texture2D, scale: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = texture.get_size() * scale
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## 16x16 piksel kart ikonu, koddan çizilir (Resurrect 64 renkleri). Nearest süzme proje varsayılanıdır.
## type: &"upgrade" (variant: ArmySquad.Upgrade: kılıç / kalkan / artı) ya da &"passive" (mühür, main + accent).
static func card_icon_texture(type: StringName, variant: int, main: Color, accent: Color) -> Texture2D:
	var key := "%s%d%s%s" % [type, variant, main.to_html(), accent.to_html()]
	if _card_icons.has(key):
		return _card_icons[key]
	var image := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	if type == &"passive":
		_draw_seal(image, main, accent)
	else:
		match variant:
			ArmySquad.Upgrade.ATTACK:
				_draw_sword(image)
			ArmySquad.Upgrade.DEFENSE:
				_draw_shield(image)
			_:
				_draw_plus(image)
	_add_outline(image, Color("2e222f"))
	var texture := ImageTexture.create_from_image(image)
	_card_icons[key] = texture
	return texture


## Dolu piksellere komşu boş pikseller koyu kenar olur (8 komşu).
static func _add_outline(image: Image, color: Color) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var edge: Array[Vector2i] = []
	for y in h:
		for x in w:
			if image.get_pixel(x, y).a > 0.0:
				continue
			var touches := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and ny >= 0 and nx < w and ny < h and image.get_pixel(nx, ny).a > 0.0:
						touches = true
			if touches:
				edge.append(Vector2i(x, y))
	for p in edge:
		image.set_pixelv(p, color)


static func _draw_sword(image: Image) -> void:
	var steel := Color("c7dcd0")
	var steel_dark := Color("9babb2")
	var gold := Color("f9c22b")
	var brown := Color("694f62")
	for i in 10:  # bıçak: sol alttan sağ üste, 2 piksel kalın
		image.set_pixel(4 + i, 10 - i, steel_dark)
		image.set_pixel(5 + i, 10 - i, steel)
	for i in 3:  # sap
		image.set_pixel(3 - i, 11 + i, brown)
	image.set_pixel(0, 14, gold)  # topuz
	for d in range(-3, 4):  # siper: bıçağa dik çizgi
		image.set_pixel(4 + d + 1, 10 + d + 1, gold)


static func _draw_shield(image: Image) -> void:
	var rim := Color("c7dcd0")
	var body := Color("4d65b4")
	var light := Color("4d9be6")
	var gold := Color("f9c22b")
	for y in range(2, 15):
		var half := 6 if y <= 8 else 6 - (y - 8)
		half = maxi(half, 1)
		for x in range(8 - half, 8 + half):
			var on_rim := y == 2 or x == 8 - half or x == 8 + half - 1 or y == 14 or half <= 1
			image.set_pixel(x, y, rim if on_rim else (light if x < 8 and y < 8 else body))
	for y in range(4, 12):  # ortada altın dikey şerit
		image.set_pixel(7, y, gold)
		image.set_pixel(8, y, gold)


static func _draw_plus(image: Image) -> void:
	var green := Color("1ebc73")
	var light := Color("91db69")
	var dark := Color("239063")
	for y in range(2, 14):
		for x in range(2, 14):
			if (x >= 6 and x <= 9) or (y >= 6 and y <= 9):
				var c := green
				if x == 6 or y == 6:
					c = light
				elif x == 9 or y == 9:
					c = dark
				image.set_pixel(x, y, c)


## Mühür: krallık renginde daire, açık iç halka, ortada vurgu rengi baklava.
static func _draw_seal(image: Image, main: Color, accent: Color) -> void:
	var rim := main.darkened(0.35)
	var ring := main.lightened(0.3)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length()
			if d <= 6.5:
				image.set_pixel(x, y, rim if d > 5.4 else (ring if d > 4.2 else main))
	for y in range(-3, 4):
		var half := 3 - absi(y)
		for x in range(-half, half + 1):
			image.set_pixel(8 + x, 8 + y, accent)
	image.set_pixel(8, 8, Color.WHITE)
