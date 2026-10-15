class_name CardLayer
extends CanvasLayer
## Kart aşaması katmanı: ekranın alt ~%40'ında kart paneli, üstte alan (ordu tam güçle yerinde).
## Kazanınca 3, kaybedince 2 kart; biri seçilir, etkisi alanda görünür (Meydan.apply_card).
## Kart türleri: birlik (savaşılan krallıktan), yükseltme (ordundaki bir bölüğe), ferman (savaşılan krallıktan).
## Ordu doluyken yeni birlik seçilirse panel "alanda bir bölüğe tıkla" der (replacing).
## Godot: CanvasLayer ekrana sabit çizilir; alan tıklaması _unhandled_input ile alınır (düğmeler olayı yutar).

signal card_taken(offer: CardOffer, replaced: ArmySquad)
signal skipped
signal replace_requested(offer: CardOffer)

const PANEL_HEIGHT := 150.0  ## 360 px ekranın ~%42'si.
## Kart satırının en çok yüksekliği: panel - boşluklar (12) - üst satır (~20) - ayırıcı (3).
const ROW_MAX := 115.0
const ART_HEIGHT := 36  ## Kart resim alanı (UiKit.CARD_ART_HEIGHT 64: bu panele sığmaz).
## Ferman ve ad satırları bu kadar satıra kırpılır; tamamı üstüne gelince (ipucu) görünür.
const DESC_LINES := 2

## Değiştirilecek bölük bekleniyor: bu teklif ordu doluyken seçildi (null: bekleme yok).
var replacing: CardOffer
## 4+ kartta (Geniş Ganimet) yazılar bir kademe küçülür.
var _compact := false
var _taking := false  ## Kart seçildi, kısa animasyon oynuyor: ikinci tık yok sayılır.
var _meydan: Node
var _panel: PanelContainer
var _content: VBoxContainer
var _hover: Label


func setup(meydan: Node) -> void:
	_meydan = meydan
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()  # CanvasLayer bir Control değil: tema ebeveynden gelmez
	add_child(root)
	_panel = UiKit.game_panel(0.95)
	var panel_style: StyleBoxFlat = _panel.get_theme_stylebox("panel")
	panel_style.corner_radius_bottom_left = 0
	panel_style.corner_radius_bottom_right = 0
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_top = -PANEL_HEIGHT
	_panel.offset_bottom = 0.0
	root.add_child(_panel)
	_content = UiKit.vbox(3)
	_panel.add_child(_content)
	replace_requested.connect(_on_replace_requested)


func _clear() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


## Kart panelini kurar (başlık satırı + kartlar). Yeniden çek ve vazgeç buradan da çağrılır.
func show_offers() -> void:
	replacing = null
	_taking = false
	_clear()
	_panel.offset_top = -PANEL_HEIGHT
	_content.add_child(_header())
	var row := UiKit.hbox(6)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(row)
	var offers := RunState.card_offers()
	_compact = offers.size() > 3
	for offer in offers:
		row.add_child(_card(offer))
	_animate_cards(row)


## Üst satır: sonuç başlığı, ganimet yazısı, yeniden çek ve "Kart alma, devam et".
func _header() -> Control:
	var opponent := RunState.current_opponent()
	var title: Label
	if RunState.last_battle_won and RunState.is_boss_battle():
		var text := tr("%s yenildi!") % tr(opponent.boss.display_name)
		if RunState.last_life_restored:
			text += tr("  +1 can (%d/%d)") % [RunState.lives, RunState.max_lives]
		title = UiKit.label(text, 13, UiKit.COLOR_GOLD, true)
	elif RunState.last_battle_won:
		title = UiKit.label(tr("Zafer!"), 14, UiKit.COLOR_GOLD, true)
	else:
		title = UiKit.label(tr("Yenilgi"), 14, UiKit.COLOR_BAD, true)
	var sub := UiKit.label(tr("Ganimet seç  ·  Ordun %d/%d bölük") % [RunState.army.size(), Balance.MAX_SQUADS],
			9, UiKit.COLOR_MUTED)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.clip_text = true  # dar ekranda butonlara çarpmasın: taşan kısım kırpılır
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var bar := UiKit.hbox(8)
	for label in [title, sub]:
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bar.add_child(label)
	if RunState.rerolls_left > 0:
		bar.add_child(UiKit.button_ghost(tr("Yeniden çek (%d hak)") % RunState.rerolls_left, _on_reroll))
	bar.add_child(UiKit.button_ghost(tr("Kart alma, devam et"), func() -> void: skipped.emit()))
	return bar


