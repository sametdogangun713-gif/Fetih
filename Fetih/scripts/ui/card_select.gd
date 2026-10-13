extends Control
## Savaş sonrası kart seçimi: savaşılan krallığın birliklerinden biri seçilir.
## Kazanınca 3, kaybedince 2 kart. Seçilen kart anında orduya eklenir (deste yok).


func _ready() -> void:
	if not RunState.active:  # sahne tek başına (F6) çalıştırılırsa deneme koşusu
		RunState.start_run(KingdomCatalog.all()[0], 1)
		RunState.finish_battle(true)
	var opponent := RunState.current_opponent()
	var root := UiKit.screen_root(self, 12)
	if RunState.last_battle_won:
		root.add_child(UiKit.centered(tr("Zafer!"), 20, UiKit.COLOR_GOOD))
	else:
		root.add_child(UiKit.centered(tr("Yenilgi... Bir can kaybettin (kalan: %d).") % RunState.lives,
				16, UiKit.COLOR_BAD))
	root.add_child(UiKit.centered(tr("%s ordusundan bir birlik seç:") % opponent.display_name,
			UiKit.FONT_SIZE, UiKit.COLOR_MUTED))

	var row := UiKit.hbox(8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	for offer in RunState.card_offers():
		row.add_child(_card(offer))

	var bottom := UiKit.hbox()
	bottom.add_child(UiKit.spacer())
	bottom.add_child(UiKit.button(tr("Kart alma, devam et"), _continue))
	root.add_child(bottom)


func _card(offer: CardOffer) -> Control:
	var unit := offer.unit
	var card := UiKit.panel()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiKit.vbox(3)
	card.add_child(box)
	box.add_child(UiKit.label(unit.display_name, 14, unit.placeholder_color))
	box.add_child(UiKit.label(UiKit.role_name(unit.role), 10, UiKit.COLOR_MUTED))
	box.add_child(UiKit.label(tr("%d asker") % offer.count, 18, UiKit.COLOR_GOLD))
	box.add_child(UiKit.wrapped(UiKit.unit_stats(unit), 9))
	for text in UiKit.unit_traits(unit):
		box.add_child(UiKit.wrapped("• " + text, 9, UiKit.COLOR_TEXT))
	box.add_child(UiKit.spacer(true))

	var existing := RunState.find_squad(unit)
	var note: Label
	if existing:
		note = UiKit.wrapped(tr("Ordundaki bölüğe eklenir: %d → %d") % [existing.count,
				existing.count + offer.count], 9, UiKit.COLOR_GOOD)
	elif RunState.can_take(offer):
		note = UiKit.wrapped(tr("Yeni bölük olarak ızgaraya girer."), 9, UiKit.COLOR_MUTED)
	else:
		note = UiKit.wrapped(tr("Izgara dolu."), 9, UiKit.COLOR_BAD)
	box.add_child(note)

	var take := UiKit.button(tr("Al"), _take.bind(offer))
	take.disabled = not RunState.can_take(offer)
	box.add_child(take)
	return card


func _take(offer: CardOffer) -> void:
	RunState.take_card(offer)
	_continue()


func _continue() -> void:
	RunState.advance()
	Screens.goto(Screens.PREP)
