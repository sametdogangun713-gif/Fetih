extends Control
## Hazırlık ekranı: ordu ızgarası (sürükle-bırak), sıradaki rakip ve ordusu, savaşa başla.

var _grid: GridContainer
var _info: Label


func _ready() -> void:
	if not RunState.active:  # sahne tek başına (F6) çalıştırılırsa deneme koşusu başlat
		RunState.start_run(KingdomCatalog.all()[0], 1)
	var root := UiKit.screen_root(self)
	root.add_child(_top_bar())

	var middle := UiKit.hbox(10)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(middle)
	middle.add_child(_army_column())
	middle.add_child(_opponent_column())

	var bottom := UiKit.hbox()
	bottom.add_child(UiKit.spacer())
	bottom.add_child(UiKit.button(tr("Savaşa başla"), func() -> void: Screens.goto(Screens.BATTLE)))
	root.add_child(bottom)
	_refresh_grid()


func _top_bar() -> Control:
	var bar := UiKit.hbox(16)
	bar.add_child(UiKit.label(tr("Savaş %d / %d") % [RunState.battle_index + 1, RunState.RUN_LENGTH], 13))
	var lives_color := UiKit.COLOR_TEXT if RunState.lives == RunState.START_LIVES else UiKit.COLOR_BAD
	bar.add_child(UiKit.label(tr("Can: %d / %d") % [RunState.lives, RunState.START_LIVES], 13, lives_color))
	bar.add_child(UiKit.spacer())
	bar.add_child(UiKit.label(RunState.kingdom.display_name, 13, RunState.kingdom.color))
	return bar


func _army_column() -> Control:
	var column := UiKit.vbox(3)
	column.add_child(UiKit.label(tr("Ordun"), 13))
	column.add_child(UiKit.label(tr("Ön cephe (rakibe yakın)"), 9, UiKit.COLOR_GOLD))
	_grid = GridContainer.new()
	_grid.columns = RunState.GRID_SIZE.x
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	column.add_child(_grid)
	column.add_child(UiKit.label(tr("Arka saf"), 9, UiKit.COLOR_MUTED))
	var hint := UiKit.wrapped(tr("Bölükleri sürükleyip bırakarak yerlerini değiştir. Tanklar ve savaşçılar önde, okçu ve büyücüler arkada iyi durur."),
			9, UiKit.COLOR_MUTED)
	hint.custom_minimum_size.x = 306
	column.add_child(hint)
	return column


func _opponent_column() -> Control:
	var opponent := RunState.current_opponent()
	var enemy_army := RunState.current_enemy_army()
	var card := UiKit.panel()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiKit.vbox(3)
	card.add_child(box)
	box.add_child(UiKit.label(tr("Sıradaki rakip"), 9, UiKit.COLOR_MUTED))
	box.add_child(UiKit.label(opponent.display_name, 16, opponent.color))
	box.add_child(UiKit.label(tr("Uzmanlık: %s") % UiKit.role_name(opponent.specialty_role),
			10, UiKit.COLOR_GOLD))
	box.add_child(UiKit.label(tr("Rakip ordu: %d bölük") % enemy_army.size(), 10))
	for squad in enemy_army:
		box.add_child(UiKit.label("• %d %s (%s)" % [squad.count, squad.unit.display_name,
				UiKit.role_name(squad.unit.role)], 10, UiKit.COLOR_TEXT))
	box.add_child(UiKit.wrapped(tr("Savaştan sonra %s ordusundan bir birlik seçeceksin (kazanırsan 3, kaybedersen 2 kart).") % opponent.display_name,
			9, UiKit.COLOR_MUTED))
	box.add_child(HSeparator.new())
	_info = UiKit.wrapped(tr("Bir bölüğün üstüne gel: ayrıntıları burada görünür."), 9, UiKit.COLOR_MUTED)
	box.add_child(_info)
	return card


func _refresh_grid() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for y in RunState.GRID_SIZE.y:
		for x in RunState.GRID_SIZE.x:
			var cell := Vector2i(x, y)
			var slot := ArmySlot.new()
			slot.setup(cell, RunState.squad_at(cell))
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
	_info.text = "%s: %d %s (%s)\n%s\n%s" % [tr("Bölük"), squad.count, unit.display_name,
			UiKit.role_name(unit.role), UiKit.unit_stats(unit), ", ".join(UiKit.unit_traits(unit))]
	_info.add_theme_color_override("font_color", UiKit.COLOR_TEXT)
