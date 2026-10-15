extends Control
## Krallık seçimi (renkli fantastik): arkada soluk menü manzarası, üstte 10 krallığın dalgalanan sancağı,
## altta seçilen krallığın canlı dioraması ve bilgi kartı, büyük "Başla" düğmesi.
## Kilitli krallıklar seçilip incelenebilir ama onlarla başlanamaz; kartta nasıl açılacağı yazar.
## Klavye: ←/→ krallık değiştirir, Enter başlar, Esc ana menüye döner.
## Godot: kart içeriği her seçimde yeniden kurulur (eski düğümler queue_free), fade_in ile belirir.

const CARD_WIDTH := 232.0

var _banners: Array[KingdomBanner] = []
var _diorama: KingdomDiorama
var _card_box: VBoxContainer
var _start: Button
var _selected: KingdomData
var _starting := false  ## Başla basıldı, sahne değişiyor.


func _ready() -> void:
	Audio.play_music("menu")
	RunState.end_run()
	theme = UiKit.theme_menu()
	var backdrop := MenuBackdrop.new()
	backdrop.dim = 0.55
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	add_child(margin)
	var root := UiKit.vbox(6)
	margin.add_child(root)
	root.add_child(_header())
	var row := UiKit.hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(row)
	for kingdom in KingdomCatalog.all():
		var banner := KingdomBanner.new(kingdom, Profile.is_unlocked(kingdom.id))
		banner.picked.connect(select)
		row.add_child(banner)
		_banners.append(banner)
	var body := UiKit.hbox(8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var frame := UiKit.menu_panel()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame_style: StyleBoxFlat = frame.get_theme_stylebox("panel")
	frame_style.set_content_margin_all(3)
	body.add_child(frame)
	_diorama = KingdomDiorama.new()
	frame.add_child(_diorama)
	var card := UiKit.menu_panel()
	card.custom_minimum_size.x = CARD_WIDTH
	body.add_child(card)
	var card_column := UiKit.vbox(4)
	card.add_child(card_column)
	_card_box = UiKit.vbox(3)
	_card_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_column.add_child(_card_box)
	_start = UiKit.button_primary("", _on_start)
	_start.custom_minimum_size.y = 26
	UiKit.set_font_size(_start, 13)
	_start.add_theme_font_override("font", UiKit.ui_font(800))
	card_column.add_child(_start)
	for kingdom in KingdomCatalog.all():
		if Profile.is_unlocked(kingdom.id):
			select(kingdom)
			break
	Tips.show_once(self, Tips.MENU)


func _header() -> Control:
	var header := UiKit.hbox(8)
	var back := UiKit.button_ghost(tr("Geri"), func() -> void: Screens.goto(Screens.MAIN_MENU))
	_outlined(back)
	back.custom_minimum_size.x = 64
	header.add_child(back)
	header.add_child(UiKit.spacer())
	var title := UiKit.label(tr("KRALLIĞINI SEÇ"), 18, UiKit.COLOR_GOLD, true)
	title.add_theme_color_override("font_outline_color", Color("2e222f"))
	title.add_theme_constant_override("outline_size", 5)
	header.add_child(title)
	header.add_child(UiKit.spacer())
	var glory := UiKit.label(tr("Şan: %d") % Profile.glory, 12, UiKit.COLOR_GOLD)
	glory.add_theme_color_override("font_outline_color", Color("2e222f"))
	glory.add_theme_constant_override("outline_size", 3)
	glory.custom_minimum_size.x = 64
	glory.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(glory)
	return header


static func _outlined(button: Button) -> void:
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, UiKit.COLOR_PARCHMENT)
	button.add_theme_color_override("font_outline_color", Color("2e222f"))
	button.add_theme_constant_override("outline_size", 3)


func selected() -> KingdomData:
	return _selected


func banners() -> Array[KingdomBanner]:
	return _banners


func start_button() -> Button:
	return _start


func select(kingdom: KingdomData) -> void:
	if kingdom == _selected:
		return
	var all := KingdomCatalog.all()
	var direction := 0
	if _selected != null:
		direction = 1 if all.find(kingdom) > all.find(_selected) else -1
	_selected = kingdom
	for banner in _banners:
		banner.selected = banner.kingdom == kingdom
	var unlocked := Profile.is_unlocked(kingdom.id)
	_diorama.show_kingdom(kingdom, unlocked, direction)
	_fill_card(kingdom, unlocked)
	_start.disabled = not unlocked
	_start.text = tr("%s ile başla") % tr(kingdom.display_name) if unlocked else tr("Kilitli")


