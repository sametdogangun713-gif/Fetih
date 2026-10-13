extends Control
## Ana ekran: krallık seçimi. Seçilen krallıkla yeni koşu başlar.


func _ready() -> void:
	RunState.end_run()
	var root := UiKit.screen_root(self, 12)
	root.add_child(UiKit.centered("FETİH", 28, UiKit.COLOR_GOLD))
	root.add_child(UiKit.centered(tr("Krallığını seç. Rakip krallıkları yen, ordunu onların askerleriyle büyüt."),
			UiKit.FONT_SIZE, UiKit.COLOR_MUTED))

	var row := UiKit.hbox(8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	for kingdom in KingdomCatalog.all():
		row.add_child(_kingdom_card(kingdom))

	root.add_child(UiKit.centered(tr("Koşu: %d savaş, %d can, en fazla %d bölük. Kaybedilen savaş tekrar oynanmaz.") % [
			Balance.RUN_LENGTH, Balance.START_LIVES, Balance.MAX_SQUADS], 10, UiKit.COLOR_MUTED))


func _kingdom_card(kingdom: KingdomData) -> Control:
	var card := UiKit.panel()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiKit.vbox(4)
	card.add_child(box)
	box.add_child(UiKit.label(kingdom.display_name, 16, kingdom.color))
	box.add_child(UiKit.label(tr("Uzmanlık: %s") % UiKit.role_name(kingdom.specialty_role),
			UiKit.FONT_SIZE, UiKit.COLOR_GOLD))
	box.add_child(UiKit.wrapped(kingdom.description, 10))
	box.add_child(UiKit.label(tr("Başlangıç ordusu:"), 10, UiKit.COLOR_MUTED))
	for unit in kingdom.starting_units:
		box.add_child(UiKit.label("• %d %s" % [
				UnitCatalog.count_for_budget(unit, Balance.SQUAD_BUDGET), unit.display_name], 10))
	box.add_child(UiKit.spacer(true))
	box.add_child(UiKit.button(tr("Bu krallıkla başla"), _on_pick.bind(kingdom)))
	return card


func _on_pick(kingdom: KingdomData) -> void:
	RunState.start_run(kingdom)
	Screens.goto(Screens.PREP)
