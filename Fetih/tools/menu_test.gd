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
