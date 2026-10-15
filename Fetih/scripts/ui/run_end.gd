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

	var backdrop := MenuBackdrop.new()  # menü manzarası, koyu: yazılar öne çıksın
	backdrop.dim = 0.62
	add_child(backdrop)
	var root := UiKit.screen_root(self, 16, true)
	root.add_child(UiKit.spacer(true))
	var title_text := tr("FETİH TAMAMLANDI")
	var title_color := UiKit.COLOR_GOLD
	if RunState.is_defeated():
		title_text = tr("ORDUN DAĞILDI")
		title_color = UiKit.COLOR_BAD
	elif not RunState.is_victory():
		title_text = tr("BÜYÜK FETİH KAYBEDİLDİ")
		title_color = UiKit.COLOR_BAD
	var title := UiKit.label(title_text, 28, title_color, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("2e222f"))
	title.add_theme_constant_override("outline_size", 6)
	root.add_child(title)
	UiKit.pop(title, 0.35)
	if not RunState.is_victory() and not RunState.is_defeated():
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
	bottom.add_child(UiKit.button_primary(tr("Ana menüye dön"), _back_to_menu))
	bottom.add_child(UiKit.spacer())
	root.add_child(bottom)


func _back_to_menu() -> void:
	Screens.goto(Screens.MAIN_MENU)
