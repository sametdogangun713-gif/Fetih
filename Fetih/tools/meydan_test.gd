extends SceneTree
## Meydan akış testi (ekransız). Oyuncunun kaydına yazmaz.
## Çalıştırma: godot --headless --path Fetih -s res://tools/meydan_test.gd

const TEST_SAVE := "user://meydan_test_save.json"
var failures := 0


func check(name: String, ok: bool) -> void:
	print("%s  %s" % ["TAMAM " if ok else "HATA  ", name])
	if not ok:
		failures += 1


func _init() -> void:
	node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node.get_parent() == root and node.name == "Profile":
		node.save_path = TEST_SAVE
		node_added.disconnect(_on_node_added)


func _initialize() -> void:
	await process_frame
	var run := root.get_node("RunState")
	# Sınıflar load() ile alınır: araç autoload'lar kurulmadan derlenirken Screens zincirini çözemez.
	var screens: GDScript = load("res://scripts/ui/screens.gd")
	run.start_run(KingdomCatalog.all()[0], 4242)
	var meydan: Node = load("res://scenes/run/meydan.tscn").instantiate()
	root.add_child(meydan)
	await process_frame
	check("PREP ile açıldı", meydan.phase == meydan.Phase.PREP)
	check("bölük görüntüleri", meydan.runner.views().size() == run.army.size() + run.current_enemy_army().size())
	# Sürükle-bırak: ilk bölüğü ikincinin üstüne bırak.
	var prep = meydan.prep
	var b_field := Formation.deploy_to_field(run.army[1].pos, SquadState.Team.PLAYER)
	prep.begin_drag(0)
	prep.drop_at(b_field)
	check("dolu yere bırakılan kaydı", run.army[0].pos.distance_to(run.army[1].pos) >= Formation.MIN_GAP - 0.001)
	# Review Focus 5: sürüklerken iptal -> eski yer.
	var before: Vector2 = run.army[0].pos
	prep.begin_drag(0)
	prep.cancel_drag()
	check("iptal eski yerde", run.army[0].pos == before)
	check("iptal sonrası sürükleme yok", prep.dragging == -1)
	meydan.queue_free()
	await process_frame
	# Kayıttan dönüş: Screens.next_phase aşamayı belirler ve okunduktan sonra sıfırlanır.
	screens.next_phase = "cards"
	run.finish_battle(true)
	var second: Node = load("res://scenes/run/meydan.tscn").instantiate()
	root.add_child(second)
	await process_frame
	check("next_phase ile CARDS açıldı", second.phase == second.Phase.CARDS)
	check("next_phase sıfırlandı", screens.next_phase == "prep")
	print("Hata: %d" % failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	quit(1 if failures > 0 else 0)
