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

static var _theme: Theme


## Ekranların kök düğümüne verilir; tüm alt düğümler bu yazı boyutunu kullanır.
static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font_size = FONT_SIZE
	return _theme


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
	return b


## Düğme sesi. Audio autoload'una düğüm yolundan ulaşılır: araç scriptleri (-s) UiKit'i
## autoload'lar kurulmadan derler, doğrudan "Audio" adı orada derleme hatası verir.
static func click_sound() -> void:
	var audio := (Engine.get_main_loop() as SceneTree).root.get_node_or_null(^"Audio")
	if audio:
		audio.play("click", -2.0, 0.05)


## Birliğin sprite'ı (durma karesi), piksel sanat bozulmasın diye tam sayı katıyla büyütülür.
static func unit_icon(unit: UnitData, scale := 2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = UnitSprites.icon(unit)
	icon.custom_minimum_size = icon.texture.get_size() * scale
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


static func panel(color := COLOR_PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(6)
	p.add_theme_stylebox_override("panel", style)
	return p


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
## Çeviri dosyası (İngilizce) Aşama 10'da eklenecek; o zamana kadar metni aynen döndürür.
static func t(text: String) -> String:
	return TranslationServer.translate(text)


static func num(value: float) -> String:
	return String.num(value, 2)


static func unit_stats(unit: UnitData) -> String:
	return t("Can %s   Hasar %s   Saldırı %s/sn\nMenzil %s   Hız %s   Zırh %s") % [
			num(unit.hp), num(unit.damage), num(unit.attack_speed),
			num(unit.attack_range), num(unit.move_speed), num(unit.armor)]


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
