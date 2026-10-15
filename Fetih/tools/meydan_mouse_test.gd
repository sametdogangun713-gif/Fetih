extends SceneTree
## Meydan sürükleme testi, GERÇEK fare olaylarıyla (EKRANLI: pencere açılır, test bitince kapanır).
## Input.parse_input_event ile InputEventMouseButton / InputEventMouseMotion / InputEventKey gönderilir;
## olaylar normal girdi hattından (GUI, _input, _unhandled_input) geçer. Oyuncunun kaydına yazmaz.
## Çalıştırma: godot --path Fetih -s res://tools/meydan_mouse_test.gd
## Sürükleme ortasındaki ekran görüntüsü: res://tools/reports/meydan/drag.png

const TEST_SAVE := "user://meydan_mouse_test_save.json"  ## Oyuncunun user://save.json dosyasına asla yazılmaz.
const SHOT := "res://tools/reports/meydan/drag.png"
var failures := 0
var meydan: Node
var run: Node
var _held := false  ## Sol tuş basılı mı (gönderdiğimiz olaylara göre).
var _last := Vector2.ZERO  ## Son gönderilen fare konumu (pencere pikseli).


func check(name: String, ok: bool) -> void:
	print("%s  %s" % ["TAMAM " if ok else "HATA  ", name])
	if not ok:
		failures += 1


## Araç scripti autoload'lardan önce oluşur: Profile ağaca girerken kayıt yolu test dosyasına çevrilir.
func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node.get_parent() == root and node.name == "Profile":
		node.save_path = TEST_SAVE
		node_added.disconnect(_on_node_added)


# --- Fare yardımcıları ---

## Savaş alanı koordinatı -> pencere pikseli. Dünya -> görüntü alanı (canvas_transform: kamera) ->
## pencere (stretch ölçeği: 640x360 yerleşim, pencere 3x).
func _screen(field_pos: Vector2) -> Vector2:
	var world: Vector2 = meydan.battlefield.to_global(Battlefield.field_to_world(field_pos))
	var in_viewport: Vector2 = root.get_canvas_transform() * world
	return in_viewport * (Vector2(root.size) / root.get_visible_rect().size)


func _squad_screen(index: int) -> Vector2:
	return _screen(Formation.deploy_to_field(run.army[index].pos, SquadState.Team.PLAYER))


func _motion(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if _held else 0
	_last = pos
	Input.parse_input_event(ev)
	await process_frame
	await process_frame


func _button(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_held = pressed
	_last = pos
	Input.parse_input_event(ev)
	await process_frame
	await process_frame


func _key(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	await process_frame
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


## Fareyi from -> to arasında birkaç adımda taşır (gerçek sürükleme gibi).
func _move_along(from: Vector2, to: Vector2, steps := 5) -> void:
	for i in range(1, steps + 1):
		await _motion(from.lerp(to, float(i) / steps))


## Bölüğü from'dan to'ya sürükle ve bırak. mid: sürükleme ortasında çağrılacak kanca.
func _drag(index: int, to: Vector2, mid := Callable()) -> void:
	var from := _squad_screen(index)
	await _motion(from)
	await _button(from, true)
	await _move_along(from, to)
	if mid.is_valid():
		await mid.call()
	await _button(to, false)


## Boş, ekranda güvenli (arayüzün altında olmayan) bir yerleşim noktası: diğer bölüklerden uzak.
func _free_target(except_index: int) -> Vector2:
	var others: Array[Vector2] = []
	for i in run.army.size():
		if i != except_index:
			others.append(run.army[i].pos)
	var best := Vector2(-1, -1)
	var best_gap := 0.0
	for xi in 19:
		for yi in 6:
			var p := Vector2(xi * 0.5, yi * 0.5)
			var gap := 99.0
			for o in others:
				gap = minf(gap, p.distance_to(o))
			var s := _screen(Formation.deploy_to_field(p, SquadState.Team.PLAYER)) / 3.0
			if gap > best_gap and s.x > 190 and s.x < 600 and s.y > 80 and s.y < 290:
				best_gap = gap
				best = p
	return best


func _expected_drop(index: int, deploy: Vector2) -> Vector2:
	var others: Array[Vector2] = []
	for i in run.army.size():
		if i != index:
			others.append(run.army[i].pos)
	return Formation.nearest_free(deploy, others)


## Pencere pikseli -> savaş alanı koordinatı (_screen'in tersi; oyun kodundan bağımsız hesap).
func _field_at(pos: Vector2) -> Vector2:
	var in_viewport: Vector2 = pos / (Vector2(root.size) / root.get_visible_rect().size)
	var world: Vector2 = root.get_canvas_transform().affine_inverse() * in_viewport
	return Battlefield.world_to_field(meydan.battlefield.to_local(world))


## Son gönderilen fare konumunun yerleşim koordinatı.
func _mouse_deploy() -> Vector2:
	return Formation.field_to_deploy(_field_at(_last))


func _save_shot() -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT).get_base_dir())
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT))


