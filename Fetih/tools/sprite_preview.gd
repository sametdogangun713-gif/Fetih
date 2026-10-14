extends SceneTree
## Bütün birliklerin ve boss'ların sprite sayfalarını tek bir PNG'de toplar (göz kontrolü).
## Hazır çizimi olan birlik (assets/sprites/units/<id>.png) o çizimle, olmayan koddan üretilen
## sayfayla görünür; oyunda kullanılan sayfanın aynısı.
##   godot --headless --path Fetih -s res://tools/sprite_preview.gd -- <çıktı.png>

const SCALE := 2


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://sprite_preview.png"
	var units := UnitCatalog.all()
	for path in DirAccess.get_files_at("res://data/bosses/"):
		if path.ends_with(".tres"):
			units.append(load("res://data/bosses/" + path))
	var images: Array[Image] = []
	var cell := Vector2i.ZERO
	for unit in units:
		var img := UnitSprites.sheet_for(unit).texture.get_image()
		images.append(img)
		cell = Vector2i(maxi(cell.x, img.get_width()), maxi(cell.y, img.get_height()))
	cell += Vector2i(8, 8)
	var columns := 4
	var rows := ceili(units.size() / float(columns))
	var sheet := Image.create_empty(cell.x * columns, cell.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("5a8f3c"))
	for i in units.size():
		var img := images[i]
		var at := Vector2i((i % columns) * cell.x + 4, (i / columns) * cell.y + 4)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	sheet.resize(sheet.get_width() * SCALE, sheet.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	sheet.save_png(out_path)
	print("kaydedildi: ", out_path)
	quit()
