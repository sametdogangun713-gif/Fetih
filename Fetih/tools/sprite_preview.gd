extends SceneTree
## Birlik sprite sayfalarını tek bir PNG'de toplar (göz kontrolü); oyunda kullanılan sayfanın aynısı.
##   godot --headless --path Fetih -s res://tools/sprite_preview.gd -- <çıktı.png> [seçenekler]
## Varsayılan: her minik birlik için şerit: oyuncu (durma, yürüme, saldırı, ölüm) + rakip (durma,
## saldırı), 4x büyütülmüş, birlik adıyla.
## Seçenekler:
##   sheet          şerit yerine tam sayfalar (oyuncu rengi, 4 satır x en çok 4 sütun)
##   boss           sadece boss'lar (eski büyük çizim, tam sayfa)
##   scale=<n>      büyütme (varsayılan 4)
##   <birlik id>    sadece bu birlikler (birden çok yazılabilir)

const SCALE := 4
const COLUMNS := 4
const BG := Color("5a8f3c")
const LABEL_COLOR := Color("fdcbb0")
## Şeritteki kareler: [takım, anim satırı, kare].
const STRIP: Array = [
	[SquadState.Team.PLAYER, 0, 0], [SquadState.Team.PLAYER, 1, 0], [SquadState.Team.PLAYER, 2, 1],
	[SquadState.Team.PLAYER, 3, 3], [SquadState.Team.ENEMY, 0, 0], [SquadState.Team.ENEMY, 2, 1],
]
## 3x5 piksel yazı tipi (etiketler için; headless'ta yazı çizilemez). Satır başına 3 bit.
const GLYPHS := {
	"a": [2, 5, 7, 5, 5], "b": [6, 5, 6, 5, 6], "c": [3, 4, 4, 4, 3], "d": [6, 5, 5, 5, 6],
	"e": [7, 4, 6, 4, 7], "f": [7, 4, 6, 4, 4], "g": [3, 4, 5, 5, 3], "h": [5, 5, 7, 5, 5],
	"i": [7, 2, 2, 2, 7], "j": [1, 1, 1, 5, 2], "k": [5, 5, 6, 5, 5], "l": [4, 4, 4, 4, 7],
	"m": [5, 7, 7, 5, 5], "n": [6, 5, 5, 5, 5], "o": [2, 5, 5, 5, 2], "p": [6, 5, 6, 4, 4],
	"q": [2, 5, 5, 7, 3], "r": [6, 5, 6, 5, 5], "s": [3, 4, 2, 1, 6], "t": [7, 2, 2, 2, 2],
	"u": [5, 5, 5, 5, 7], "v": [5, 5, 5, 5, 2], "w": [5, 5, 7, 7, 5], "x": [5, 5, 2, 5, 5],
	"y": [5, 5, 2, 2, 2], "z": [7, 1, 2, 4, 7], "_": [0, 0, 0, 0, 7], "0": [7, 5, 5, 5, 7],
	"1": [2, 6, 2, 2, 7], "2": [6, 1, 2, 4, 7], "3": [6, 1, 2, 1, 6],
}


func _init() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var out_path: String = args.pop_front() if args.size() > 0 else "user://sprite_preview.png"
	var scale := SCALE
	var full := false
	var bosses := false
	var only_ids: Array[String] = []
	for a: String in args:
		if a == "sheet":
			full = true
		elif a == "boss":
			bosses = true
		elif a.begins_with("scale="):
			scale = maxi(int(a.trim_prefix("scale=")), 1)
		else:
			only_ids.append(a)
	var units: Array = []
	if bosses:
		for path in DirAccess.get_files_at("res://data/bosses/"):
			if path.ends_with(".tres"):
				units.append(load("res://data/bosses/" + path))
	else:
		for unit: UnitData in UnitCatalog.all():
			if only_ids.is_empty() or only_ids.has(String(unit.id)):
				units.append(unit)
	var tiles: Array[Image] = []
	for unit: UnitData in units:
		tiles.append(_tile(unit, full or bosses))
	var cell := Vector2i.ZERO
	for t in tiles:
		cell = Vector2i(maxi(cell.x, t.get_width()), maxi(cell.y, t.get_height()))
	cell += Vector2i(6, 6)
	var rows := ceili(tiles.size() / float(COLUMNS))
	var out := Image.create_empty(cell.x * COLUMNS, cell.y * rows, false, Image.FORMAT_RGBA8)
	out.fill(BG)
	for i in tiles.size():
		out.blend_rect(tiles[i], Rect2i(Vector2i.ZERO, tiles[i].get_size()),
				Vector2i((i % COLUMNS) * cell.x + 3, (i / COLUMNS) * cell.y + 3))
	out.resize(out.get_width() * scale, out.get_height() * scale, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path).get_base_dir())
	out.save_png(out_path)
	print("kaydedildi: ", out_path, " (", units.size(), " birlik)")
	quit()


## Bir birliğin karosu: etiket + şerit (ya da tam sayfa).
func _tile(unit: UnitData, full: bool) -> Image:
	var label := _label(String(unit.id))
	var body: Image
	if full:
		body = UnitSprites.sheet_for(unit).texture.get_image()
	else:
		var side := MiniUnitArt.CELL
		body = Image.create_empty(side * STRIP.size(), side, false, Image.FORMAT_RGBA8)
		for i in STRIP.size():
			var s := UnitSprites.sheet_for(unit, STRIP[i][0])
			var img := s.texture.get_image()
			var src := Rect2i(STRIP[i][2] * side, STRIP[i][1] * side, side, side)
			body.blit_rect(img, src, Vector2i(i * side, 0))
	var tile := Image.create_empty(maxi(body.get_width(), label.get_width()), label.get_height() + 2 + body.get_height(),
			false, Image.FORMAT_RGBA8)
	tile.blit_rect(label, Rect2i(Vector2i.ZERO, label.get_size()), Vector2i.ZERO)
	tile.blend_rect(body, Rect2i(Vector2i.ZERO, body.get_size()), Vector2i(0, label.get_height() + 2))
	return tile


func _label(text: String) -> Image:
	var img := Image.create_empty(maxi(text.length() * 4, 1), 5, false, Image.FORMAT_RGBA8)
	for i in text.length():
		var rows: Array = GLYPHS.get(text[i], [])
		for y in rows.size():
			for x in 3:
				if rows[y] & (4 >> x):
					img.set_pixel(i * 4 + x, y, LABEL_COLOR)
	return img
