extends SceneTree
## Savaş alanı dönüşümleri, zemin ve formasyon testleri.
## Çalıştırma: godot --headless --path Fetih -s res://tools/field_test.gd

var failures := 0


func check(name: String, ok: bool) -> void:
	print("%s  %s" % ["TAMAM " if ok else "HATA  ", name])
	if not ok:
		failures += 1


func _initialize() -> void:
	await process_frame
	test_mirror()
	test_ground()
	test_buildings()
	test_layout()
	test_formation()
	test_bands()
	print("Hata: %d" % failures)
	quit(1 if failures > 0 else 0)


func test_mirror() -> void:
	var player := Battlefield.field_to_world(Vector2(4.5, 13))
	var enemy := Battlefield.field_to_world(Vector2(4.5, 2))
	check("oyuncu sağda", player.x > enemy.x)
	check("oyuncu aşağıda", player.y > enemy.y)
	for p in [Vector2(0, 0), Vector2(9, 15), Vector2(3.25, 7.5), Vector2(-2, 18)]:
		check("gidiş-dönüş %s" % p, Battlefield.world_to_field(Battlefield.field_to_world(p)).is_equal_approx(p))


func test_ground() -> void:
	var rect := Rect2i(-9, -9, 28, 34)  # alan + MARGIN (karo)
	var a := GroundArt.motif_points(&"default", rect)
	var b := GroundArt.motif_points(&"default", rect)
	check("motif deterministik", a == b)
	var per_tile := float(a.size()) / (rect.size.x * rect.size.y)
	check("motif seyrek (%.2f/karo)" % per_tile, per_tile > 0.15 and per_tile < 0.45)
	for id in GroundArt.BIOMES:
		var pts := GroundArt.motif_points(id, rect)
		var kinds := {}
		for p in pts:
			kinds[p.z] = true
		check("motif türü %s (%d nokta, türler %s)" % [id, pts.size(), kinds.keys()],
				pts.size() > 100 and kinds.size() == 1)


func test_buildings() -> void:
	for k in KingdomCatalog.all():
		var img := BuildingArt.piece(StringName("signature_%s" % k.id), k.color, k.accent_color)
		check("%s imza yapı dolu" % k.id, img.get_used_rect().size.x >= 12)
		check("%s imza yapı palette" % k.id, SpritePalette.off_palette_count(img, Color(-1, -1, -1)) == 0)
	var tower := BuildingArt.piece(&"tower", Color("4d9be6"), Color("f9c22b"))
	var used := tower.get_used_rect()
	check("kule çerçeveli", tower.get_pixel(used.position.x, used.get_center().y).v < 0.3)
	for kind in [&"wall", &"tower", &"tent", &"banner", &"fire"]:
		var r := BuildingArt.piece(kind, Color("4d9be6"), Color("f9c22b")).get_used_rect()
		check("%s boyutu 12-44 px (%s)" % [kind, r.size], r.size.x >= 12 and r.size.x <= 44 and r.size.y >= 8 and r.size.y <= 44)
	# Ağaç şeridi: yapıların olduğu karolarda ağaç yok.
	var d := Battlefield.FIELD_DEPTH
	check("ağaç şeridi (oyuncu arkası) boş", not GroundArt.tree_allowed(Vector2i(4, d + 1)))
	check("ağaç şeridi (rakip arkası) boş", not GroundArt.tree_allowed(Vector2i(4, -2)))
	check("ağaç alanın içinde yok", not GroundArt.tree_allowed(Vector2i(4, 8)))
	# Kamp: sprite sayısı, konumlar tam piksel ve deterministik.
	var holder := Node2D.new()
	root.add_child(holder)
	var humans := KingdomCatalog.get_kingdom(&"humans")
	var a := KingdomCamp.build(holder, humans, SquadState.Team.PLAYER)
	var b := KingdomCamp.build(holder, humans, SquadState.Team.PLAYER)
	check("kamp 5-7 parça (%d)" % a.size(), a.size() >= 5 and a.size() <= 7)
	var same := a.size() == b.size()
	var integral := true
	for i in a.size():
		same = same and a[i].position == b[i].position and a[i].texture.get_size() == b[i].texture.get_size()
		integral = integral and a[i].position == a[i].position.round()
	check("kamp deterministik", same)
	check("kamp konumları tam piksel", integral)
	var enemy := KingdomCamp.build(holder, humans, SquadState.Team.ENEMY)
	check("rakip kamp ekranda yukarıda", enemy[0].position.y < a[0].position.y)
	holder.queue_free()


