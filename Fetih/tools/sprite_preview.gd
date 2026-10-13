extends SceneTree
## Bütün birliklerin ve boss'ların üretilen sprite sayfalarını tek bir PNG'de toplar (göz kontrolü).
##   godot --headless --path Fetih -s res://tools/sprite_preview.gd -- <çıktı.png>

const SCALE := 4


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://sprite_preview.png"
	var units := UnitCatalog.all()
	for path in DirAccess.get_files_at("res://data/bosses/"):
		if path.ends_with(".tres"):
			units.append(load("res://data/bosses/" + path))
	var cell := Vector2i(UnitSprites.SOLDIER_FRAME.x * UnitSprites.FRAME_COUNT * 2 + 8,
			UnitSprites.SOLDIER_FRAME.y * 2 + UnitSprites.BOSS_HEADROOM + 4)
	var columns := 4
	var rows := ceili(units.size() / float(columns))
	var sheet := Image.create_empty(cell.x * columns, cell.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("5a8f3c"))
	for i in units.size():
		var img := UnitSprites._generate(units[i])
		var at := Vector2i((i % columns) * cell.x + 4, (i / columns) * cell.y + 2)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	sheet.resize(sheet.get_width() * SCALE, sheet.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	sheet.save_png(out_path)
	print("kaydedildi: ", out_path)
	quit()
