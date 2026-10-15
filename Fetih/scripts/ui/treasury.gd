extends Control
## Hazine: koşulardan kazanılan Şan ile kalıcı geliştirmeler satın alınır.

var _root: VBoxContainer


func _ready() -> void:
	Audio.play_music("menu")
	var backdrop := MenuBackdrop.new()
	backdrop.dim = 0.6
	add_child(backdrop)
	_root = UiKit.screen_root(self, 14, true)
	_build()
	Tips.show_once(self, Tips.TREASURY)


func _build() -> void:
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()
	var header := UiKit.hbox(10)
	var title := UiKit.label(tr("HAZİNE"), 20, UiKit.COLOR_GOLD, true)
	title.add_theme_color_override("font_outline_color", Color("2e222f"))
	title.add_theme_constant_override("outline_size", 5)
	header.add_child(title)
	header.add_child(UiKit.spacer())
	header.add_child(UiKit.label(tr("Şan: %d") % Profile.glory, 14, UiKit.COLOR_GOLD))
	_root.add_child(header)
	_root.add_child(UiKit.label(tr("Şan kazanma: kazanılan savaş +%d, yenilen boss +%d, tamamlanan fetih +%d.") % [
			MetaUpgrades.GLORY_PER_WIN, MetaUpgrades.GLORY_PER_BOSS, MetaUpgrades.GLORY_VICTORY],
			9, UiKit.COLOR_MUTED))

	for def in MetaUpgrades.ALL:
		_root.add_child(_upgrade_row(def))

	_root.add_child(UiKit.spacer(true))
	var bottom := UiKit.hbox()
	bottom.add_child(UiKit.spacer())
	bottom.add_child(UiKit.button_primary(tr("Geri"), func() -> void: Screens.goto(Screens.MAIN_MENU)))
	_root.add_child(bottom)


func _upgrade_row(def: Dictionary) -> Control:
	var id: String = def["id"]
	var level := Profile.level_of(id)
	var max_level := MetaUpgrades.max_level(id)
	var panel := UiKit.panel()
	var row := UiKit.hbox(10)
	panel.add_child(row)
	var info := UiKit.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.label("%s  (%d/%d)" % [tr(def["name"]), level, max_level], 12,
			UiKit.COLOR_GOLD if level > 0 else UiKit.COLOR_TEXT))
	info.add_child(UiKit.wrapped(tr(def["desc"]), 9, UiKit.COLOR_MUTED))
	row.add_child(info)
	var cost := MetaUpgrades.next_cost(id, level)
	if cost < 0:
		row.add_child(UiKit.label(tr("Tamamlandı"), 10, UiKit.COLOR_GOOD))
	else:
		var buy := UiKit.button(tr("Al (%d Şan)") % cost, _on_buy.bind(id))
		buy.disabled = not Profile.can_buy(id)
		row.add_child(buy)
	return panel


func _on_buy(id: String) -> void:
	Audio.play("card")
	Profile.buy(id)
	_build.call_deferred()
