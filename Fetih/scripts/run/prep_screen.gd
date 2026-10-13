extends Control
## Hazırlık ekranı: ordu ızgarası (sürükle-bırak), fermanlar, sıradaki rakip ve ordusu, savaşa başla.

var _grid: GridContainer
var _info: Label


func _ready() -> void:
	if not RunState.active:  # sahne tek başına (F6) çalıştırılırsa deneme koşusu başlat
		RunState.start_run(KingdomCatalog.all()[0], 1)
	var root := UiKit.screen_root(self)
	root.add_child(_top_bar())
	var map_row := UiKit.hbox()
	map_row.add_child(UiKit.spacer())
	map_row.add_child(RunMap.new())
	map_row.add_child(UiKit.spacer())
	root.add_child(map_row)

	var middle := UiKit.hbox(10)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(middle)
	middle.add_child(_army_column())
	middle.add_child(_opponent_column())

	var bottom := UiKit.hbox()
	bottom.add_child(UiKit.spacer())
	bottom.add_child(UiKit.button(tr("Savaşa başla"), _start_battle))
	root.add_child(bottom)
	_refresh_grid()


func _top_bar() -> Control:
	var bar := UiKit.hbox(16)
	bar.add_child(UiKit.label(tr("Savaş %d / %d") % [RunState.battle_index + 1, Balance.RUN_LENGTH], 13))
	var lives_color := UiKit.COLOR_TEXT if RunState.lives == Balance.START_LIVES else UiKit.COLOR_BAD
	bar.add_child(UiKit.label(tr("Can: %d / %d") % [RunState.lives, Balance.START_LIVES], 13, lives_color))
	bar.add_child(UiKit.spacer())
	bar.add_child(UiKit.label(RunState.kingdom.display_name, 13, RunState.kingdom.color))
	return bar


func _army_column() -> Control:
	var column := UiKit.vbox(3)
	var header := UiKit.hbox(8)
	header.add_child(UiKit.label(tr("Ordun"), 13))
	header.add_child(UiKit.label(tr("Bölük %d/%d   Güç %d") % [RunState.army.size(), Balance.MAX_SQUADS,
			roundi(RunState.army_power(RunState.army))], 10, UiKit.COLOR_MUTED))
	column.add_child(header)
	column.add_child(UiKit.label(tr("Ön cephe (rakibe yakın)"), 9, UiKit.COLOR_GOLD))
	_grid = GridContainer.new()
	_grid.columns = Balance.GRID_SIZE.x
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	column.add_child(_grid)
	column.add_child(UiKit.label(tr("Arka saf"), 9, UiKit.COLOR_MUTED))
	column.add_child(_passives_line())
	column.add_child(UiKit.label(tr("Bölükleri sürükleyip bırakarak yerlerini değiştir."), 9, UiKit.COLOR_MUTED))
	return column


## Alınan fermanlar; üstüne gelince açıklaması görünür.
func _passives_line() -> Control:
	var line := HFlowContainer.new()
	line.custom_minimum_size.x = 306
	line.add_theme_constant_override("h_separation", 6)
	line.add_child(UiKit.label(tr("Fermanlar:"), 9, UiKit.COLOR_MUTED))
	if RunState.passives.is_empty():
		line.add_child(UiKit.label(tr("yok"), 9, UiKit.COLOR_MUTED))
	for passive in RunState.passives:
		var tag := UiKit.label(passive.display_name, 9, UiKit.COLOR_GOLD)
		tag.tooltip_text = passive.description
		tag.mouse_filter = Control.MOUSE_FILTER_PASS  # etiketler normalde fareyi yok sayar
		line.add_child(tag)
	return line