## Keşif hakkı: kart teklifleri yeni bir rastgele akışla yeniden üretilir.
func _on_reroll() -> void:
	if RunState.reroll_cards():
		Profile.store_run(RunState.to_dict("cards"))
		show_offers.call_deferred()


## Tür çerçeveli kart. Panel kısa olduğu için içerik az: ad, tür/sayı, "Al"; ayrıntılar ipucunda.
func _card(offer: CardOffer) -> Control:
	var card := UiKit.card_frame(offer.kind, _card_kingdom(offer), offer.unit, offer.upgrade,
			2, ART_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiKit.card_body(card)
	var tip := ""
	match offer.kind:
		CardOffer.Kind.UNIT:
			tip = _fill_unit_card(box, offer)
		CardOffer.Kind.UPGRADE:
			tip = _fill_upgrade_card(box, offer)
		CardOffer.Kind.PASSIVE:
			tip = _fill_passive_card(box, offer)
	card.tooltip_text = tip
	card.modulate.a = 0.0  # _animate_cards görünür yapar (ilk karede yanıp sönmesin)
	card.mouse_entered.connect(UiKit.hover_scale.bind(card, true, 1.03))
	card.mouse_exited.connect(UiKit.hover_scale.bind(card, false))
	var take := UiKit.button(tr("Yerine geç") if RunState.needs_replace(offer) else tr("Al"),
			_on_take.bind(offer, card))
	take.disabled = not RunState.can_take(offer)
	take.tooltip_text = tip
	box.add_child(take)
	return card


## Kartın krallığı: birlik/ferman kartında kendi krallığı, yükseltmede bölüğün birliğinin krallığı.
func _card_kingdom(offer: CardOffer) -> KingdomData:
	match offer.kind:
		CardOffer.Kind.UNIT:
			return KingdomCatalog.get_kingdom(offer.unit.kingdom)
		CardOffer.Kind.UPGRADE:
			return KingdomCatalog.get_kingdom(offer.target.unit.kingdom)
		CardOffer.Kind.PASSIVE:
			return KingdomCatalog.get_kingdom(offer.passive.kingdom)
	return null


## Tek satırlık yazı: taşarsa "..." ile kısalır (kart yüksekliği sabit kalsın).
func _line(text: String, size: int, color := UiKit.COLOR_TEXT) -> Label:
	var label := UiKit.label(text, size, color)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


## Birlik kartı satırlarını ekler; ipucu metnini (değerler, özellikler, durum) döndürür.
func _fill_unit_card(box: VBoxContainer, offer: CardOffer) -> String:
	var unit := offer.unit
	var existing := RunState.find_squad(unit)
	box.add_child(_line(tr(unit.display_name), 11 if _compact else 12, unit.placeholder_color))
	box.add_child(_line("%s  ·  %s" % [UiKit.role_name(unit.role),
			tr("TAKVİYE") if existing else tr("YENİ BİRLİK")], 8, UiKit.COLOR_MUTED))
	if existing:
		box.add_child(_line(UiKit.upgrade_effect(existing, ArmySquad.Upgrade.REINFORCE), 12, UiKit.COLOR_GOLD))
	else:
		box.add_child(_line(tr("%d asker") % UnitCatalog.count_for_budget(unit, Balance.SQUAD_BUDGET),
				12, UiKit.COLOR_GOLD))
	var tip := [UiKit.unit_stats(unit)]
	for text in UiKit.unit_traits(unit):
		tip.append("• " + text)
	if existing and not existing.can_upgrade():
		tip.append(tr("Bölük en üst seviyede."))
	elif existing:
		tip.append(tr("Ordundaki bölük: %s -> Sv %d") % [UiKit.level_text(existing), existing.level() + 1])
	elif RunState.needs_replace(offer):
		tip.append(tr("Ordu dolu: bir bölüğün yerine geçer."))
	else:
		tip.append(tr("Yeni bölük olarak meydana girer."))
	return "\n".join(tip)


func _fill_upgrade_card(box: VBoxContainer, offer: CardOffer) -> String:
	var squad := offer.target
	box.add_child(_line(UiKit.upgrade_name(offer.upgrade), 12, UiKit.COLOR_GOLD))
	box.add_child(_line(tr("%s bölüğü") % tr(squad.unit.display_name), 9, squad.unit.placeholder_color))
	box.add_child(_line(UiKit.upgrade_effect(squad, offer.upgrade), 12))
	return tr("Seviye: %s -> Sv %d   Güç %d -> %d") % [UiKit.level_text(squad),
			squad.level() + 1, roundi(squad.power()),
			roundi(squad.power() / Balance.level_multiplier(squad.upgrade_level(offer.upgrade))
					* Balance.level_multiplier(squad.upgrade_level(offer.upgrade) + 1))]


func _fill_passive_card(box: VBoxContainer, offer: CardOffer) -> String:
	var passive := offer.passive
	var kingdom := KingdomCatalog.get_kingdom(passive.kingdom)
	box.add_child(_line(tr(passive.display_name), 12, kingdom.color if kingdom else UiKit.COLOR_GOLD))
	var desc := UiKit.wrapped(tr(passive.description), 9)
	desc.max_lines_visible = DESC_LINES  # kısa panel: uzun açıklama kırpılır, tamamı ipucunda
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(desc)
	box.add_child(UiKit.spacer(true))
	return tr(passive.description) + "\n" + tr("Koşu boyunca kalıcı. Bir krallığın fermanı bir kez alınır.")


## Kartlar sırayla aşağıdan kayarak belirir (Tween, kart başına 0.07 sn gecikme).
## HBoxContainer çocuklarının konumunu kendisi belirler: animasyon dizilim bittikten sonra
## (bir kare sonra) başlar ve son konum kapsayıcının verdiği konumdur.
func _animate_cards(row: HBoxContainer) -> void:
	await get_tree().process_frame
	if not is_instance_valid(row):
		return  # panel bir kare içinde yeniden kuruldu
	for i in row.get_child_count():
		var card := row.get_child(i) as Control
		if card == null:
			continue
		var end_y := card.position.y
		card.position.y = end_y + 18.0
		var tween := card.create_tween().set_parallel()
		tween.tween_property(card, "position:y", end_y, 0.3).set_delay(i * 0.07) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(i * 0.07)


func _on_take(offer: CardOffer, card: Control) -> void:
	if _taking:
		return
	_taking = true
	Audio.play("card")
	# Seçilen kart bir an büyür, diğerleri söner; sonra seçim uygulanır.
	card.pivot_offset = card.size / 2.0
	for other in card.get_parent().get_children():
		if other != card:
			other.create_tween().tween_property(other, "modulate:a", 0.35, 0.15)
	var tween := card.create_tween()
	tween.tween_property(card, "scale", Vector2.ONE * 1.08, 0.08).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(card, "scale", Vector2.ONE, 0.1)
	await tween.finished
	_taking = false
	if RunState.needs_replace(offer):
		# Panel yeniden kurulurken basılan düğme de silinir; bu yüzden işlem bittikten sonra.
		replace_requested.emit.call_deferred(offer)
	else:
		card_taken.emit(offer, null)


## Ordu doluyken: panel küçülür, oyuncu alanda değiştirilecek bölüğe tıklar.
func _on_replace_requested(offer: CardOffer) -> void:
	replacing = offer
	_clear()
	_panel.offset_top = -10.0  # içeriğin en küçük yüksekliğine kadar yukarı büyür (grow BEGIN)
	_content.add_child(UiKit.centered(tr("Ordun dolu (%d/%d). %s hangi bölüğün yerine geçsin?") % [
			RunState.army.size(), Balance.MAX_SQUADS, tr(offer.unit.display_name)], 12))
	_content.add_child(UiKit.centered(tr("Değiştirilecek bölüğe alanda tıkla."), 11, UiKit.COLOR_GOLD))
	_content.add_child(UiKit.centered(
			tr("Yerine geçilen bölük ve seviyeleri kaybolur; yeni bölük onun yerine girer."), 9, UiKit.COLOR_MUTED))
	_hover = UiKit.centered("", 9)
	_content.add_child(_hover)
	var bottom := UiKit.hbox()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(UiKit.button(tr("Vazgeç"), cancel_replace))
	_content.add_child(bottom)


## Vazgeç: hiçbir şey değişmez, kartlar geri gelir.
func cancel_replace() -> void:
	replacing = null
	show_offers()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or replacing == null or _meydan == null:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()  # duraklatma menüsü açılmasın: ESC sadece vazgeçer
		cancel_replace()
		return
	var field: Battlefield = _meydan.battlefield
	if event is InputEventMouseMotion:
		var index: int = _meydan.player_index_at(field.event_field(event))
		_hover.text = SquadInfo.squad_details(RunState.army[index]).get_slice("\n", 0) if index >= 0 else ""
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var index: int = _meydan.player_index_at(field.event_field(event))
		if index >= 0:
			get_viewport().set_input_as_handled()
			var offer := replacing
			replacing = null
			card_taken.emit(offer, RunState.army[index])
