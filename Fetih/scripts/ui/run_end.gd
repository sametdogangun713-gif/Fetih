extends Control
## Koşu sonu: zafer veya yenilgi özeti, ana menüye dönüş.


func _ready() -> void:
	if not RunState.active:  # sahne tek başına (F6) çalıştırılırsa deneme verisi
		RunState.start_run(KingdomCatalog.all()[0], 1)
	var root := UiKit.screen_root(self, 16)
	root.add_child(UiKit.spacer(true))
	if RunState.is_victory():
		root.add_child(UiKit.centered(tr("FETİH TAMAMLANDI"), 24, UiKit.COLOR_GOLD))
	elif RunState.is_defeated():
		root.add_child(UiKit.centered(tr("ORDUN DAĞILDI"), 24, UiKit.COLOR_BAD))
	else:
		root.add_child(UiKit.centered(tr("BÜYÜK FETİH KAYBEDİLDİ"), 24, UiKit.COLOR_BAD))
		root.add_child(UiKit.centered(tr("Son savaşı kazanmadan fetih tamamlanmaz."), 11, UiKit.COLOR_MUTED))
	root.add_child(UiKit.centered("%s  ·  %s" % [RunState.kingdom.display_name,
			tr("Kazanılan savaş: %d / %d") % [RunState.wins, RunState.battle_index + 1]], 12))
	root.add_child(UiKit.centered(tr("Son ordun:"), 10, UiKit.COLOR_MUTED))
	for squad in RunState.army:
		root.add_child(UiKit.centered("%d %s  %s" % [squad.count, squad.unit.display_name,
				UiKit.level_text(squad)], 10))
	root.add_child(UiKit.spacer(true))

	var bottom := UiKit.hbox()
	bottom.add_child(UiKit.spacer())
	bottom.add_child(UiKit.button(tr("Ana menüye dön"), _back_to_menu))
	bottom.add_child(UiKit.spacer())
	root.add_child(bottom)


func _back_to_menu() -> void:
	RunState.end_run()
	Screens.goto(Screens.KINGDOM_SELECT)