func _opponent_column() -> Control:
	var opponent := RunState.current_opponent()
	var enemy_army := RunState.current_enemy_army()
	var card := UiKit.panel()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiKit.vbox(3)
	card.add_child(box)
	if RunState.is_final_battle():
		box.add_child(UiKit.label(tr("BÜYÜK FETİH - kazanmak zorundasın"), 10, UiKit.COLOR_BAD))
	elif RunState.is_boss_battle():
		box.add_child(UiKit.label(tr("BOSS SAVAŞI - yenersen +1 can ve ferman"), 10, UiKit.COLOR_GOLD))
	else:
		box.add_child(UiKit.label(tr("Sıradaki rakip"), 9, UiKit.COLOR_MUTED))
	var title := UiKit.hbox(8)
	title.add_child(UiKit.label(opponent.display_name, 16, opponent.color))
	title.add_child(UiKit.label(tr("Güç %d") % roundi(RunState.army_power(enemy_army)), 10, UiKit.COLOR_MUTED))
	box.add_child(title)
	box.add_child(UiKit.label(tr("Uzmanlık: %s") % UiKit.role_name(opponent.specialty_role),
			10, UiKit.COLOR_GOLD))
	for squad in enemy_army:
		if squad.unit.is_boss:
			box.add_child(UiKit.label("• %s %s (%s)" % [tr("BOSS:"), squad.unit.display_name,
					UiKit.role_name(squad.unit.role)], 10, UiKit.COLOR_GOLD))
		else:
			box.add_child(UiKit.label("• %d %s (%s)  %s" % [squad.count, squad.unit.display_name,
					UiKit.role_name(squad.unit.role), UiKit.level_text(squad)], 10))
	var fermans := RunState.enemy_passives()
	if not fermans.is_empty():
		var names: PackedStringArray = []
		for passive in fermans:
			names.append(passive.display_name)
		box.add_child(UiKit.wrapped(tr("Fermanları: %s") % ", ".join(names), 9, UiKit.COLOR_GOLD))
	box.add_child(UiKit.wrapped(tr("Savaştan sonra %s ordusundan kart seçeceksin (kazanırsan 3, kaybedersen 2).") % opponent.display_name,
			9, UiKit.COLOR_MUTED))
	box.add_child(HSeparator.new())
	_info = UiKit.wrapped(tr("Bir bölüğün üstüne gel: ayrıntıları burada görünür."), 9, UiKit.COLOR_MUTED)
	box.add_child(_info)
	return card


func _refresh_grid() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for y in Balance.GRID_SIZE.y:
		for x in Balance.GRID_SIZE.x:
			var cell := Vector2i(x, y)
			var squad := RunState.squad_at(cell)
			var slot := ArmySlot.new()
			slot.setup(cell, squad, squad != null and squad == RunState.last_changed)
			slot.squad_moved.connect(_on_squad_moved)
			slot.mouse_entered.connect(_show_info.bind(cell))
			_grid.add_child(slot)


func _on_squad_moved(from: Vector2i, to: Vector2i) -> void:
	RunState.move_squad(from, to)
	# Bırakma işlemi bir karenin içinden geliyor; kareleri o işlem bittikten sonra yeniden kur.
	_refresh_grid.call_deferred()


func _show_info(cell: Vector2i) -> void:
	var squad := RunState.squad_at(cell)
	if squad == null:
		return
	var unit := squad.unit
	var lines: PackedStringArray = []
	lines.append("%d %s (%s)  %s  %s" % [squad.count, unit.display_name, UiKit.role_name(unit.role),
			UiKit.level_text(squad), tr("Güç %d") % roundi(squad.power())])
	lines.append(tr("Saldırı %d · Savunma %d · Takviye %d") % [squad.attack_level, squad.defense_level,
			squad.reinforce_level])
	lines.append(UiKit.unit_stats(unit))
	lines.append(", ".join(UiKit.unit_traits(unit)))
	for passive in RunState.passives:
		if passive.applies_to(squad, Balance.GRID_SIZE):
			lines.append(tr("Ferman: %s") % passive.display_name)
	_info.text = "\n".join(lines)
	_info.add_theme_color_override("font_color", UiKit.COLOR_TEXT)


func _start_battle() -> void:
	RunState.last_changed = null
	Screens.goto(Screens.BATTLE)
