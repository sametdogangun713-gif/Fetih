class_name PrepLayer
extends CanvasLayer
## Hazırlık katmanı: üst şerit (savaş, can, krallık, harita), sol bilgi paneli, "Savaşa başla".
## Bölükler alanda sürüklenir: sol tıkla tut, bırak. Sürüklerken bant adı (ön/orta/arka) görünür.
## Godot: CanvasLayer ekrana sabit çizilir (kamerayla kaymaz); fare olayları _input / _unhandled_input ile alınır.

signal start_pressed

const SIDE_WIDTH := 150.0  ## Sol panelin genişliği (640 px'lik ekranda küçük kalsın).

var dragging := -1  ## Sürüklenen bölüğün ordu sırası; -1 yok.
var _meydan: Node
var _info: Label
var _band_label: Label
var _drag_from := Vector2.ZERO


func setup(meydan: Node) -> void:
	_meydan = meydan
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()  # CanvasLayer bir Control değil: tema ebeveynden gelmez, kök Control'e verilir
	add_child(root)
	# Üst şerit + harita: köşelerde az arayüz; ortası boş kalır.
	var top := UiKit.vbox(2)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 6
	top.offset_right = -6
	top.offset_top = 4
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	top.add_child(SquadInfo.top_bar())
	var map_row := UiKit.hbox()
	map_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_row.add_child(UiKit.spacer())
	map_row.add_child(RunMap.new())
	map_row.add_child(UiKit.spacer())
	top.add_child(map_row)
	# Sol bilgi paneli: yarı saydam, dar; rakip özeti, fermanlar ve fare altındaki bölüğün ayrıntısı.
	var side := UiKit.panel(Color(UiKit.COLOR_PANEL, 0.78))
	side.set_anchors_preset(Control.PRESET_TOP_LEFT)
	side.position = Vector2(6, 62)
	side.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	root.add_child(side)
	var box := UiKit.vbox(3)
	side.add_child(box)
	SquadInfo.fill_opponent(box, SIDE_WIDTH - 12.0)
	box.add_child(HSeparator.new())
	box.add_child(SquadInfo.passives_line(SIDE_WIDTH - 12.0))
	_info = UiKit.wrapped(tr("Bir bölüğün üstüne gel: ayrıntıları burada görünür."), 9, UiKit.COLOR_MUTED)
	_info.custom_minimum_size.x = SIDE_WIDTH - 12.0
	box.add_child(_info)
	var start := UiKit.button(tr("Savaşa başla"), func() -> void: start_pressed.emit())
	start.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	start.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	start.grow_vertical = Control.GROW_DIRECTION_BEGIN
	start.offset_right = -8
	start.offset_bottom = -8
	root.add_child(start)
	_band_label = UiKit.label("", 10, UiKit.COLOR_GOLD)
	_band_label.visible = false
	_band_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_band_label)


func refresh() -> void:
	dragging = -1
	_band_label.visible = false


## Sürükleme aşaması _input'ta: sol panelin üstünde bırakılan düğme de yakalanır (GUI olayı yutamaz).
func _input(event: InputEvent) -> void:
	if not visible or dragging < 0:
		return
	var field: Battlefield = _meydan.battlefield
	if event is InputEventMouseMotion:
		_move_view(dragging, Formation.clamp_deploy(Formation.field_to_deploy(field.mouse_field())))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		drop_at(field.mouse_field())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel_drag()
		get_viewport().set_input_as_handled()  # duraklatma menüsü açılmasın: ESC sadece sürüklemeyi iptal eder


func _unhandled_input(event: InputEvent) -> void:
	if not visible or dragging >= 0:
		return
	var field: Battlefield = _meydan.battlefield
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var index: int = _meydan.player_index_at(field.mouse_field())
		if index >= 0:
			begin_drag(index)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var index: int = _meydan.player_index_at(field.mouse_field())
		if index >= 0:
			_info.text = SquadInfo.squad_details(RunState.army[index])
			_info.add_theme_color_override("font_color", UiKit.COLOR_TEXT)


func begin_drag(index: int) -> void:
	dragging = index
	_drag_from = RunState.army[index].pos


## Bölüğü bırakılan yere oturtur: bölge dışı sınıra kenetlenir, dolu yerde en yakın boş noktaya kayar.
func drop_at(field_pos: Vector2) -> void:
	if dragging < 0:
		return
	var squad: ArmySquad = RunState.army[dragging]
	var pos := RunState.move_squad_to(squad, Formation.field_to_deploy(field_pos))
	var index := dragging
	dragging = -1
	_band_label.visible = false
	_move_view(index, pos)
	Audio.play("card")
	Profile.store_run(RunState.to_dict("prep"))


## Sürüklemeyi iptal eder: bölük eski yerine döner (kayıtlı konum zaten hiç değişmedi).
func cancel_drag() -> void:
	if dragging < 0:
		return
	var index := dragging
	dragging = -1
	_band_label.visible = false
	_move_view(index, _drag_from)


## Görüntüyü yerleşim koordinatına taşır (sadece görüntü; kayıtlı konum drop_at'ta değişir).
func _move_view(index: int, deploy_pos: Vector2) -> void:
	var view: SquadView = _meydan.player_views()[index]
	var p := Formation.deploy_to_field(deploy_pos, SquadState.Team.PLAYER)
	view.squad.position = p
	view.squad.previous_position = p
	view.update_visual(1.0, 0.0)
	_band_label.visible = dragging >= 0
	if dragging >= 0:
		_band_label.text = UiKit.band_name(ArmySquad.band_of(deploy_pos.y))
		_band_label.position = _band_label.get_parent().get_local_mouse_position() + Vector2(10, -14)
