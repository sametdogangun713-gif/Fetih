extends SceneTree
## Bütün birliklerin ve boss'ların sprite sayfalarını tek bir PNG'de toplar (göz kontrolü).
## Hazır çizimi olan birlik (assets/sprites/units/<id>.png) o çizimle, olmayan koddan üretilen
## sayfayla görünür; oyunda kullanılan sayfanın aynısı.
##   godot --headless --path Fetih -s res://tools/sprite_preview.gd -- <çıktı.png> [seçenekler]
## Seçenekler:
##   gen            sadece koddan üretilen sayfalar (+ kıyas için birkaç hazır CC0 sayfa, en sonda)
##   demo           her rol için koddan üretilen yedek insansı figür (hazır çizim yok sayılır)
##   scale=<n>      büyütme (varsayılan 2)
##   <birlik id>    sadece bu birlikler (birden çok yazılabilir)

const SCALE := 2
## "gen" kipinde kıyas için yanına konan hazır sayfalar (stil referansı).
const REFERENCE_IDS: Array[StringName] = [&"human_swordsman", &"human_spearman", &"elf_archer",
		&"dwarf_axe", &"orc_shaman", &"demon_hellhound"]


func _init() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var out_path: String = args.pop_front() if args.size() > 0 else "user://sprite_preview.png"
	var scale := SCALE
	var only_generated := false
	var only_ids: Array[String] = []
	var demo := false
	for a: String in args:
		if a == "gen":
			only_generated = true
		elif a == "demo":
			demo = true
		elif a.begins_with("scale="):
			scale = maxi(int(a.trim_prefix("scale=")), 1)
		else:
			only_ids.append(a)
	var all := UnitCatalog.all()
	for path in DirAccess.get_files_at("res://data/bosses/"):
		if path.ends_with(".tres"):
			all.append(load("res://data/bosses/" + path))
	var units: Array = []
	var references: Array = []
	for unit: UnitData in all:
		var has_art := ResourceLoader.exists(UnitSprites.user_path(unit))
		if not only_ids.is_empty():
			if only_ids.has(String(unit.id)):
				units.append(unit)
		elif only_generated:
			if not has_art:
				units.append(unit)
			elif REFERENCE_IDS.has(unit.id):
				references.append(unit)
		else:
			units.append(unit)
	units.append_array(references)
	var images: Array[Image] = []
	if demo:  # hazır çizimi olsa bile her rolün koddan üretilen yedek figürü
		units.clear()
		for role in RoleRules.ROLE_ORDER:
			var u := UnitData.new()
			u.id = StringName("demo_" + role)
			u.role = role
			u.placeholder_color = Color.from_hsv(RoleRules.ROLE_ORDER.find(role) / 7.0, 0.45, 0.75)
			units.append(u)
	var cell := Vector2i.ZERO
	for unit: UnitData in units:
		var img := UnitSprites.generate(unit) if demo else UnitSprites.sheet_for(unit).texture.get_image()
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
	sheet.resize(sheet.get_width() * scale, sheet.get_height() * scale, Image.INTERPOLATE_NEAREST)
	sheet.save_png(out_path)
	print("kaydedildi: ", out_path)
	quit()