func _fill_card(kingdom: KingdomData, unlocked: bool) -> void:
	for child in _card_box.get_children():
		_card_box.remove_child(child)
		child.queue_free()
	var ink_name := kingdom.color.darkened(0.35) if unlocked else UiKit.COLOR_MUTED.darkened(0.3)
	_card_box.add_child(UiKit.label(tr(kingdom.display_name), 20, ink_name, true))
	var badge := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = kingdom.color.darkened(0.15) if unlocked else UiKit.COLOR_MUTED
	badge_style.set_corner_radius_all(4)
	badge_style.content_margin_left = 6
	badge_style.content_margin_right = 6
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.add_child(UiKit.label(tr("Uzmanlık: %s") % UiKit.kingdom_specialty(kingdom), 9, Color.WHITE))
	_card_box.add_child(badge)
	var desc := UiKit.wrapped(tr(kingdom.description), 10, UiKit.COLOR_INK)
	desc.max_lines_visible = 3
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.tooltip_text = tr(kingdom.description)
	desc.mouse_filter = Control.MOUSE_FILTER_PASS
	_card_box.add_child(desc)
	for passive in kingdom.starting_passives:
		var line := UiKit.hbox(4)
		var seal := TextureRect.new()
		seal.texture = UiKit.card_icon_texture(&"passive", 0, kingdom.color, kingdom.accent_color)
		seal.custom_minimum_size = Vector2(14, 14)
		seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		line.add_child(seal)
		line.add_child(UiKit.label(tr(passive.display_name), 10, UiKit.COLOR_INK.lightened(0.1)))
		line.tooltip_text = "%s\n%s" % [tr(passive.display_name), tr(passive.description)]
		line.mouse_filter = Control.MOUSE_FILTER_PASS
		_card_box.add_child(line)
	_card_box.add_child(UiKit.label(tr("Birlikleri"), 9, UiKit.COLOR_INK.lightened(0.35)))
	var units := HFlowContainer.new()
	units.add_theme_constant_override("h_separation", 4)
	for unit in UnitCatalog.units_of(kingdom.id):
		var icon := UiKit.unit_icon(unit, 1)
		icon.custom_minimum_size = icon.custom_minimum_size.min(Vector2(20, 20))
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		icon.tooltip_text = "%s (%s)" % [tr(unit.display_name), UiKit.role_name(unit.role)]
		if not unlocked:
			icon.modulate = Color(0, 0, 0, 0.7)
		units.add_child(icon)
	if kingdom.boss:
		var boss := UiKit.unit_icon(kingdom.boss, 1)
		boss.custom_minimum_size = boss.custom_minimum_size.min(Vector2(20, 20))
		boss.mouse_filter = Control.MOUSE_FILTER_PASS
		boss.tooltip_text = tr("Boss: %s (%s)") % [tr(kingdom.boss.display_name), UiKit.role_name(kingdom.boss.role)]
		if not unlocked:
			boss.modulate = Color(0, 0, 0, 0.7)
		units.add_child(boss)
	_card_box.add_child(units)
	var victories: int = int(Profile.stats.get("kingdom_victories", {}).get(String(kingdom.id), 0))
	if victories > 0:
		_card_box.add_child(UiKit.label(tr("Bu krallıkla fetih: %d") % victories, 9, Color("239063")))
	if not unlocked:
		var lock := UiKit.wrapped(tr("Açmak için: bir koşuda %s boss'unu yen ve fethi tamamla.") % tr(kingdom.display_name),
				9, Color("ae2334"))
		_card_box.add_child(lock)
	for child in _card_box.get_children():
		UiKit.fade_in(child as CanvasItem, 0.0, 0.18)


func _unhandled_input(event: InputEvent) -> void:
	var all := KingdomCatalog.all()
	if event.is_action_pressed("ui_right"):
		select(all[(all.find(_selected) + 1) % all.size()])
	elif event.is_action_pressed("ui_left"):
		select(all[(all.find(_selected) - 1 + all.size()) % all.size()])
	elif event.is_action_pressed("ui_accept"):
		_on_start()
	elif event.is_action_pressed("ui_cancel"):
		Screens.goto(Screens.MAIN_MENU)
	else:
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _on_start() -> void:
	if _starting or _selected == null or not Profile.is_unlocked(_selected.id):
		return
	_starting = true  # çift tık / Enter koşuyu iki kez başlatmasın
	RunState.start_run(_selected, 0, Profile.run_perks(), Profile.locked_kingdoms())
	Screens.next_phase = "prep"
	Screens.goto(Screens.MEYDAN)
