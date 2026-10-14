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
