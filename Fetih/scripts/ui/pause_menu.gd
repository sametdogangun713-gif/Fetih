class_name PauseMenu
extends Node
## Duraklatma menüsü: Esc (ya da HUD'daki düğme) oyunu durdurur.
## Devam, Ayarlar, Ana menüye dön. Koşu zaten kayıtlı olduğu için ana menüden "Devam et" ile dönülür.
## Ekranlar kendine bir tane ekler: add_child(PauseMenu.new(not_metni)).
##
## get_tree().paused = true: process_mode'u PAUSABLE olan her şey (savaş, kamera) durur;
## menü ALWAYS modunda çalıştığı için duraklamadayken de tıklanabilir.

var note := ""  ## Menüde gösterilecek kısa bilgi (ör. "bu savaş baştan oynanır").
var _overlay: Overlay


func _init(p_note := "") -> void:
	note = p_note
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if _overlay == null and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		open()


func is_open() -> bool:
	return _overlay != null


func open() -> void:
	if _overlay:
		return
	_overlay = Overlay.new(220.0, true, 15)
	var box := _overlay.content
	var title := UiKit.label(tr("DURAKLATILDI"), 18, UiKit.COLOR_GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	if note != "":
		box.add_child(UiKit.wrapped(note, 9, UiKit.COLOR_MUTED))
	box.add_child(UiKit.button_primary(tr("Devam"), _close))
	box.add_child(UiKit.button(tr("Ayarlar"), func() -> void: SettingsPanel.open(self)))
	box.add_child(UiKit.button(tr("Ana menüye dön"), _to_main_menu))
	_overlay.closed.connect(func() -> void: _overlay = null)
	add_child(_overlay)


func _close() -> void:
	if _overlay:
		_overlay.close()


func _to_main_menu() -> void:
	get_tree().paused = false
	Screens.goto(Screens.MAIN_MENU)
