extends Control
## Ana ekran: yarım kalan koşuya devam, Hazine (kalıcı geliştirmeler), krallık seçimi.
## Kilitli krallıklar gösterilir ama seçilemez; nasıl açılacağı yazar.


func _ready() -> void:
	RunState.end_run()
	var root := UiKit.screen_root(self, 12)

	var header := UiKit.hbox(10)
	header.add_child(UiKit.label("FETİH", 24, UiKit.COLOR_GOLD))
	header.add_child(UiKit.spacer())
	header.add_child(UiKit.label(tr("Şan: %d") % Profile.glory, 12, UiKit.COLOR_GOLD))
	header.add_child(UiKit.button(tr("Hazine"), func() -> void: Screens.goto(Screens.TREASURY)))
	if Profile.has_saved_run():
		header.add_child(UiKit.button(_continue_text(), _on_continue))
	root.add_child(header)

	var subtitle := tr("Krallığını seç. Rakip krallıkları yen, ordunu onların askerleriyle büyüt.")
	if Profile.has_saved_run():
		subtitle = tr("Yeni koşu başlatırsan yarım kalan koşu silinir.")
	root.add_child(UiKit.centered(subtitle, 10, UiKit.COLOR_MUTED))

	var row := UiKit.hbox(8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	for kingdom in KingdomCatalog.all():
		row.add_child(_kingdom_card(kingdom))

	var stats := Profile.stats
	root.add_child(UiKit.centered(tr("Koşu: %d savaş, her %d. savaş boss.   Oynanan koşu: %d   Fetih: %d   En uzun: %d. savaş") % [
			Balance.RUN_LENGTH, Balance.BOSS_EVERY, int(stats.get("runs", 0)),
			int(stats.get("victories", 0)), int(stats.get("best_battle", 0))], 9, UiKit.COLOR_MUTED))


func _continue_text() -> String:
	var data := Profile.saved_run
	var kingdom := KingdomCatalog.get_kingdom(StringName(data.get("kingdom", "")))
	var name := kingdom.display_name if kingdom else "?"
	return tr("Devam et: %s, savaş %d") % [name, int(data.get("battle_index", 0)) + 1]


func _kingdom_card(kingdom: KingdomData) -> Control:
	var unlocked := Profile.is_unlocked(kingdom.id)
	var card := UiKit.panel()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiKit.vbox(4)
	card.add_child(box)
	box.add_child(UiKit.label(kingdom.display_name, 16, kingdom.color if unlocked else UiKit.COLOR_MUTED))
	box.add_child(UiKit.label(tr("Uzmanlık: %s") % UiKit.role_name(kingdom.specialty_role),
			UiKit.FONT_SIZE, UiKit.COLOR_GOLD))
	if not unlocked:
		box.add_child(UiKit.wrapped(tr("KİLİTLİ. Açmak için: bir koşuda %s boss'unu (%s) yen ve fethi tamamla.") % [
				kingdom.display_name, kingdom.boss.display_name if kingdom.boss else "?"], 10, UiKit.COLOR_BAD))
		box.add_child(UiKit.spacer(true))
		return card
	box.add_child(UiKit.wrapped(kingdom.description, 10))
	for passive in kingdom.starting_passives:
		box.add_child(UiKit.wrapped(tr("Özellik: %s - %s") % [passive.display_name, passive.description],
				9, UiKit.COLOR_GOLD))
	box.add_child(UiKit.label(tr("Başlangıç ordusu:"), 10, UiKit.COLOR_MUTED))
	for unit in kingdom.starting_units:
		box.add_child(UiKit.label("• %d %s" % [
				UnitCatalog.count_for_budget(unit, Balance.SQUAD_BUDGET), unit.display_name], 10))
	var victories: int = int(Profile.stats.get("kingdom_victories", {}).get(String(kingdom.id), 0))
	if victories > 0:
		box.add_child(UiKit.label(tr("Fetih: %d") % victories, 9, UiKit.COLOR_GOOD))
	box.add_child(UiKit.spacer(true))
	box.add_child(UiKit.button(tr("Bu krallıkla başla"), _on_pick.bind(kingdom)))
	return card


func _on_pick(kingdom: KingdomData) -> void:
	RunState.start_run(kingdom, 0, Profile.run_perks(), Profile.locked_kingdoms())
	Screens.goto(Screens.PREP)


func _on_continue() -> void:
	Screens.resume_saved_run()
