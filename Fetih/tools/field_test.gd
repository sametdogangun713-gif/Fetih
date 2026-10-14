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
	print("Hata: %d" % failures)
	quit(1 if failures > 0 else 0)


func test_mirror() -> void:
	var player := Battlefield.field_to_world(Vector2(4.5, 13))
	var enemy := Battlefield.field_to_world(Vector2(4.5, 2))
	check("oyuncu sağda", player.x > enemy.x)
	check("oyuncu aşağıda", player.y > enemy.y)
	for p in [Vector2(0, 0), Vector2(9, 15), Vector2(3.25, 7.5), Vector2(-2, 18)]:
		check("gidiş-dönüş %s" % p, Battlefield.world_to_field(Battlefield.field_to_world(p)).is_equal_approx(p))
