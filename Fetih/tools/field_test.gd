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
