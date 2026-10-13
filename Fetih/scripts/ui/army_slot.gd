class_name ArmySlot
extends PanelContainer
## Ordu ızgarasında bir kare. Godot'nun yerleşik sürükle-bırak sistemini kullanır:
## _get_drag_data (sürükleme başlar), _can_drop_data (buraya bırakılabilir mi), _drop_data (bırakıldı).

signal squad_moved(from: Vector2i, to: Vector2i)

const SLOT_SIZE := Vector2(100, 44)

var cell: Vector2i
var squad: ArmySquad  ## Boş karede null.


## highlighted: son kartla eklenen/yükseltilen bölük (altın çerçeve).
func setup(p_cell: Vector2i, p_squad: ArmySquad, highlighted := false) -> void:
	cell = p_cell
	squad = p_squad
	custom_minimum_size = SLOT_SIZE

	var style := StyleBoxFlat.new()
	style.set_content_margin_all(4)
	style.set_border_width_all(1)
	if squad:
		style.bg_color = UiKit.COLOR_PANEL
		style.border_color = UiKit.COLOR_GOLD if highlighted else squad.unit.placeholder_color
		style.border_width_left = 4
		if highlighted:
			style.set_border_width_all(2)
			style.border_width_left = 4
	else:
		style.bg_color = UiKit.COLOR_SLOT_EMPTY
		style.border_color = Color(1, 1, 1, 0.08)
	add_theme_stylebox_override("panel", style)

	var box := UiKit.vbox(0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE  # sürükleme kareye ulaşsın
	add_child(box)
	if squad:
		box.add_child(UiKit.label(squad.unit.display_name, 10))
		var line := UiKit.hbox(4)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(UiKit.label("%d · %s" % [squad.count, UiKit.role_name(squad.unit.role)],
				9, UiKit.COLOR_MUTED))
		line.add_child(UiKit.spacer())
		line.add_child(UiKit.label(UiKit.level_text(squad), 9,
				UiKit.COLOR_GOLD if squad.level() > 1 else UiKit.COLOR_MUTED))
		box.add_child(line)
	else:
		box.add_child(UiKit.label(tr("boş"), 9, Color(1, 1, 1, 0.2)))


func _get_drag_data(_at_position: Vector2) -> Variant:
	if squad == null:
		return null
	set_drag_preview(UiKit.label("%d %s" % [squad.count, squad.unit.display_name], 11,
			squad.unit.placeholder_color))
	return {"from_cell": cell}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("from_cell") and data["from_cell"] != cell


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	squad_moved.emit(data["from_cell"], cell)
