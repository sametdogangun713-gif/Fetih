extends Control
## Hazırlık ekranı: ordu ızgarası (sürükle-bırak), fermanlar, sıradaki rakip ve ordusu, savaşa başla.

var _grid: GridContainer
var _info: Label


func _ready() -> void:
	Audio.play_music("menu")
	if not RunState.active:  # sahne tek başına (F6) çalıştırılırsa deneme koşusu başlat
		RunState.start_run(KingdomCatalog.all()[0], 1)
	Profile.store_run(RunState.to_dict("prep"))  # oyun kapanırsa buradan devam edilir
	var root := UiKit.screen_root(self)
	root.add_child(SquadInfo.top_bar())
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
	add_child(PauseMenu.new(tr("Koşun kayıtlı: ana menüden \"Devam et\" ile buraya dönersin.")))
	Tips.show_once(self, Tips.PREP)


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
	column.add_child(SquadInfo.passives_line())
	column.add_child(UiKit.label(tr("Bölükleri sürükleyip bırakarak yerlerini değiştir."), 9, UiKit.COLOR_MUTED))
	return column


func _opponent_column() -> Control:
	var card := UiKit.panel()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiKit.vbox(3)
	card.add_child(box)
	SquadInfo.fill_opponent(box)
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
	_info.text = SquadInfo.squad_details(squad)
	_info.add_theme_color_override("font_color", UiKit.COLOR_TEXT)


func _start_battle() -> void:
	RunState.last_changed = null
	# Savaş başlarken kaydedilir: oyundan çıkıp dönen oyuncu dizilişi değiştiremeden
	# aynı savaşa döner (savaş deterministik; kaybedilen savaşı tekrar denemek mümkün olmaz).
	Profile.store_run(RunState.to_dict("battle"))
	Screens.goto(Screens.BATTLE)
