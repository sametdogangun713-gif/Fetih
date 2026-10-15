class_name StatsPanel
extends RefCounted
## İstatistikler penceresi (Overlay): oynanan koşu, fetih, kazanılan savaş, en uzun koşu ve
## krallık başına fetih (amblemli). Veriler Profile.stats'tan okunur, hiçbir şey yazılmaz.
## Ana menüden açılır: parşömen (menü) tema, yazılar mürekkep rengi.


static func open(parent: Node) -> Overlay:
	var profile := (Engine.get_main_loop() as SceneTree).root.get_node("Profile")
	var stats: Dictionary = profile.stats
	var overlay := Overlay.new(260.0, false, 10, true)
	var box := overlay.content
	var title := UiKit.label(UiKit.t("İstatistikler"), 18, UiKit.COLOR_INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	var best := int(stats.get("best_battle", 0))
	for row: Array in [
			[UiKit.t("Oynanan koşu"), str(int(stats.get("runs", 0)))],
			[UiKit.t("Fetih"), str(int(stats.get("victories", 0)))],
			[UiKit.t("Kazanılan savaş"), str(int(stats.get("battles_won", 0)))],
			[UiKit.t("En uzun koşu"), UiKit.t("%d. savaş") % best if best > 0 else "-"],
	]:
		var name := UiKit.label(row[0], 11, UiKit.COLOR_INK)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name)
		var value := UiKit.label(row[1], 12, UiKit.COLOR_INK)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value)
	box.add_child(HSeparator.new())
	box.add_child(UiKit.label(UiKit.t("Krallıklarla fetih"), 10, UiKit.COLOR_INK))
	var per_kingdom: Dictionary = stats.get("kingdom_victories", {})
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 3)
	box.add_child(flow)
	for kingdom in KingdomCatalog.all():
		var chip := UiKit.hbox(3)
		var icon := TextureRect.new()
		icon.texture = BannerArt.emblem_texture(kingdom.id, kingdom.color, 2)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		chip.add_child(icon)
		var count := int(per_kingdom.get(String(kingdom.id), 0))
		var count_label := UiKit.label(str(count), 11, UiKit.COLOR_INK)
		if count == 0:
			count_label.self_modulate.a = 0.5  # fethedilmemiş krallık soluk
		chip.add_child(count_label)
		chip.tooltip_text = UiKit.t(kingdom.display_name)
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		flow.add_child(chip)
	var close := UiKit.button(UiKit.t("Kapat"), overlay.close)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.custom_minimum_size.x = 100
	box.add_child(close)
	parent.add_child(overlay)
	return overlay
