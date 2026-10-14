extends Control
## Ana ekran: yarım kalan koşuya devam, Hazine (kalıcı geliştirmeler), krallık seçimi.
## Solda 10 krallığın listesi, sağda seçilen krallığın ayrıntıları.
## Kilitli krallıklar seçilip incelenebilir ama onlarla başlanamaz; nasıl açılacağı yazar.

var _detail: VBoxContainer
var _buttons := {}  ## krallık id -> Button
var _selected: KingdomData


func _ready() -> void:
	Audio.play_music("menu")
	RunState.end_run()
	var root := UiKit.screen_root(self, 10)

	var header := UiKit.hbox(10)
	header.add_child(UiKit.label(tr("FETİH"), 22, UiKit.COLOR_GOLD))
	header.add_child(UiKit.label(tr("Açık krallık: %d/%d") % [Profile.unlocked.size(), KingdomCatalog.all().size()],
			10, UiKit.COLOR_MUTED))
	header.add_child(UiKit.spacer())
	header.add_child(UiKit.label(tr("Şan: %d") % Profile.glory, 12, UiKit.COLOR_GOLD))
	header.add_child(UiKit.button(tr("Hazine"), func() -> void: Screens.goto(Screens.TREASURY)))
	header.add_child(UiKit.button(tr("Ayarlar"), func() -> void: SettingsPanel.open(self, true)))
	header.add_child(UiKit.button(tr("Çık"), func() -> void: get_tree().quit()))
	if Profile.has_saved_run():
		header.add_child(UiKit.button(_continue_text(), _on_continue))
	root.add_child(header)

	var body := UiKit.hbox(8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	body.add_child(grid)
	for kingdom in KingdomCatalog.all():
		var unlocked := Profile.is_unlocked(kingdom.id)
		var button := UiKit.button(tr(kingdom.display_name) if unlocked else tr("%s (kilitli)") % tr(kingdom.display_name),
				_select.bind(kingdom))
		button.custom_minimum_size = Vector2(118, 0)
		button.add_theme_color_override("font_color", kingdom.color if unlocked else UiKit.COLOR_MUTED)
		grid.add_child(button)
		_buttons[kingdom.id] = button

	var panel := UiKit.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(panel)
	_detail = UiKit.vbox(3)
	panel.add_child(_detail)

	var stats := Profile.stats
	var footer := tr("Koşu: %d savaş, her %d. savaş boss.   Oynanan koşu: %d   Fetih: %d   En uzun: %d. savaş") % [
			Balance.RUN_LENGTH, Balance.BOSS_EVERY, int(stats.get("runs", 0)),
			int(stats.get("victories", 0)), int(stats.get("best_battle", 0))]
	if Profile.has_saved_run():
		footer = tr("Yeni koşu başlatırsan yarım kalan koşu silinir.   ") + footer
	footer += "   v%s" % ProjectSettings.get_setting("application/config/version")
	root.add_child(UiKit.centered(footer, 9, UiKit.COLOR_MUTED))

	for kingdom in KingdomCatalog.all():
		if Profile.is_unlocked(kingdom.id):
			_select(kingdom)
			break
	Tips.show_once(self, Tips.MENU)


func _continue_text() -> String:
	var data := Profile.saved_run
	var kingdom := KingdomCatalog.get_kingdom(StringName(data.get("kingdom", "")))
	var name := tr(kingdom.display_name) if kingdom else "?"
	return tr("Devam et: %s, savaş %d") % [name, int(data.get("battle_index", 0)) + 1]


func _select(kingdom: KingdomData) -> void:
	_selected = kingdom
	for id in _buttons:
		_buttons[id].button_pressed = false
		_buttons[id].toggle_mode = true
	_buttons[kingdom.id].button_pressed = true
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	_fill_detail(kingdom)


func _fill_detail(kingdom: KingdomData) -> void:
	var unlocked := Profile.is_unlocked(kingdom.id)
	var title := UiKit.hbox(8)
	title.add_child(UiKit.label(tr(kingdom.display_name), 16, kingdom.color if unlocked else UiKit.COLOR_MUTED))
	title.add_child(UiKit.label(tr("Uzmanlık: %s") % UiKit.kingdom_specialty(kingdom), 10, UiKit.COLOR_GOLD))
	_detail.add_child(title)
	if unlocked:
		_detail.add_child(UiKit.kingdom_strip(kingdom))  # ana renk + vurgu rengi şeridi
	_detail.add_child(UiKit.wrapped(tr(kingdom.description), 10))
	for passive in kingdom.starting_passives:
		_detail.add_child(UiKit.wrapped(tr("Özellik: %s - %s") % [tr(passive.display_name), tr(passive.description)],
				9, UiKit.COLOR_GOLD))
	var army: PackedStringArray = []
	for unit in kingdom.starting_units:
		army.append("%d %s" % [UnitCatalog.count_for_budget(unit, Balance.SQUAD_BUDGET), tr(unit.display_name)])
	_detail.add_child(UiKit.wrapped(tr("Başlangıç ordusu: %s") % ", ".join(army), 9))
	var units: PackedStringArray = []
	for unit in UnitCatalog.units_of(kingdom.id):
		units.append("%s (%s)" % [tr(unit.display_name), UiKit.role_name(unit.role)])
	_detail.add_child(UiKit.wrapped(tr("Birlikleri: %s") % ", ".join(units), 9, UiKit.COLOR_MUTED))
	if kingdom.boss:
		_detail.add_child(UiKit.wrapped(tr("Boss: %s (%s)") % [tr(kingdom.boss.display_name),
				UiKit.role_name(kingdom.boss.role)], 9, UiKit.COLOR_MUTED))
	var victories: int = int(Profile.stats.get("kingdom_victories", {}).get(String(kingdom.id), 0))
	if victories > 0:
		_detail.add_child(UiKit.label(tr("Bu krallıkla fetih: %d") % victories, 9, UiKit.COLOR_GOOD))
	_detail.add_child(UiKit.spacer(true))
	if unlocked:
		_detail.add_child(UiKit.button(tr("%s ile başla") % tr(kingdom.display_name), _on_pick.bind(kingdom)))
	else:
		_detail.add_child(UiKit.wrapped(tr("KİLİTLİ. Açmak için: bir koşuda %s boss'unu yen (mühür) ve fethi tamamla.") % tr(kingdom.display_name),
				10, UiKit.COLOR_BAD))


func _on_pick(kingdom: KingdomData) -> void:
	RunState.start_run(kingdom, 0, Profile.run_perks(), Profile.locked_kingdoms())
	Screens.goto(Screens.PREP)


func _on_continue() -> void:
	Screens.resume_saved_run()