# --- Test ---

func _initialize() -> void:
	await process_frame
	var profile := root.get_node("Profile")
	if profile.save_path != TEST_SAVE:  # yedek yol: yakalanamadıysa çevir, yeniden yükle
		push_warning("Profile autoload'u yakalanamadı; test kaydı sonradan yüklendi.")
		profile.save_path = TEST_SAVE
		profile.load_profile()
	check("profil test dosyasında", profile.save_path == TEST_SAVE)
	for id in ["menu", "prep", "battle", "cards", "treasury"]:  # ipucu penceresi fareyi yutmasın
		profile.tips_seen.append(id)
	run = root.get_node("RunState")
	run.start_run(KingdomCatalog.all()[0], 4242)
	meydan = load("res://scenes/run/meydan.tscn").instantiate()
	root.add_child(meydan)
	for i in 30:
		await process_frame
	var prep = meydan.prep
	var field: Battlefield = meydan.battlefield
	check("PREP ile açıldı", meydan.phase == meydan.Phase.PREP)
	print("Pencere %s, görüntü alanı %s" % [root.size, root.get_visible_rect().size])

	# 1. Dönüşüm: bölüğün hesaplanan ekran konumunda fare alan koordinatını geri vermeli.
	while run.army.size() < Balance.MAX_SQUADS:  # 5 bölük: sürükleme senaryolarına yetsin
		var unit: UnitData = UnitCatalog.all()[run.army.size()]
		run.army.append(ArmySquad.new(unit, 100.0, run.free_pos_for(unit)))
	meydan.enter(meydan.Phase.PREP)
	for i in 10:
		await process_frame
	var s0 := _squad_screen(0)
	await _motion(s0)
	var expected_field: Vector2 = Formation.deploy_to_field(run.army[0].pos, SquadState.Team.PLAYER)
	check("dönüşüm: olay alan koordinatı bölüğe denk (%s ~ %s)" % [_field_at(s0), expected_field],
			_field_at(s0).distance_to(expected_field) < 0.05)
	check("üstüne gelince bilgi paneli güncellendi", not str(prep._info.text).begins_with("Bir bölüğün"))

	# 2. Normal sürükle-bırak: boş bir noktaya.
	var target_deploy := _free_target(0)
	var target_screen := _screen(Formation.deploy_to_field(target_deploy, SquadState.Team.PLAYER))
	var old_pos: Vector2 = run.army[0].pos
	var shot_done := false
	var mid := func() -> void:
		check("basılı: sürükleme başladı (dragging == 0)", prep.dragging == 0)
		var view: SquadView = meydan.player_views()[0]
		var want_field := Formation.deploy_to_field(Formation.clamp_deploy(_mouse_deploy()), SquadState.Team.PLAYER)
		check("sürüklerken görüntü fareyi izler", view.squad.position.distance_to(want_field) < 0.05)
		check("sürüklerken kayıtlı konum değişmedi", run.army[0].pos == old_pos)
		var label: Label = prep._band_label
		check("bant etiketi görünür", label.visible)
		var band_text: String = UiKit.band_name(ArmySquad.band_of(Formation.clamp_deploy(_mouse_deploy()).y))
		check("bant etiketi doğru bantı yazar (%s)" % band_text, label.text == band_text)
		var mouse_vp: Vector2 = _last / (Vector2(root.size) / root.get_visible_rect().size)
		var label_center := label.get_global_rect().get_center()
		check("bant etiketi farenin yakınında", label_center.distance_to(mouse_vp) < 40.0)
		if not shot_done:
			shot_done = true
			await _save_shot()
	await _drag(0, target_screen, mid)
	var want := _expected_drop(0, _mouse_deploy())
	check("bırakınca sürükleme bitti", prep.dragging == -1)
	check("bırakılan noktaya gitti (%s ~ %s)" % [run.army[0].pos, target_deploy],
			run.army[0].pos.distance_to(want) < 0.02 and run.army[0].pos.distance_to(target_deploy) < 0.1)
	check("etiket gizlendi", not prep._band_label.visible)
	check("kayıt yazıldı (test dosyası)", FileAccess.file_exists(TEST_SAVE))

	# 3. ESC ile iptal: bölük eski yerine döner, duraklatma menüsü açılmaz.
	var before: Vector2 = run.army[1].pos
	var view1: SquadView = meydan.player_views()[1]
	var view_before := view1.squad.position
	var from := _squad_screen(1)
	await _motion(from)
	await _button(from, true)
	await _move_along(from, _screen(Formation.deploy_to_field(_free_target(1), SquadState.Team.PLAYER)))
	check("ESC öncesi sürükleme sürüyor", prep.dragging == 1)
	check("ESC öncesi görüntü taşındı", view1.squad.position.distance_to(view_before) > 0.3)
	await _key(KEY_ESCAPE)
	check("ESC: sürükleme iptal", prep.dragging == -1)
	check("ESC: kayıtlı konum aynı", run.army[1].pos == before)
	check("ESC: görüntü eski yerde", view1.squad.position.distance_to(view_before) < 0.001)
	check("ESC: duraklatma menüsü açılmadı", not meydan._pause_menu.is_open())
	check("ESC: etiket gizli", not prep._band_label.visible)
	await _button(from, false)  # kalan bırakma: boşta, hiçbir şey yapmamalı
	check("iptal sonrası bırakma konumu değiştirmedi", run.army[1].pos == before and prep.dragging == -1)

	# 4. Rakip bölgesine bırakma: kendi bölgesinin sınırına kenetlenir.
	var enemy_field := Vector2(4.5, 3.0)  # rakip yerleşim bölgesi
	check("hedef gerçekten rakip bölgesinde", field.zone_of_field(enemy_field) == Battlefield.Zone.ENEMY)
	var enemy_screen := _screen(enemy_field)
	await _drag(2, enemy_screen)
	var want2 := _expected_drop(2, _mouse_deploy())
	var pos2: Vector2 = run.army[2].pos
	check("rakip bölgesi: bölük kendi bölgesinde (%s)" % pos2,
			field.zone_of_field(Formation.deploy_to_field(pos2, SquadState.Team.PLAYER)) == Battlefield.Zone.PLAYER)
	check("rakip bölgesi: kenetlendi (y 0..%.1f)" % Formation.DEPLOY_DEPTH, pos2.y >= 0.0 and pos2.y <= Formation.DEPLOY_DEPTH)
	check("rakip bölgesi: beklenen nokta", pos2.distance_to(want2) < 0.02)

	# 5. Dolu yere bırakma: MIN_GAP korunur.
	var onto := _squad_screen(4)
	await _drag(3, onto)
	var pos3: Vector2 = run.army[3].pos
	var min_dist := 99.0
	for i in run.army.size():
		if i != 3:
			min_dist = minf(min_dist, pos3.distance_to(run.army[i].pos))
	check("dolu yer: MIN_GAP korundu (en yakın %.2f)" % min_dist, min_dist >= Formation.MIN_GAP - 0.001)
	check("dolu yer: yine de yakına oturdu", pos3.distance_to(run.army[4].pos) < Formation.MIN_GAP + 1.5)
	check("dolu yer: görüntü kayıtlı konumda",
			meydan.player_views()[3].squad.position.distance_to(Formation.deploy_to_field(pos3, SquadState.Team.PLAYER)) < 0.001)

	# 6. Boşa tıklama: bir şey sürüklenmez.
	var empty := _screen(Vector2(4.5, 8.0))  # tarafsız orta bölge
	await _motion(empty)
	await _button(empty, true)
	check("boşa basınca sürükleme yok", prep.dragging == -1)
	await _button(empty, false)

	# 7. CARDS: değiştirme modunda alanda gerçek tıklama.
	while run.army.size() < Balance.MAX_SQUADS:
		var unit: UnitData = UnitCatalog.all()[run.army.size()]
		run.army.append(ArmySquad.new(unit, 100.0, run.free_pos_for(unit)))
	var army_size: int = run.army.size()
	meydan.enter(meydan.Phase.CARDS)
	for i in 40:
		await process_frame
	var cards = meydan.cards
	var unit_offer := CardOffer.unit_card(UnitCatalog.all()[UnitCatalog.all().size() - 1])
	cards.replace_requested.emit(unit_offer)
	await process_frame
	check("değiştirme modu açıldı", cards.replacing == unit_offer)
	# ESC vazgeçer.
	await _key(KEY_ESCAPE)
	check("değiştirme: ESC vazgeçer", cards.replacing == null)
	check("değiştirme: ESC menü açmaz", not meydan._pause_menu.is_open())
	cards.replace_requested.emit(unit_offer)
	await process_frame
	var victim: ArmySquad = run.army[1]
	var click := _squad_screen(1)
	await _motion(click)
	check("değiştirme: üstüne gelince ad görünür", str(cards._hover.text) != "")
	await _button(click, true)
	await _button(click, false)
	await create_timer(1.5).timeout  # apply_card: parlama + 0.9 sn bekleme
	check("değiştirme: tıklanan bölük gitti, sayı aynı", not run.army.has(victim) and run.army.size() == army_size)
	check("değiştirme: yeni birlik geldi", run.army.any(func(s: ArmySquad) -> bool: return s.unit == unit_offer.unit))
	check("değiştirme: sıradaki savaşın hazırlığı", meydan.phase == meydan.Phase.PREP)

	print("Hata: %d" % failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	quit(1 if failures > 0 else 0)
