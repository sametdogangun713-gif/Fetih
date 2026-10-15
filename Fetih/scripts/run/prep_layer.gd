class_name PrepLayer
extends CanvasLayer
## Hazırlık katmanı: sol üstte kalpler, üst ortada aşama göstergesi, sol bilgi paneli, "Savaşa başla".
## Bölükler alanda sürüklenir: sol tıkla tut, bırak. Sürüklerken bant adı (ön/orta/arka) görünür.
## Godot: CanvasLayer ekrana sabit çizilir (kamerayla kaymaz); fare olayları _input / _unhandled_input ile alınır.

signal start_pressed

const SIDE_WIDTH := 132.0  ## Sol panelin genişliği (640 px'lik ekranda küçük kalsın).

var dragging := -1  ## Sürüklenen bölüğün ordu sırası; -1 yok.
var _meydan: Node
var hover_card: PanelContainer  ## Fare altındaki bölüğün kartı (imlecin yanında).
var _hover_index := -1
var _hearts: LivesHearts
var _progress: RunProgress
var _band_label: Label
var _drag_from := Vector2.ZERO
var _mouse := Vector2.ZERO  ## Son fare olayının ekran konumu (bant etiketi için).


func setup(meydan: Node) -> void:
	_meydan = meydan
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()  # CanvasLayer bir Control değil: tema ebeveynden gelmez, kök Control'e verilir
	add_child(root)
	# Üst satır: solda kalpler, ortada aşama göstergesi; ekranın geri kalanı alana kalır.
	var top := run_header()
	_hearts = top.get_meta("hearts")
	_progress = top.get_meta("progress")
	root.add_child(top)
	# Sol bilgi paneli: yarı saydam, dar; rakip kartı ve fermanlar.
	var side := UiKit.game_panel(0.78)
	side.set_anchors_preset(Control.PRESET_TOP_LEFT)
	side.position = Vector2(6, 30)
	side.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	root.add_child(side)
	var box := UiKit.vbox(3)
	side.add_child(box)
	SquadInfo.fill_opponent(box, SIDE_WIDTH - 12.0)
	box.add_child(HSeparator.new())
	box.add_child(SquadInfo.passives_line(SIDE_WIDTH - 12.0))
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
	# Çim ve birliklerin üstünde okunsun: koyu kenar çizgisi.
	_band_label.add_theme_color_override("font_outline_color", UiKit.COLOR_BG)
	_band_label.add_theme_constant_override("outline_size", 4)
	root.add_child(_band_label)
	hover_card = PanelContainer.new()  # show_hover içeriğini doldurur
	hover_card.visible = false
	hover_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hover_card)


func refresh() -> void:
	dragging = -1
	_band_label.visible = false
	show_hover(-1)
	_hearts.set_lives(RunState.lives, false)
	_progress.refresh()


## Üst satır (hazırlık ve savaş HUD'u ortak): sol üstte kalpler, ortada aşama göstergesi.
## Parçalar set_meta ile iliştirilir ("hearts", "progress"): çağıran günceller.
static func run_header() -> HBoxContainer:
	var top := UiKit.hbox(10)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = 6
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hearts := LivesHearts.new(RunState.lives, RunState.max_lives)
	top.add_child(hearts)
	var left_pad := UiKit.spacer()
	left_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(left_pad)
	var progress := RunProgress.new()
	top.add_child(progress)
	var right_pad := UiKit.spacer()
	right_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(right_pad)
	var balance := Control.new()  # sağda kalp genişliği kadar boşluk: gösterge tam ortada kalsın
	balance.custom_minimum_size = hearts.custom_minimum_size
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(balance)
	top.set_meta("hearts", hearts)
	top.set_meta("progress", progress)
	return top


## Sürükleme aşaması _input'ta: sol panelin üstünde bırakılan düğme de yakalanır (GUI olayı yutamaz).
func _input(event: InputEvent) -> void:
	if not visible or dragging < 0:
		return
	var field: Battlefield = _meydan.battlefield
	if event is InputEventMouse:
		_mouse = event.position
	if event is InputEventMouseMotion:
		_move_view(dragging, Formation.clamp_deploy(Formation.field_to_deploy(field.event_field(event))))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		drop_at(field.event_field(event))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel_drag()
		get_viewport().set_input_as_handled()  # duraklatma menüsü açılmasın: ESC sadece sürüklemeyi iptal eder


func _unhandled_input(event: InputEvent) -> void:
	if not visible or dragging >= 0:
		return
	var field: Battlefield = _meydan.battlefield
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var index: int = _meydan.player_index_at(field.event_field(event))
		if index >= 0:
			begin_drag(index)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_mouse = event.position
		show_hover(_meydan.player_index_at(field.event_field(event)))


## Fare altındaki bölüğün kartı imlecin sağ altında (ekran dışına taşmaz); index < 0 gizler.
func show_hover(index: int) -> void:
	if index < 0 or index >= RunState.army.size():
		hover_card.visible = false
		_hover_index = -1
		return
	if index != _hover_index:
		_hover_index = index
		var parent := hover_card.get_parent()
		var fresh := SquadInfo.squad_card(RunState.army[index])
		parent.remove_child(hover_card)
		hover_card.queue_free()
		hover_card = fresh
		parent.add_child(hover_card)
	hover_card.visible = true
	hover_card.reset_size()
	var screen := hover_card.get_viewport_rect().size
	var at := _mouse + Vector2(12, 12)
	at.x = minf(at.x, screen.x - hover_card.size.x - 4)
	at.y = minf(at.y, screen.y - hover_card.size.y - 4)
	hover_card.position = at


func begin_drag(index: int) -> void:
	show_hover(-1)
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
		_band_label.position = _mouse + Vector2(10, -14)
