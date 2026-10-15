extends SceneTree
## Piksel yazı tipi önizlemesi: her font/boyut için Türkçe örnek satır, 3x büyütülmüş PNG.
## Çalıştırma (ekranlı): godot --path Fetih -s res://tools/font_preview.gd -- out.png

const SPECS := [["PixelOperator8.ttf", 8], ["PixelOperator.ttf", 16], ["PixelOperator8.ttf", 16],
		["PixelOperator.ttf", 32]]


func _initialize() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 150)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("2a2622")
	bg.size = Vector2(640, 150)
	vp.add_child(bg)
	var y := 4
	for spec in SPECS:
		var font: FontFile = load("res://assets/fonts/" + spec[0])
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.hinting = TextServer.HINTING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		var label := Label.new()
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", spec[1])
		label.text = "%s %d: ĞğİıŞşÇçÖöÜü Savaşa başla · Güç 120" % [spec[0].get_basename(), spec[1]]
		label.position = Vector2(4, y)
		vp.add_child(label)
		y += spec[1] + 8
	for i in 3:
		await RenderingServer.frame_post_draw
	var out := vp.get_texture().get_image()
	out.resize(out.get_width() * 3, out.get_height() * 3, Image.INTERPOLATE_NEAREST)
	out.save_png(OS.get_cmdline_user_args()[0])
	quit()
