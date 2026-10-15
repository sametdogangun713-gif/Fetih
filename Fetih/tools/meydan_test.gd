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
	# BATTLE: savaş başlar, bitince sonuç kaydedilir, "Devam" kart aşamasına geçirir.
	meydan.enter(meydan.Phase.BATTLE)
	check("savaş başladı", meydan.runner.running)
	check("BATTLE: HUD görünür, hazırlık gizli", meydan.hud.visible and not meydan.prep.visible)
	var sim: BattleSimulation = meydan.runner.simulation
	while not sim.finished:
		sim.step()
	await process_frame
	check("sonuç kaydedildi", run.results.size() == 1)
	meydan.hud.continue_pressed.emit()
	await process_frame
	check("CARDS aşaması", meydan.phase == meydan.Phase.CARDS)
	# CARDS: kart alanda uygulanır, sonra sıradaki savaşın hazırlığı.
	var cards = meydan.cards  # tür yazılmaz: araç derlenirken CardLayer -> RunState (autoload) çözülemez
	check("CARDS: panel görünür", cards.visible and not meydan.hud.visible)
	var offers: Array[CardOffer] = run.card_offers()
	var takeable: CardOffer = null
	for o in offers:
		if run.can_take(o) and not run.needs_replace(o):
			takeable = o
			break
	var index_before: int = run.battle_index
	meydan.apply_card(takeable)
	await create_timer(1.5).timeout  # kart etkisi animasyonu
	check("sıradaki savaş", run.battle_index == index_before + 1)
	check("tekrar PREP", meydan.phase == meydan.Phase.PREP)
	# Review Focus 4: ordu doluyken birlik kartı + vazgeç.
	while run.army.size() < Balance.MAX_SQUADS:
		var unit: UnitData = UnitCatalog.all()[run.army.size()]
		run.army.append(ArmySquad.new(unit, 100.0, run.free_pos_for(unit)))
	var army_before: int = run.army.size()
	var unit_offer := CardOffer.unit_card(UnitCatalog.all()[UnitCatalog.all().size() - 1])
	meydan.enter(meydan.Phase.CARDS)
	cards.replace_requested.emit(unit_offer)
	check("değiştirme bekleniyor", cards.replacing == unit_offer)
	await process_frame
	var panel: Control = cards._panel
	var viewport_h: float = root.get_visible_rect().size.y
	check("değiştirme paneli altta ve kısa", panel.size.y < 150.0 and absf(panel.get_global_rect().end.y - viewport_h) < 1.5)
	cards.cancel_replace()
	check("vazgeç: ordu aynı", run.army.size() == army_before and cards.replacing == null)
	# Değiştirme: bir bölüğe tıklanınca yeni birlik onun yerine girer.
	var victim: ArmySquad = run.army[0]
	cards.replace_requested.emit(unit_offer)
	var click_at := Formation.deploy_to_field(victim.pos, SquadState.Team.PLAYER)
	check("alan tıklaması bölüğü bulur", meydan.player_index_at(click_at) == 0)
	meydan.apply_card(unit_offer, victim)
	await create_timer(1.5).timeout
	check("değiştirme: ordu sayısı aynı, eski bölük gitti", run.army.size() == army_before and not run.army.has(victim))
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
