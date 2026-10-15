extends Control
## Koşu sonu: zafer veya yenilgi özeti, kazanılan Şan, açılan krallıklar, ana menüye dönüş.
## Ödüller (Şan, istatistik, mühürle açılan krallıklar) Profile'a bir kez yazılır; yarım koşu kaydı silinir.


func _ready() -> void:
	Audio.play_music("menu")
	if not RunState.active:  # sahne tek başına (F6) çalıştırılırsa deneme verisi
		RunState.start_run(KingdomCatalog.all()[0], 1)
	var glory := RunState.glory_earned()
	var newly_unlocked := Profile.record_run_end(glory, RunState.is_victory(), RunState.kingdom.id,
			RunState.wins, RunState.battle_index + 1, RunState.seals)
	RunState.end_run()

	var root := UiKit.screen_root(self, 16)
	root.add_child(UiKit.spacer(true))
	if RunState.is_victory():
		root.add_child(UiKit.centered(tr("FETİH TAMAMLANDI"), 24, UiKit.COLOR_GOLD))
	elif RunState.is_defeated():
		root.add_child(UiKit.centered(tr("ORDUN DAĞILDI"), 24, UiKit.COLOR_BAD))
	else:
		root.add_child(UiKit.centered(tr("BÜYÜK FETİH KAYBEDİLDİ"), 24, UiKit.COLOR_BAD))
		root.add_child(UiKit.centered(tr("Son savaşı kazanmadan fetih tamamlanmaz."), 11, UiKit.COLOR_MUTED))
	root.add_child(UiKit.centered("%s  ·  %s  ·  %s" % [tr(RunState.kingdom.display_name),
			tr("Kazanılan savaş: %d / %d") % [RunState.wins, RunState.battle_index + 1],
			tr("Yenilen boss: %d") % RunState.bosses_beaten], 12))
	root.add_child(UiKit.centered(tr("+%d Şan  (toplam %d)") % [glory, Profile.glory], 14, UiKit.COLOR_GOLD))
	for id in newly_unlocked:
		var kingdom := KingdomCatalog.get_kingdom(id)
		root.add_child(UiKit.centered(tr("Yeni krallık açıldı: %s!") % tr(kingdom.display_name), 14, kingdom.color))
	if not RunState.is_victory() and not RunState.seals.is_empty():
		root.add_child(UiKit.centered(tr("Mühürler kayboldu: krallık açmak için fethi tamamlamalısın."),
				10, UiKit.COLOR_MUTED))
	root.add_child(UiKit.centered(tr("Son ordun:"), 10, UiKit.COLOR_MUTED))
	for squad in RunState.army:
		root.add_child(UiKit.centered("%d %s  %s" % [squad.count, tr(squad.unit.display_name),
				UiKit.level_text(squad)], 10))
	root.add_child(UiKit.spacer(true))

	var bottom := UiKit.hbox()
	bottom.add_child(UiKit.spacer())
	bottom.add_child(UiKit.button(tr("Ana menüye dön"), _back_to_menu))
	bottom.add_child(UiKit.spacer())
	root.add_child(bottom)


func _back_to_menu() -> void:
	Screens.goto(Screens.MAIN_MENU)
