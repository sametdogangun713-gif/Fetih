class_name SquadInfo
extends RefCounted
## Hazırlık bilgi metinleri ve küçük arayüz parçaları (ferman satırı, rakip özeti, bölük ayrıntısı).
## Hepsi statik: hem Meydan hem eski hazırlık ekranı kullanır. Statik fonksiyonda tr() olmadığı için UiKit.t().


## Alınan fermanlar: küçük mühür simgeleri; üstüne gelince adı ve açıklaması görünür.
static func passives_line(width := 306.0) -> Control:
	return _ferman_row(UiKit.t("Fermanların"), RunState.passives, width)


## Başlık + ferman mühürleri satırı (oyuncu ya da rakip).
static func _ferman_row(title: String, passives: Array[PassiveData], width: float) -> Control:
	var line := HFlowContainer.new()
	line.custom_minimum_size.x = width
	line.add_theme_constant_override("h_separation", 3)
	line.add_theme_constant_override("v_separation", 2)
	var head := UiKit.label(title, 9, UiKit.COLOR_MUTED)
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(head)
	if passives.is_empty():
		line.add_child(UiKit.label("-", 9, UiKit.COLOR_MUTED))
	for passive in passives:
		var kingdom := KingdomCatalog.get_kingdom(passive.kingdom)
		var main := kingdom.color if kingdom else UiKit.COLOR_PASSIVE
		var accent := kingdom.accent_color if kingdom else UiKit.COLOR_GOLD
		var icon := TextureRect.new()
		icon.texture = UiKit.card_icon_texture(&"passive", 0, main, accent)
		icon.custom_minimum_size = Vector2(12, 12)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = "%s\n%s" % [UiKit.t(passive.display_name), UiKit.t(passive.description)]
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		line.add_child(icon)
	return line


## Sıradaki rakibin kartı: amblem + ad, güç ve uzmanlık, bölük simgeleri (adet ve seviye noktalı),
## fermanlar mühür simgesi. Ayrıntılar simgelerin ipucunda; uzun yazı yok. width: kutunun iç genişliği.
static func fill_opponent(box: VBoxContainer, width := 0.0) -> void:
	var opponent := RunState.current_opponent()
	var enemy_army := RunState.current_enemy_army()
	if RunState.is_final_battle():
		box.add_child(_headline(UiKit.t("BÜYÜK FETİH"), UiKit.COLOR_BAD, width))
	elif RunState.is_boss_battle():
		box.add_child(_headline(UiKit.t("BOSS SAVAŞI"), UiKit.COLOR_GOLD, width))
	var title := UiKit.hbox(5)
	var emblem := TextureRect.new()
	emblem.texture = BannerArt.emblem_texture(opponent.id, opponent.color, 2)
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(emblem)
	var name_label := UiKit.label(UiKit.t(opponent.display_name), 14, opponent.color, true)
	title.add_child(name_label)
	box.add_child(title)
	var sub := UiKit.wrapped("%s  ·  %s" % [UiKit.t("Güç %d") % roundi(RunState.army_power(enemy_army)),
			UiKit.kingdom_specialty(opponent)], 10, UiKit.COLOR_GOLD)
	sub.custom_minimum_size.x = width
	box.add_child(sub)
	if RunState.is_boss_battle() and RunState.locked.has(opponent.id):
		var locked := UiKit.label(UiKit.t("Yenersen mühür"), 9, UiKit.COLOR_GOLD)
		locked.tooltip_text = UiKit.t("Kilitli krallık: boss'u yen, mühür al; fetihle %s açılır.") % UiKit.t(opponent.display_name)
		locked.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(locked)
	var units := HFlowContainer.new()
	units.custom_minimum_size.x = width
	units.add_theme_constant_override("h_separation", 4)
	units.add_theme_constant_override("v_separation", 2)
	for group in enemy_groups(enemy_army):
		units.add_child(_unit_chip(group[0], group[1]))
	box.add_child(units)
	box.add_child(_ferman_row(UiKit.t("Fermanları"), RunState.enemy_passives(), width))


static func _headline(text: String, color: Color, width: float) -> Label:
	var l := UiKit.label(text, 10, color, true)
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = width
	return l


