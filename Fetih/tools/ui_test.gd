extends SceneTree
## UiKit temaları, düğme türleri ve animasyon yardımcıları.
## Çalıştırma: godot --headless --path Fetih -s res://tools/ui_test.gd

var failures := 0


func check(name: String, ok: bool) -> void:
	print("%s  %s" % ["TAMAM " if ok else "HATA  ", name])
	if not ok:
		failures += 1


func _initialize() -> void:
	await process_frame
	var kit: GDScript = load("res://scripts/ui/ui_kit.gd")
	if not kit.has_method("theme_menu"):
		check("theme_menu var", false)
		_finish()
		return
	var menu: Theme = kit.theme_menu()
	var game: Theme = kit.theme_game()
	check("iki ayrı tema", menu != game)
	check("theme() = oyun teması", kit.theme() == game)
	for t: Theme in [menu, game]:
		check("düğme odak stili tek tip", t.get_stylebox("focus", "Button") == t.get_stylebox("focus", "CheckButton"))
		check("sürgü teması var", t.has_stylebox("slider", "HSlider"))
		var box := t.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
		check("panel köşesi yuvarlak", box != null and box.corner_radius_top_left >= 4)
	check("menü paneli açık renk (parşömen)", (menu.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color.v > 0.7)
	check("oyun paneli koyu ve saydam", (game.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color.v < 0.2
			and (game.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color.a < 0.95)
	var p: Button = kit.button_primary("Başla", func() -> void: pass)
	var g: Button = kit.button_ghost("Geç", func() -> void: pass)
	check("birincil düğme dolgulu", (p.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.a > 0.9)
	check("hayalet düğme saydam", (g.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.a < 0.2)
	check("düğme klavyeyle odaklanır", p.focus_mode == Control.FOCUS_ALL)
	var c := Control.new()
	root.add_child(c)
	var tw: Tween = kit.pop(c)
	check("pop tween döner", tw != null and tw.is_valid())
	await tw.finished
	check("pop sonunda ölçek 1", c.scale.is_equal_approx(Vector2.ONE))
	var f: Tween = kit.fade_in(c, 0.0, 0.05)
	check("fade_in görünmezden başlar", c.modulate.a == 0.0)
	await f.finished
	check("fade_in sonunda görünür", is_equal_approx(c.modulate.a, 1.0))
	c.queue_free()
	p.free()
	g.free()
	await _test_real_click(kit)
	_finish()


## Gerçek fare tıklaması (bas + bırak) düğmenin pressed sinyalini vermeli (odak bırakma basmayı iptal etmemeli).
func _test_real_click(kit: GDScript) -> void:
	var clicked := [0]
	var b: Button = kit.button("Tık", func() -> void: clicked[0] += 1)
	b.position = Vector2(40, 40)
	b.size = Vector2(120, 24)
	root.add_child(b)
	await process_frame
	var at := root.get_final_transform() * b.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion)
	await process_frame
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		root.push_input(ev)
		await process_frame
	await process_frame
	check("gerçek fare tıklaması düğmeye basar", clicked[0] == 1)
	check("tıklamadan sonra odak bırakıldı", not b.has_focus())
	b.queue_free()


func _finish() -> void:
	print("Hata: %d" % failures)
	quit(1 if failures > 0 else 0)
