class_name SquadInfo
extends RefCounted
## Hazırlık bilgi metinleri ve küçük arayüz parçaları (ferman satırı, rakip özeti, bölük ayrıntısı).
## Hepsi statik: hem Meydan hem eski hazırlık ekranı kullanır. Statik fonksiyonda tr() olmadığı için UiKit.t().


## Alınan fermanlar; üstüne gelince açıklaması görünür.
static func passives_line(width := 306.0) -> Control:
	var line := HFlowContainer.new()
	line.custom_minimum_size.x = width
	line.add_theme_constant_override("h_separation", 6)
	line.add_child(UiKit.label(UiKit.t("Fermanlar:"), 9, UiKit.COLOR_MUTED))
	if RunState.passives.is_empty():
		line.add_child(UiKit.label(UiKit.t("yok"), 9, UiKit.COLOR_MUTED))
	for passive in RunState.passives:
		var tag := UiKit.label(UiKit.t(passive.display_name), 9, UiKit.COLOR_GOLD)
		tag.tooltip_text = UiKit.t(passive.description)
		tag.mouse_filter = Control.MOUSE_FILTER_PASS  # etiketler normalde fareyi yok sayar
		line.add_child(tag)
	return line


## Sıradaki rakibin özeti (başlık, güç, ordu satırları, fermanlar, ganimet) kutuya eklenir.
## width > 0: dar kutu için sıkı düzen (yazılar width'te alt satıra geçer, küçük başlık, ganimet satırı yok).
static func fill_opponent(box: VBoxContainer, width := 0.0) -> void:
	var compact := width > 0.0
	var opponent := RunState.current_opponent()
	var enemy_army := RunState.current_enemy_army()
	if RunState.is_final_battle():
		box.add_child(_headline(UiKit.t("BÜYÜK FETİH - kazanmak zorundasın"), UiKit.COLOR_BAD, width))
	elif RunState.is_boss_battle():
		box.add_child(_headline(UiKit.t("BOSS SAVAŞI - yenersen +1 can ve ferman"), UiKit.COLOR_GOLD, width))
	else:
		box.add_child(UiKit.label(UiKit.t("Sıradaki rakip"), 9, UiKit.COLOR_MUTED))
	if compact:
		box.add_child(UiKit.label(UiKit.t(opponent.display_name), 13, opponent.color))
		var sub := UiKit.wrapped("%s  ·  %s" % [UiKit.t("Güç %d") % roundi(RunState.army_power(enemy_army)),
				UiKit.kingdom_specialty(opponent)], 9, UiKit.COLOR_GOLD)
		sub.custom_minimum_size.x = width
		box.add_child(sub)
	else:
		var title := UiKit.hbox(8)
		title.add_child(UiKit.label(UiKit.t(opponent.display_name), 16, opponent.color))
		title.add_child(UiKit.label(UiKit.t("Güç %d") % roundi(RunState.army_power(enemy_army)), 10, UiKit.COLOR_MUTED))
		title.add_child(UiKit.label(UiKit.kingdom_specialty(opponent), 10, UiKit.COLOR_GOLD))
		box.add_child(title)
	if RunState.is_boss_battle() and RunState.locked.has(opponent.id):
		var locked := UiKit.wrapped(UiKit.t("Kilitli krallık: boss'u yen, mühür al; fetihle %s açılır.") % UiKit.t(opponent.display_name),
				9, UiKit.COLOR_GOLD)
		if compact:
			locked.custom_minimum_size.x = width
		box.add_child(locked)
	for line in enemy_lines(enemy_army):
		if compact:
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size.x = width
		box.add_child(line)
	var fermans := RunState.enemy_passives()
	if not fermans.is_empty():
		var names: PackedStringArray = []
		for passive in fermans:
			names.append(UiKit.t(passive.display_name))
		var fermans_label := UiKit.wrapped(UiKit.t("Fermanları: %s") % ", ".join(names), 9, UiKit.COLOR_GOLD)
		if compact:
			fermans_label.custom_minimum_size.x = width
		box.add_child(fermans_label)
	if not compact:
		box.add_child(UiKit.label(UiKit.t("Ganimet: %s kartları") % UiKit.t(opponent.display_name), 9, UiKit.COLOR_MUTED))


static func _headline(text: String, color: Color, width: float) -> Label:
	if width <= 0.0:
		return UiKit.label(text, 10, color)
	var l := UiKit.wrapped(text, 10, color)
	l.custom_minimum_size.x = width
	return l


## Rakip ordusunun satırları. Aynı birlik + aynı asker sayısı + aynı seviyedeki bölükler tek satırda.
static func enemy_lines(enemy_army: Array[ArmySquad]) -> Array[Label]:
	var lines: Array[Label] = []
	var groups := {}  ## anahtar -> [bölük, adet]
	var order: Array[String] = []
	for squad in enemy_army:
		var key := "%s|%d|%d" % [squad.unit.id, squad.count, squad.level()]
		if not groups.has(key):
			groups[key] = [squad, 0]
			order.append(key)
		groups[key][1] += 1
	for key in order:
		var squad: ArmySquad = groups[key][0]
		var copies: int = groups[key][1]
		if squad.unit.is_boss:
			lines.append(UiKit.label("• %s %s (%s)" % [UiKit.t("BOSS:"), UiKit.t(squad.unit.display_name),
					UiKit.role_name(squad.unit.role)], 10, UiKit.COLOR_GOLD))
			continue
		var prefix := "%dx " % copies if copies > 1 else ""
		lines.append(UiKit.label("• %s%d %s (%s)  %s" % [prefix, squad.count, UiKit.t(squad.unit.display_name),
				UiKit.role_name(squad.unit.role), UiKit.level_text(squad)], 10))
	return lines


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