## Rakip bölüğü simgesi: birlik figürü, altında "x2" (aynı bölükten birden çok) ve seviye noktaları.
static func _unit_chip(squad: ArmySquad, copies: int) -> Control:
	var chip := UiKit.vbox(0)
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var icon := UiKit.unit_icon(squad.unit, 1)
	icon.custom_minimum_size = icon.custom_minimum_size.min(Vector2(20, 20))  # boss figürü de küçük kalsın
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.add_child(icon)
	var caption := "x%d" % copies if copies > 1 else ""
	caption += " " + "•".repeat(squad.level()) if not squad.unit.is_boss else UiKit.t("BOSS")
	var under := UiKit.centered(caption.strip_edges(), 8, UiKit.COLOR_GOLD if squad.unit.is_boss else UiKit.COLOR_MUTED)
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(under)
	var prefix := "%dx " % copies if copies > 1 else ""
	chip.tooltip_text = "%s%d %s (%s)  %s" % [prefix, squad.count, UiKit.t(squad.unit.display_name),
			UiKit.role_name(squad.unit.role), UiKit.level_text(squad)]
	return chip


## Rakip ordusu gruplanmış: aynı birlik + aynı asker sayısı + aynı seviye -> [bölük, adet].
static func enemy_groups(enemy_army: Array[ArmySquad]) -> Array:
	var groups := {}
	var order: Array[String] = []
	for squad in enemy_army:
		var key := "%s|%d|%d" % [squad.unit.id, squad.count, squad.level()]
		if not groups.has(key):
			groups[key] = [squad, 0]
			order.append(key)
		groups[key][1] += 1
	var out: Array = []
	for key in order:
		out.append(groups[key])
	return out


## Fare altındaki bölüğün küçük kartı: ad, seviye/rol/güç, asker sayısı, can-hasar, özellikler, konum, fermanlar.
static func squad_card(squad: ArmySquad, width := 150.0) -> PanelContainer:
	var card := UiKit.game_panel(0.92)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiKit.vbox(1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var unit := squad.unit
	box.add_child(UiKit.label(UiKit.t(unit.display_name), 12, UiKit.COLOR_GOLD))
	box.add_child(UiKit.label("%s  ·  %s  ·  %s" % [UiKit.role_name(unit.role), UiKit.level_text(squad),
			UiKit.t("Güç %d") % roundi(squad.power())], 9, UiKit.COLOR_MUTED))
	box.add_child(UiKit.label(UiKit.t("%d asker  ·  Can %s  ·  Hasar %s") % [squad.count, UiKit.num(unit.hp),
			UiKit.num(unit.damage)], 9))
	var traits := UiKit.unit_traits(unit)
	if not traits.is_empty():
		var t := UiKit.wrapped(", ".join(traits), 9, UiKit.COLOR_TEXT)
		t.custom_minimum_size.x = width
		box.add_child(t)
	var extra: PackedStringArray = [UiKit.band_name(squad.band())]
	for passive in RunState.passives:
		if passive.applies_to(squad):
			extra.append(UiKit.t(passive.display_name))
	var foot := UiKit.wrapped("  ·  ".join(extra), 9, UiKit.COLOR_GOLD)
	foot.custom_minimum_size.x = width
	box.add_child(foot)
	for child in box.get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


## Bir oyuncu bölüğünün ayrıntı metni (birlik, seviyeler, özellikler, bant, fermanlar).
static func squad_details(squad: ArmySquad) -> String:
	var unit := squad.unit
	var lines: PackedStringArray = []
	lines.append("%d %s (%s)  %s  %s" % [squad.count, UiKit.t(unit.display_name), UiKit.role_name(unit.role),
			UiKit.level_text(squad), UiKit.t("Güç %d") % roundi(squad.power())])
	lines.append(UiKit.t("Saldırı %d · Savunma %d · Takviye %d") % [squad.attack_level, squad.defense_level,
			squad.reinforce_level])
	lines.append(UiKit.unit_stats(unit))
	lines.append(", ".join(UiKit.unit_traits(unit)))
	lines.append(UiKit.t("Konum: %s") % UiKit.band_name(squad.band()))
	for passive in RunState.passives:
		if passive.applies_to(squad):
			lines.append(UiKit.t("Ferman: %s") % UiKit.t(passive.display_name))
	return "\n".join(lines)
