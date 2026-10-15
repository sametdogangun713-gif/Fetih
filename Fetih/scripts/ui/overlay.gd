class_name Overlay
extends CanvasLayer
## Ekranın üstüne açılan pencere: arkayı karartır, ortada bir panel gösterir.
## Ayarlar, duraklatma menüsü ve ipuçları bunu kullanır.
##
## CanvasLayer: içindeki arayüz kameradan ve alttaki sahneden bağımsız, her zaman üstte çizilir.
## process_mode ALWAYS: oyun duraklatılmışken (get_tree().paused) de çalışır.
## pause_tree açıksa pencere açıkken oyun durur, kapanınca (başkası durdurmadıysa) devam eder.

signal closed

var content: VBoxContainer  ## Panelin içi; çağıran doldurur.
var close_on_cancel := true  ## Esc pencereyi kapatsın mı.

var _pause_tree := false
var _panel: PanelContainer
var _dim: ColorRect
var _paused_by_me := false  ## Oyunu bu pencere durdurdu (kapanınca o devam ettirir).


func _init(width := 300.0, pause_tree := false, layer_index := 10) -> void:
	layer = layer_index
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiKit.theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # arkadaki düğmelere tıklanamasın
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := UiKit.game_panel(0.95)
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	style.border_color = Color(UiKit.COLOR_GOLD, 0.6)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.custom_minimum_size.x = width
	center.add_child(panel)
	_panel = panel
	_dim = dim
	content = UiKit.vbox(6)
	panel.add_child(content)
	_pause_tree = pause_tree


## Açılış: karartma solar, panel küçükten "zıplayarak" gelir (yerleşim bir kare sonra biter).
func _ready() -> void:
	UiKit.fade_in(_dim, 0.0, 0.15)
	_panel.modulate.a = 0.0
	await get_tree().process_frame
	if is_instance_valid(_panel):
		UiKit.fade_in(_panel, 0.0, 0.15)
		UiKit.pop(_panel, 0.22)


func _enter_tree() -> void:
	# Oyun zaten durmuşsa (ör. duraklatma menüsünden açılan ayarlar) kapanınca açmak bizim işimiz değil.
	if _pause_tree and not get_tree().paused:
		get_tree().paused = true
		_paused_by_me = true


func _unhandled_input(event: InputEvent) -> void:
	if close_on_cancel and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if is_queued_for_deletion():
		return
	if _paused_by_me:
		get_tree().paused = false
	closed.emit()
	queue_free()
