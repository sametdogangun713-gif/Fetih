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
