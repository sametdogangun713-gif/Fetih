extends SceneTree
## Arayüz yazı tipi önizlemesi (Cinzel başlık, Nunito metin): her font/boyut için Türkçe örnek satır, 3x PNG.
## Çalıştırma (ekranlı): godot --path Fetih -s res://tools/font_preview.gd -- out.png

const SPECS := [["Nunito", 9, false], ["Nunito", 11, false], ["Nunito", 13, false], ["Cinzel", 18, true],
		["Cinzel", 28, true]]


func _initialize() -> void:
	var kit: GDScript = load("res://scripts/ui/ui_kit.gd")
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 170)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("1e2a4a")
	bg.size = Vector2(640, 170)
	vp.add_child(bg)
	var y := 4
	for spec in SPECS:
		var label: Label = kit.label("%s %d: ĞğİıŞşÇçÖöÜü Savaşa başla · Güç 120" % [spec[0], spec[1]],
				spec[1], Color("f2e3c0"), spec[2])
		label.position = Vector2(4, y)
		vp.add_child(label)
		y += int(spec[1] * 1.4) + 6
	for i in 3:
		await RenderingServer.frame_post_draw
	var out := vp.get_texture().get_image()
	out.resize(out.get_width() * 3, out.get_height() * 3, Image.INTERPOLATE_NEAREST)
	out.save_png(OS.get_cmdline_user_args()[0])
	quit()
