extends SceneTree
## Ana menü, krallık seçimi ve ayarlar testi (ekransız). Oyuncunun kaydına/ayarına yazmaz.
## Çalıştırma: godot --headless --path Fetih -s res://tools/menu_test.gd

const TEST_SAVE := "user://menu_test_save.json"
const TEST_SETTINGS := "user://menu_test_settings.cfg"
var failures := 0


func check(name: String, ok: bool) -> void:
	print("%s  %s" % ["TAMAM " if ok else "HATA  ", name])
	if not ok:
		failures += 1


func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node.get_parent() != root:
		return
	if node.name == "Profile":
		node.save_path = TEST_SAVE
	elif node.name == "Settings":
		node.settings_path = TEST_SETTINGS


func _initialize() -> void:
	await process_frame
	await test_backdrop()
	await test_main_menu()
	await test_kingdom_select()
	await test_settings()
	await test_menu_windows()
	await test_run_end_title()
	await test_start_once()
	print("Hata: %d" % failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	quit(1 if failures > 0 else 0)


func test_backdrop() -> void:
	var script: GDScript = load("res://scripts/ui/menu_backdrop.gd") if ResourceLoader.exists("res://scripts/ui/menu_backdrop.gd") else null
	check("MenuBackdrop var", script != null)
	if script == null:
		return
	var bd: Control = script.new()
	bd.size = Vector2(640, 360)
	root.add_child(bd)
	await process_frame
	var clouds_before: float = bd.cloud_offset(0)
	await create_timer(0.3).timeout
	check("bulutlar kayıyor", bd.cloud_offset(0) != clouds_before)
	bd.size = Vector2(853, 480)
	await process_frame
	check("boyut değişince katmanlar yeniden kuruldu", bd.layer_width() == 853)
	bd.dim = 0.4
	check("karartma ayarlanır", is_equal_approx(bd.dim, 0.4))
	# Kale ve ağaçlar zemine basmalı (havada durmamalı).
	check("kale yerleşim kancası", bd.has_method("castle_ground"))
	if bd.has_method("castle_ground"):
		var g: Vector2 = bd.castle_ground()
		var peak := true
		for dx in range(-40, 41, 4):
			peak = peak and bd.near_ridge_y(g.x) <= bd.near_ridge_y(g.x + dx) + 0.01
		check("kale dağın tepesinde", peak)
		check("kale tabanı dağ yüzeyinde (fark %.1f)" % (g.y - bd.near_ridge_y(g.x)),
				g.y >= bd.near_ridge_y(g.x) and g.y - bd.near_ridge_y(g.x) <= 6.0)
		var feet: Array[Vector2] = bd.tree_feet()
		check("ön tepede ağaç var (%d)" % feet.size(), feet.size() >= 4)
		var grounded := true
		for f in feet:
			var d: float = f.y - bd.hill_ridge_y(f.x)
			grounded = grounded and d >= 0.0 and d <= 4.0
		check("ağaçların gövdesi tepede", grounded)
	check("manzarada yürüyen ordu var", bd.has_method("army_positions") and bd.army_positions().size() >= 6)
	if bd.has_method("army_positions"):
		var before: Vector2 = bd.army_positions()[0]
		await create_timer(0.3).timeout
		check("ordu yürüyor", bd.army_positions()[0] != before)
	bd.queue_free()
	await process_frame


func test_main_menu() -> void:
	var exists := ResourceLoader.exists("res://scenes/ui/main_menu.tscn")
	check("ana menü sahnesi var", exists)
	if not exists:
		return
	check("oyun ana menüyle açılır", ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/ui/main_menu.tscn")
	var profile := root.get_node("Profile")
	var run := root.get_node("RunState")
	profile.clear_run()
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.skip_intro()
	var names: Array = menu.buttons().map(func(b: Button) -> String: return b.text)
	check("kayıt yokken Devam yok", not names.any(func(n: String) -> bool: return n.begins_with(tr("Devam et"))))
	check("kayıt yokken 5 düğme %s" % [names], names.size() == 5)
	check("ilk düğme Yeni oyun (birincil)", names.size() > 0 and names[0] == tr("Yeni oyun"))
	menu.queue_free()
	await process_frame
	# Review Focus 3: yarım koşu varken "Yeni oyun" onay sorar; iptal kaydı silmez.
	run.start_run(KingdomCatalog.all()[0], 77)
	profile.store_run(run.to_dict("prep"))
	run.end_run()
	menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.skip_intro()
	check("kayıt varken ilk düğme Devam", menu.buttons()[0].text.begins_with(tr("Devam et")))
	menu._on_new_game()
	await process_frame
	check("Yeni oyun onay soruyor, kayıt duruyor", menu.is_confirming() and profile.has_saved_run())
	menu.cancel_confirm()
	await process_frame
	check("iptal sonrası kayıt duruyor", profile.has_saved_run() and not menu.is_confirming())
	menu.queue_free()
	await process_frame
	profile.clear_run()
	# Açılış doğal bitince: alt başlık açılışta gizli, sonunda logo + alt başlık görünür, perde kalkmış.
	menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	menu.set("force_intro", true)
	root.add_child(menu)
	await process_frame
	check("açılışta alt başlık gizli", menu.subtitle().modulate.a < 0.01)
	var waited := 0.0
	while menu.intro_playing() and waited < 6.0:
		await create_timer(0.1).timeout
		waited += 0.1
	await create_timer(0.6).timeout
	check("açılış kendiliğinden bitti (%.1f sn)" % waited, not menu.intro_playing())
	check("açılış sonunda logo görünür", menu.logo().modulate.a > 0.99)
	check("açılış sonunda alt başlık görünür", menu.subtitle().modulate.a > 0.5)
	menu.queue_free()
	await process_frame
	# Review Focus 5: açılış tık/tuşla her an geçer.
	menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	menu.set("force_intro", true)
	root.add_child(menu)
	await process_frame
	check("açılış oynuyor", menu.intro_playing())
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	menu._input(key)
	await process_frame
	check("tuşla açılış geçildi", not menu.intro_playing() and menu.buttons()[0].modulate.a > 0.99)
	menu.queue_free()
	await process_frame


func _action(name: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = name
	ev.pressed = true
	return ev


func test_kingdom_select() -> void:
	var run := root.get_node("RunState")
	var profile := root.get_node("Profile")
	run.end_run()
	var screen: Control = load("res://scenes/ui/kingdom_select.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	check("krallık seçimi yeni API", screen.has_method("selected"))
	if not screen.has_method("selected"):
		screen.queue_free()
		return
	var all := KingdomCatalog.all()
	check("ilk açık krallık seçili", profile.is_unlocked(screen.selected().id))
	check("10 sancak", screen.banners().size() == all.size())
	# Review Focus 4: kilitli krallık klavyeyle seçilince Başla kapalı, Enter koşu başlatmaz.
	var locked: KingdomData = null
	for k in all:
		if not profile.is_unlocked(k.id):
			locked = k
			break
	check("test profilinde kilitli krallık var", locked != null)
	if locked:
		screen.select(locked)
		check("kilitli krallıkta Başla devre dışı", screen.start_button().disabled)
		screen._unhandled_input(_action(&"ui_accept"))
		check("kilitliyle Enter koşu başlatmaz", not run.active)
	screen.select(all[0])
	screen._unhandled_input(_action(&"ui_right"))
	check("sağ ok sonraki krallık", screen.selected() == all[1])
	screen._unhandled_input(_action(&"ui_left"))
	check("sol ok önceki krallık", screen.selected() == all[0])
	for banner: Control in screen.banners():
		var label: Label = banner.name_label
		check("%s sancak adı sığıyor" % banner.kingdom.id,
				label.get_minimum_size().x <= banner.size.x + 0.5 or label.clip_text)
	screen.queue_free()
	await process_frame
	# Review Focus 1: İngilizce metinlerle Başla düğmesi ekranın içinde.
	TranslationServer.set_locale("en")
	screen = load("res://scenes/ui/kingdom_select.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame
	var rect: Rect2 = screen.start_button().get_global_rect()
	var view := root.get_visible_rect().size
	check("EN: Başla düğmesi ekranda (%s)" % rect, rect.end.x <= view.x + 0.5 and rect.end.y <= view.y + 0.5)
	TranslationServer.set_locale("tr")
	screen.queue_free()
	await process_frame


func test_settings() -> void:
	var settings := root.get_node("Settings")
	settings.volumes[&"Music"] = 0.6
	var host := Control.new()
	root.add_child(host)
	var panel = load("res://scripts/ui/settings_panel.gd").open(host, true)
	await process_frame
	check("ayarlar sekmeli", panel.has_method("select_tab"))
	if not panel.has_method("select_tab"):
		host.queue_free()
		return
	check("menüde dört sekme", panel.tab_count() == 4)
	panel.select_tab(0)
	check("müzik sürgüsü gerçek değeri gösterir", is_equal_approx(panel.slider_for(&"Music").value, 60.0))
	panel.select_tab(2)
	var checks: Array[Node] = panel.tab_content().find_children("*", "CheckButton", true, false)
	check("oyun sekmesinde açma/kapamalar (%d)" % checks.size(), checks.size() >= 4)
	var styles := {}
	for c: CheckButton in checks:
		styles[c.get_theme_stylebox("normal")] = true
		styles[c.get_theme_stylebox("focus")] = true
	check("açma/kapama stilleri tek tip (%d)" % styles.size(), styles.size() == 2)
	check("menüde parşömen tema", panel.is_menu_theme())
	panel.close()
	await process_frame
	var game_panel = load("res://scripts/ui/settings_panel.gd").open(host, false)
	await process_frame
	check("oyun içinde dil sekmesi yok", game_panel.tab_count() == 3)
	check("oyun içinde koyu tema", not game_panel.is_menu_theme())
	game_panel.close()
	await process_frame
	host.queue_free()
	await process_frame


func _overlays(node: Node) -> Array[Node]:
	return node.find_children("*", "Overlay", false, false)


func _labels_ink(overlay: Node) -> bool:
	for l: Label in overlay.find_children("*", "Label", true, false):
		if l.get_theme_color("font_color") != UiKit.COLOR_INK:
			return false
	return true


func _press_accept() -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ENTER
		ev.physical_keycode = KEY_ENTER
		ev.pressed = pressed
		root.push_input(ev)


## Menü pencereleri: parşömen tema + mürekkep yazı; açılınca odak pencerede (Enter arkaya gitmez);
## menüden açılan ayarlar ağacı durdurmaz, oyun içinden açılan durdurur.
func test_menu_windows() -> void:
	paused = false  # krallık seçiminin ilk ipucu (duraklatan) kapanmadan silindi
	var profile := root.get_node("Profile")
	var run := root.get_node("RunState")
	run.start_run(KingdomCatalog.all()[0], 78)
	profile.store_run(run.to_dict("prep"))
	run.end_run()
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.skip_intro()
	var stats_button: Button = null
	for b: Button in menu.buttons():
		if b.text == tr("İstatistikler"):
			stats_button = b
	stats_button.grab_focus()
	stats_button.pressed.emit()
	await process_frame
	var stats := _overlays(menu)
	check("istatistik penceresi açıldı", stats.size() == 1)
	if stats.size() == 1:
		check("istatistik parşömen temada", stats[0].menu_theme)
		check("istatistik yazıları mürekkep", _labels_ink(stats[0]))
		var owner := root.gui_get_focus_owner()
		check("istatistik açılınca odak pencerede", owner != null and stats[0].is_ancestor_of(owner))
		_press_accept()
		await process_frame
		await process_frame
		check("Enter arkadaki düğmeyi tetiklemez (pencere sayısı %d)" % _overlays(menu).size(),
				_overlays(menu).size() == 0)
		check("kapanınca odak menü düğmesine döner", root.gui_get_focus_owner() == stats_button)
	menu._on_new_game()
	await process_frame
	var confirm := _overlays(menu)
	check("onay penceresi parşömen temada", confirm.size() == 1 and confirm[0].menu_theme)
	if confirm.size() == 1:
		check("onay yazıları mürekkep", _labels_ink(confirm[0]))
		var owner := root.gui_get_focus_owner()
		check("onay açılınca odak pencerede", owner != null and confirm[0].is_ancestor_of(owner))
	menu.cancel_confirm()
	await process_frame
	var settings: Overlay = load("res://scripts/ui/settings_panel.gd").open(menu, true)
	await process_frame
	check("menüden açılan ayarlar ağacı durdurmaz", not paused)
	var owner := root.gui_get_focus_owner()
	check("ayarlar açılınca odak pencerede", owner != null and settings.is_ancestor_of(owner))
	settings.close()
	await process_frame
	var in_game: Overlay = load("res://scripts/ui/settings_panel.gd").open(menu, false)
	await process_frame
	check("oyun içinden açılan ayarlar ağacı durdurur", paused)
	in_game.close()
	await process_frame
	check("ayarlar kapanınca oyun devam eder", not paused)
	profile.tips_seen.clear()
	var tip: Overlay = load("res://scripts/ui/tips.gd").show_once(menu, "menu")
	await process_frame
	check("menü ipucu parşömen temada", tip != null and tip.menu_theme)
	if tip:
		check("menü ipucu yazıları mürekkep", _labels_ink(tip))
		tip.close()
	var game_tip: Overlay = load("res://scripts/ui/tips.gd").show_once(menu, "prep")
	await process_frame
	check("oyun ipucu koyu temada", game_tip != null and not game_tip.menu_theme)
	if game_tip:
		game_tip.close()
	await process_frame
	paused = false
	menu.queue_free()
	await process_frame
	profile.clear_run()


## Koşu sonu başlığı yerleşimden sonra "zıplar": pivot başlığın ortasında.
func test_run_end_title() -> void:
	var run := root.get_node("RunState")
	run.end_run()
	var screen: Control = load("res://scenes/ui/run_end.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame
	await process_frame
	var title: Label = null
	for l: Label in screen.find_children("*", "Label", true, false):
		if l.get_theme_constant("outline_size") == 6:
			title = l
	check("koşu sonu başlığı bulundu", title != null)
	if title:
		check("başlık pivotu ortada (%s / %s)" % [title.pivot_offset, title.size],
				title.size.x > 0 and title.pivot_offset.is_equal_approx(title.size / 2.0))
	screen.queue_free()
	await process_frame


## Başla iki kez basılsa da koşu bir kez başlar (ikinci çağrı tohumu değiştirmez).
func test_start_once() -> void:
	var run := root.get_node("RunState")
	run.end_run()
	var screen: Control = load("res://scenes/ui/kingdom_select.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.select(KingdomCatalog.all()[0])
	screen._on_start()
	var first_seed: int = run.seed_value
	screen._on_start()
	check("Başla ikinci kez koşuyu yeniden başlatmaz", run.seed_value == first_seed)
	screen.queue_free()
	await process_frame
	await process_frame
	if current_scene:
		current_scene.queue_free()
	await process_frame
	run.end_run()