func test_layout() -> void:
	for n in [1, 5, 12, 25, 48]:
		var slots := SquadView.layout(n, 12)
		var min_px := INF
		for i in slots.size():
			for j in range(i + 1, slots.size()):
				var d := Battlefield.field_offset_to_world(slots[i] - slots[j]).length()
				min_px = minf(min_px, d)
		check("%d asker çakışmasız (%.1f px)" % [n, min_px], n == 1 or min_px >= 12 * 0.7 - 0.5)
		var span := 0.0
		for s in slots:
			span = maxf(span, s.length())
		var cap := maxf(1.6, 0.9 + 0.015 * n)
		check("%d asker %.2f karo içinde (%.2f)" % [n, cap, span], span <= cap)
	# Gerçek figür boyu (16 px) ve boss yolu (tek figür).
	var mini := SquadView.layout(48, 16)
	var min16 := INF
	for i in mini.size():
		for j in range(i + 1, mini.size()):
			min16 = minf(min16, Battlefield.field_offset_to_world(mini[i] - mini[j]).length())
	check("48 asker 16 px figür çakışmasız (%.1f px)" % min16, min16 >= 16 * 0.7 - 0.5)
	var one := SquadView.layout(1, 48)
	check("boss tek yer", one.size() == 1 and one[0] == Vector2.ZERO)


## Eski formül (değişiklik öncesi grid_to_field): yeni dönüşüm bununla birebir aynı olmalı.
func old_grid_to_field(cell: Vector2i, gs: Vector2i, enemy: bool) -> Vector2:
	var x := (Battlefield.FIELD_WIDTH - 1) / 2.0 + (cell.x - (gs.x - 1) / 2.0) * 1.6
	var y := float(Battlefield.FIELD_DEPTH - Battlefield.DEPLOY_ROWS) + cell.y * 1.0
	if enemy:
		y = (Battlefield.FIELD_DEPTH - 1) - y
	return Vector2(x, y)


func test_formation() -> void:
	var gs := Vector2i(3, 3)
	for y in 3:
		for x in 3:
			var c := Vector2i(x, y)
			var d := Formation.cell_to_deploy(c, gs)
			check("oyuncu %s" % c, Formation.deploy_to_field(d, SquadState.Team.PLAYER).is_equal_approx(old_grid_to_field(c, gs, false)))
			check("rakip %s" % c, Formation.deploy_to_field(d, SquadState.Team.ENEMY).is_equal_approx(old_grid_to_field(c, gs, true)))
	var others: Array[Vector2] = [Vector2(4.5, 1.0)]
	var free := Formation.nearest_free(Vector2(4.6, 1.1), others)
	check("dolu yerden kaydı", free.distance_to(others[0]) >= Formation.MIN_GAP - 0.001)
	check("bölgede kaldı", free == Formation.clamp_deploy(free))
	# Review Focus 2: beş bölük üst üste bırakılsa da hiçbiri MIN_GAP'ten yakın değil.
	var placed: Array[Vector2] = []
	for i in 5:
		placed.append(Formation.nearest_free(Vector2(4.5, 1.0), placed))
	var ok := true
	for i in placed.size():
		for j in range(i + 1, placed.size()):
			ok = ok and placed[i].distance_to(placed[j]) >= Formation.MIN_GAP - 0.001
	check("5 bölük ayrık", ok)
	# Review Focus 1: bölge dışı bırakma kenetlenir.
	check("kenet ön", Formation.clamp_deploy(Vector2(4, -3)).y == 0.0)
	check("kenet arka", is_equal_approx(Formation.clamp_deploy(Vector2(4, 9)).y, Formation.DEPLOY_DEPTH))
	check("kenet yan", Formation.clamp_deploy(Vector2(-5, 1)).x == 0.0)


func test_bands() -> void:
	check("0 ön", ArmySquad.band_of(0.0) == ArmySquad.Band.FRONT)
	check("1 orta", ArmySquad.band_of(1.0) == ArmySquad.Band.MIDDLE)
	check("2 arka", ArmySquad.band_of(2.0) == ArmySquad.Band.BACK)
	check("0.49 ön", ArmySquad.band_of(0.49) == ArmySquad.Band.FRONT)
	check("1.5 arka", ArmySquad.band_of(1.5) == ArmySquad.Band.BACK)
	var front := PassiveData.new()
	front.row = PassiveData.Row.FRONT
	var back := PassiveData.new()
	back.row = PassiveData.Row.BACK
	var s := ArmySquad.new(UnitCatalog.all()[0], 100.0, Vector2(4.5, 0.0))
	check("ön ferman ön bölüğe", front.applies_to(s) and not back.applies_to(s))
	s.pos.y = 2.0
	check("arka ferman arka bölüğe", back.applies_to(s) and not front.applies_to(s))
