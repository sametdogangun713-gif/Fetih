extends Control
## Savaş sonrası kart seçimi. Kazanınca 3, kaybedince 2 kart; biri seçilir, anında uygulanır.
## Kart türleri: birlik (savaşılan krallıktan), yükseltme (ordundaki bir bölüğe), ferman (savaşılan krallıktan).
## Ordu doluyken yeni birlik seçilirse hangi bölüğün yerine geçeceği sorulur.

var _root: VBoxContainer


func _ready() -> void:
	if not RunState.active:  # sahne tek başına (F6) çalıştırılırsa deneme koşusu
		RunState.start_run(KingdomCatalog.all()[0], 1)
		RunState.finish_battle(true)
	_root = UiKit.screen_root(self, 12)
	_show_offers()


func _clear() -> void:
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()


func _show_offers() -> void:
	_clear()
	var opponent := RunState.current_opponent()
	if RunState.last_battle_won:
		_root.add_child(UiKit.centered(tr("Zafer!"), 20, UiKit.COLOR_GOOD))
	else:
		_root.add_child(UiKit.centered(tr("Yenilgi... Bir can kaybettin (kalan: %d).") % RunState.lives,
				16, UiKit.COLOR_BAD))
	_root.add_child(UiKit.centered(tr("%s ganimeti: bir kart seç  ·  Ordun %d/%d bölük") % [
			opponent.display_name, RunState.army.size(), Balance.MAX_SQUADS], UiKit.FONT_SIZE, UiKit.COLOR_MUTED))

	var row := UiKit.hbox(8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(row)
	for offer in RunState.card_offers():
		row.add_child(_card(offer))

	var bottom := UiKit.hbox()
	bottom.add_child(UiKit.spacer())
	bottom.add_child(UiKit.button(tr("Kart alma, devam et"), _continue))
	_root.add_child(bottom)


func _card(offer: CardOffer) -> Control:
	var card := UiKit.panel()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiKit.vbox(3)
	card.add_child(box)
	match offer.kind:
		CardOffer.Kind.UNIT:
			_fill_unit_card(box, offer)
		CardOffer.Kind.UPGRADE:
			_fill_upgrade_card(box, offer)
		CardOffer.Kind.PASSIVE:
			_fill_passive_card(box, offer)
	var take := UiKit.button(tr("Al"), _on_take.bind(offer))
	take.disabled = not RunState.can_take(offer)
	box.add_child(take)
	return card


func _fill_unit_card(box: VBoxContainer, offer: CardOffer) -> void:
	var unit := offer.unit
	var existing := RunState.find_squad(unit)
	box.add_child(UiKit.label(tr("TAKVİYE") if existing else tr("YENİ BİRLİK"), 9, UiKit.COLOR_MUTED))
	box.add_child(UiKit.label(unit.display_name, 14, unit.placeholder_color))
	box.add_child(UiKit.label(UiKit.role_name(unit.role), 10, UiKit.COLOR_MUTED))
	if existing:
		box.add_child(UiKit.label(UiKit.upgrade_effect(existing, ArmySquad.Upgrade.REINFORCE), 16, UiKit.COLOR_GOLD))
	else:
		box.add_child(UiKit.label(tr("%d asker") % UnitCatalog.count_for_budget(unit, Balance.SQUAD_BUDGET),
				18, UiKit.COLOR_GOLD))
	box.add_child(UiKit.wrapped(UiKit.unit_stats(unit), 9))
	for text in UiKit.unit_traits(unit):
		box.add_child(UiKit.wrapped("• " + text, 9))
	box.add_child(UiKit.spacer(true))
	if existing and not existing.can_upgrade():
		box.add_child(UiKit.wrapped(tr("Bölük en üst seviyede."), 9, UiKit.COLOR_BAD))
	elif existing:
		box.add_child(UiKit.wrapped(tr("Ordundaki bölük: %s -> Sv %d") % [UiKit.level_text(existing),
				existing.level() + 1], 9, UiKit.COLOR_GOOD))
	elif RunState.needs_replace(offer):
		box.add_child(UiKit.wrapped(tr("Ordu dolu: bir bölüğün yerine geçer."), 9, UiKit.COLOR_BAD))
	else:
		box.add_child(UiKit.wrapped(tr("Yeni bölük olarak ızgaraya girer."), 9, UiKit.COLOR_MUTED))


func _fill_upgrade_card(box: VBoxContainer, offer: CardOffer) -> void:
	var squad := offer.target
	box.add_child(UiKit.label(tr("YÜKSELTME"), 9, UiKit.COLOR_MUTED))
	box.add_child(UiKit.label(UiKit.upgrade_name(offer.upgrade), 14, UiKit.COLOR_GOLD))
	box.add_child(UiKit.label(tr("%s bölüğü") % squad.unit.display_name, 10, squad.unit.placeholder_color))
	box.add_child(UiKit.label(UiKit.upgrade_effect(squad, offer.upgrade), 14))
	box.add_child(UiKit.wrapped(tr("Seviye: %s -> Sv %d   Güç %d -> %d") % [UiKit.level_text(squad),
			squad.level() + 1, roundi(squad.power()),
			roundi(squad.power() / Balance.level_multiplier(squad.upgrade_level(offer.upgrade))
					* Balance.level_multiplier(squad.upgrade_level(offer.upgrade) + 1))], 9, UiKit.COLOR_MUTED))
	box.add_child(UiKit.spacer(true))


func _fill_passive_card(box: VBoxContainer, offer: CardOffer) -> void:
	var passive := offer.passive
	var kingdom := KingdomCatalog.get_kingdom(passive.kingdom)
	box.add_child(UiKit.label(tr("FERMAN"), 9, UiKit.COLOR_MUTED))
	box.add_child(UiKit.label(passive.display_name, 14, kingdom.color if kingdom else UiKit.COLOR_GOLD))
	box.add_child(UiKit.wrapped(passive.description, 10))
	box.add_child(UiKit.spacer(true))
	box.add_child(UiKit.wrapped(tr("Koşu boyunca kalıcı. Bir krallığın fermanı bir kez alınır."), 9,
			UiKit.COLOR_MUTED))


func _on_take(offer: CardOffer) -> void:
	if RunState.needs_replace(offer):
		# Ekran yeniden kurulurken basılan düğme de silinir; bu yüzden işlem bittikten sonra.
		_show_replace.call_deferred(offer)
		return
	RunState.take_card(offer)
	_continue()


## Ordu doluyken: yeni birlik hangi bölüğün yerine geçsin?
func _show_replace(offer: CardOffer) -> void:
	_clear()
	_root.add_child(UiKit.centered(tr("Ordun dolu (%d/%d). %s hangi bölüğün yerine geçsin?") % [
			RunState.army.size(), Balance.MAX_SQUADS, offer.unit.display_name], 13))
	_root.add_child(UiKit.centered(tr("Yerine geçilen bölük ve seviyeleri kaybolur; yeni bölük onun karesine girer."),
			9, UiKit.COLOR_MUTED))
	for squad in RunState.army:
		var b := UiKit.button("%s  ·  %d %s (%s)  ·  %s" % [UiKit.level_text(squad), squad.count,
				squad.unit.display_name, UiKit.role_name(squad.unit.role), tr("Güç %d") % roundi(squad.power())],
				_on_replace.bind(offer, squad))
		_root.add_child(b)
	_root.add_child(UiKit.spacer(true))
	var bottom := UiKit.hbox()
	bottom.add_child(UiKit.spacer())
	bottom.add_child(UiKit.button(tr("Vazgeç"), func() -> void: _show_offers.call_deferred()))
	_root.add_child(bottom)


func _on_replace(offer: CardOffer, squad: ArmySquad) -> void:
	RunState.take_card(offer, squad)
	_continue()


func _continue() -> void:
	RunState.advance()
	Screens.goto(Screens.PREP)
