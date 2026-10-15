class_name UiKit
## Arayüz yardımcıları: bütün ekranlar aynı yazı boyutunu, renkleri ve kutuları kullansın.
## Gerçek arayüz çizimleri gelince (Aşama 9) bu dosya bir Theme kaynağına dönüşecek.

const FONT_SIZE := 11
const COLOR_BG := Color("1a1714")
const COLOR_PANEL := Color("2a2622")
const COLOR_SLOT_EMPTY := Color("211e1b")
const COLOR_TEXT := Color("e8e2d0")
const COLOR_MUTED := Color("9a9484")
const COLOR_GOOD := Color("8fd47f")
const COLOR_BAD := Color("e06a5a")
const COLOR_GOLD := Color("e8c25a")

## Panel ve düğme kenarı (Resurrect 64 gri-mor): 9 Kings tarzı koyu kutu, ince açık kenar.
const COLOR_EDGE := Color("625565")
## Piksel yazı tipi (varsa). Dosya yoksa Godot'un varsayılan yazı tipi kullanılır.
const FONT_PATH := "res://assets/fonts/pixel.ttf"

static var _theme: Theme


## Ekranların kök düğümüne verilir; tüm alt düğümler bu yazı boyutunu, kutuları ve düğmeleri kullanır.
## Godot: Theme, Control'lere tür adına göre (Button, PanelContainer...) stil verir; alt düğümler
## temayı ebeveynden devralır, bu yüzden kökteki tek tema bütün ekranı boyar.
static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font_size = FONT_SIZE
		if ResourceLoader.exists(FONT_PATH):
			var font: FontFile = load(FONT_PATH)
			font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			font.hinting = TextServer.HINTING_NONE
			font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			_theme.default_font = font
		var box := panel_style(COLOR_PANEL)
		_theme.set_stylebox("panel", "PanelContainer", box)
		_theme.set_stylebox("panel", "Panel", box)
		_theme.set_stylebox("panel", "TooltipPanel", panel_style(COLOR_BG, 4))
		_theme.set_stylebox("normal", "Button", _button_style(COLOR_PANEL, COLOR_EDGE))
		_theme.set_stylebox("hover", "Button", _button_style(COLOR_PANEL.lightened(0.08), COLOR_GOLD))
		_theme.set_stylebox("pressed", "Button", _button_style(COLOR_BG, COLOR_GOLD))
		_theme.set_stylebox("disabled", "Button", _button_style(COLOR_BG, COLOR_EDGE.darkened(0.4)))
		_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
		_theme.set_color("font_color", "Button", COLOR_TEXT)
		_theme.set_color("font_hover_color", "Button", COLOR_GOLD)
		_theme.set_color("font_pressed_color", "Button", COLOR_GOLD)
		_theme.set_color("font_disabled_color", "Button", COLOR_MUTED.darkened(0.3))
	return _theme


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
static func screen_root(screen: Control, margin := 10) -> VBoxContainer:
	screen.theme = theme()
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


static func label(text: String, size := FONT_SIZE, color := COLOR_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
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


static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(click_sound)
	b.pressed.connect(on_pressed)
	b.mouse_entered.connect(hover_scale.bind(b, true))
	b.mouse_exited.connect(hover_scale.bind(b, false))
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


static func panel(color := COLOR_PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(color))
	return p


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
	var style := panel_style(COLOR_PANEL, 2)  # iç boşluk = kenar kalınlığı: içerik kenarı örtmesin
	style.set_border_width_all(2)
	style.border_color = edge
	frame.add_theme_stylebox_override("panel", style)
	var column := vbox(0)
	frame.add_child(column)
	# Resim alanı: koyu zemin, ortalanmış resim, altında tür renginde 1 px çizgi.
	var art_bg := ColorRect.new()
	art_bg.color = COLOR_SLOT_EMPTY
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
	line.color = edge
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
