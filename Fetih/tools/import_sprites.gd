extends SceneTree
## Hazır CC0 paketlerinden (proje dışındaki kaynak_assetler/) birlik sprite sayfaları üretir.
##   godot --headless --path Fetih -s res://tools/import_sprites.gd [-- <birlik id> ...]
##   Sonra: godot --headless --path Fetih --import   (yeni PNG'ler içe aktarılsın)
## Çıktı UnitSprites düzenindedir: 4 satır (durma, yürüme, saldırı, ölüm), kare biçimli kareler,
## figür sağa bakar, ayak ortası karenin alt ortasında, en alt satırın bir üstünde.
## SPECS'te olmayan birlikler koddan üretilmeye devam eder (atlılar, toplar, golemler, kentaurlar).
## Kaynaklar ve lisanslar: kaynak_assetler/LISANSLAR.md

const OUT_DIR := "res://assets/sprites/units/"
const PUNY_ROW := 2  ## Puny sayfalarında sağa bakan satır (8 yönün üçüncüsü).
const PUNY_CELL := 32
## Puny Characters sütunları. Ölüm 21-23 (19-20 hasar; bazı sayfalarda 19 beyaz parlama).
const PUNY := {
	idle = [0, 1], walk = [1, 2, 3, 4], death = [21, 22, 23],
	sword = [5, 6, 7, 8], bow = [9, 10, 11, 12], staff = [13, 14, 15], throw = [16, 17, 18],
}
## PunyMonsters sütunları (ölüm yok: hasar karesinden üretilir).
const MONSTER := {idle = [0], walk = [1, 2, 3, 4], attack = [5, 6, 7, 8], hurt = 9}
## Puny Slime.png (tek satır, yön yok). Zıplayarak yürür, ezilip kabararak vurur.
const SLIME := {idle = [0, 1, 2, 1], walk = [3, 4, 5, 7], attack = [2, 3, 8, 0], death = [10, 11, 12, 13]}
## Saldırısı olmayan figürlerde (DungeonTileset II) hamle: durma karesi ileri itilir (piksel).
const LUNGE := [1, 3, 2, 0]
## Ölümü olmayan insansılarda devrilme açıları (derece).
const FALL := [0.0, 35.0, 70.0, 90.0]

## Birlik id -> kaynak. kind: puny | monster | slime | dt2.
## Seçenekler: attack (puny silahı), scale (tam sayı büyütme), crown (boss tacı),
## hue (renk tonunu kaydır, 0-1), sat / val (doygunluk / parlaklık çarpanı),
## colorize (gri figürü bu tona boyar, 0-1).
const SPECS := {
	# İnsanlar
	&"human_swordsman": {kind = "puny", file = "Human-Soldier-Red.png", attack = "sword"},
	&"human_spearman": {kind = "puny", file = "Warrior-Blue.png", attack = "sword"},
	&"human_crossbowman": {kind = "puny", file = "Archer-Purple.png", attack = "bow"},
	&"human_boss": {kind = "dt2", name = "knight_m", scale = 2, crown = true},
	# Elfler
	&"elf_archer": {kind = "puny", file = "Archer-Green.png", attack = "bow"},
	&"elf_blade_dancer": {kind = "dt2", name = "elf_m"},
	&"elf_mage": {kind = "dt2", name = "elf_f"},
	&"elf_boss": {kind = "dt2", name = "elf_f", scale = 2, crown = true},
	# Orklar
	&"orc_warrior": {kind = "puny", file = "Orc-Grunt.png", attack = "sword"},
	&"orc_shieldbearer": {kind = "puny", file = "Orc-Soldier-Red.png", attack = "sword"},
	&"orc_shaman": {kind = "dt2", name = "orc_shaman"},
	&"orc_boss": {kind = "dt2", name = "ogre", crown = true},
	# Cüceler
	&"dwarf_axe": {kind = "dt2", name = "dwarf_m"},
	&"dwarf_crossbow": {kind = "dt2", name = "dwarf_f"},
	&"dwarf_shield": {kind = "dt2", name = "dwarf_m", sat = 0.3, val = 0.9},
	# Ölüler
	&"undead_skeleton": {kind = "dt2", name = "skelet"},
	&"undead_archer": {kind = "dt2", name = "skelet", val = 0.78},
	&"undead_necromancer": {kind = "dt2", name = "necromancer"},
	&"undead_boss": {kind = "dt2", name = "necromancer", scale = 2, crown = true},
	# İblisler
	&"demon_imp": {kind = "dt2", name = "imp"},
	&"demon_brute": {kind = "dt2", name = "chort"},
	&"demon_warlock": {kind = "dt2", name = "wogol"},
	&"demon_hellhound": {kind = "monster", file = "Gray-Wolf-32x32.png", colorize = 0.01},
	&"demon_boss": {kind = "dt2", name = "big_demon", crown = true},
	# Slime'lar
	&"slime_green": {kind = "slime"},
	&"slime_acid": {kind = "slime", hue = -0.13},
	&"slime_bouncer": {kind = "slime", hue = 0.2},
	&"slime_big": {kind = "slime", scale = 2, hue = 0.45},
	&"slime_boss": {kind = "slime", scale = 3, crown = true},
	# Bataklık
	&"mud_lurker": {kind = "dt2", name = "swampy"},
	&"mud_mass": {kind = "dt2", name = "muddy"},
	&"mud_spitter": {kind = "dt2", name = "swampy", hue = 0.08},
	&"mud_witch": {kind = "dt2", name = "wizzard_f", hue = -0.3},
	&"mud_boss": {kind = "dt2", name = "muddy", scale = 3, crown = true},
}


## Sayfadaki bir kare: kaynak resim ve yerleşimde eklenecek ek kayma (hamle için).
class Frame:
	var image: Image
	var shift := Vector2i.ZERO

	func _init(p_image: Image, p_shift := Vector2i.ZERO) -> void:
		image = p_image
		shift = p_shift


var _source_dir := ""


func _init() -> void:
	_source_dir = ProjectSettings.globalize_path("res://").path_join("../kaynak_assetler").simplify_path()
	var only := Array(OS.get_cmdline_user_args())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var made := 0
	var off_before := 0
	var off_after := 0
	_check_palette_file()
	for id: StringName in SPECS:
		if not only.is_empty() and not only.has(String(id)):
			continue
		var sheet := _build(SPECS[id])
		# Palet adımı (görev 2.1): bütün sayfa Resurrect 64'e indirilir, kontur #1c1612 istisna.
		var before := SpritePalette.off_palette_count(sheet)
		SpritePalette.quantize(sheet)
		var after := SpritePalette.off_palette_count(sheet)
		off_before += before
		off_after += after
		var err := sheet.save_png(OUT_DIR + String(id) + ".png")
		if err != OK:
			push_error("kaydedilemedi: %s (%s)" % [id, error_string(err)])
			continue
		print("%s  %dx%d  palet dışı: %d -> %d" % [id, sheet.get_width(), sheet.get_height(), before, after])
		made += 1
	print("Palet dışı piksel toplamı: %d -> %d (hedef 0)" % [off_before, off_after])
	print("%d sayfa üretildi. Şimdi: godot --headless --path Fetih --import" % made)
	quit()


## assets/palette/resurrect-64.hex, SpritePalette.HEX ile aynı mı? (dosya paletin kayıt hâli)
func _check_palette_file() -> void:
	var f := FileAccess.open("res://assets/palette/resurrect-64.hex", FileAccess.READ)
	if f == null:
		push_error("palet dosyası yok: assets/palette/resurrect-64.hex")
		return
	var same := true
	var i := 0
	for line in f.get_as_text().strip_edges().split("\n"):
		same = same and i < SpritePalette.HEX.size() and line.strip_edges() == SpritePalette.HEX[i]
		i += 1
	if not same or i != SpritePalette.HEX.size():
		push_error("resurrect-64.hex ile SpritePalette.HEX farklı (%d satır, same=%s)" % [i, same])


func _build(spec: Dictionary) -> Image:
	var rows: Array = []  # 4 satır, her biri Array[Frame]
	var synth_death := ""  # "fall" (devrilme) / "flop" (sırt üstü) / "" (kaynakta var)
	match spec.kind:
		"puny":
			var src := _load("puny_characters/" + spec.file)
			rows = [_puny_cells(src, PUNY.idle), _puny_cells(src, PUNY.walk),
					_puny_cells(src, PUNY[spec.get("attack", "sword")]), _puny_cells(src, PUNY.death)]
		"monster":
			var src := _load("puny_monsters/" + spec.file)
			rows = [_puny_cells(src, MONSTER.idle), _puny_cells(src, MONSTER.walk),
					_puny_cells(src, MONSTER.attack), _puny_cells(src, [MONSTER.hurt])]
			synth_death = "flop"
		"slime":
			var src := _load("puny_characters/Slime.png")
			rows = [_strip_cells(src, SLIME.idle), _strip_cells(src, SLIME.walk),
					_strip_cells(src, SLIME.attack), _strip_cells(src, SLIME.death)]
		"dt2":
			var idle := _dt2_frames(spec.name, "idle")
			var walk := _dt2_frames(spec.name, "run")
			var hit := _dt2_frames(spec.name, "hit")
			var attack: Array = []
			for dx in LUNGE:
				attack.append(Frame.new(idle[0].image, Vector2i(dx, 0)))
			# Hasar karesi yoksa ölüm satırı sonra durma karesinden üretilir (yer tutucu yeni Frame:
			# aynı nesne iki satırda olsa aşağıda iki kez büyütülürdü).
			rows = [idle, walk, attack, hit if not hit.is_empty() else [Frame.new(idle[0].image)]]
			synth_death = "fall"
	var scale: int = spec.get("scale", 1)
	for row: Array in rows:
		for f: Frame in row:
			f.image = _recolor(f.image, spec)
			if scale > 1:
				f.image.resize(f.image.get_width() * scale, f.image.get_height() * scale,
						Image.INTERPOLATE_NEAREST)
				f.shift *= scale
	# Hizalama noktası: ilk durma karesindeki figürün ayak ortası. Bütün kareler buna göre
	# yerleşir, böylece kılıç savurma gibi kareler arası hareket korunur.
	var used := (rows[0][0] as Frame).image.get_used_rect()
	var anchor := Vector2i(used.position.x + used.size.x / 2, used.end.y - 1)
	var side := maxi(32, ceili((maxi(used.size.x, used.size.y) + 8) / 16.0) * 16)
	var cells: Array = []
	for row: Array in rows:
		var placed: Array[Image] = []
		for f: Frame in row:
			placed.append(_place(f, anchor, side))
		cells.append(placed)
	if synth_death != "":
		cells[3] = _synth_death(cells[3][0] if synth_death == "flop" else cells[0][0], synth_death, side)
	if spec.get("crown", false):
		for anim in 3:
			for cell: Image in cells[anim]:
				UnitSprites._crown(cell)
	var columns := 0
	for row: Array in cells:
		columns = maxi(columns, row.size())
	var sheet := Image.create_empty(side * columns, side * 4, false, Image.FORMAT_RGBA8)
	for anim in 4:
		for i in cells[anim].size():
			var cell: Image = cells[anim][i]
			sheet.blit_rect(cell, Rect2i(0, 0, side, side), Vector2i(i * side, anim * side))
	return sheet


func _load(relative: String) -> Image:
	var image := Image.load_from_file(_source_dir.path_join(relative))
	image.convert(Image.FORMAT_RGBA8)
	return image


## Puny sayfasından sağa bakan satırın istenen sütunları.
func _puny_cells(src: Image, columns: Array) -> Array:
	var out: Array = []
	for col: int in columns:
		out.append(Frame.new(src.get_region(
				Rect2i(col * PUNY_CELL, PUNY_ROW * PUNY_CELL, PUNY_CELL, PUNY_CELL))))
	return out


## Tek satırlık şerit (Slime.png).
func _strip_cells(src: Image, columns: Array) -> Array:
	var side := src.get_height()
	var out: Array = []
	for col: int in columns:
		out.append(Frame.new(src.get_region(Rect2i(col * side, 0, side, side))))
	return out


## DungeonTileset II: her kare ayrı dosya. "idle"/"run" yoksa tek "_anim" dizisi kullanılır.
func _dt2_frames(name: String, anim: String) -> Array:
	var out: Array = []
	for prefix in ["%s_%s_anim_f" % [name, anim], "%s_anim_f" % name]:
		if anim == "hit" and prefix == "%s_anim_f" % name:
			break  # hasar karesi yalnız kahramanlarda var; yoksa boş döner
		var i := 0
		while FileAccess.file_exists(_source_dir.path_join("dungeontileset_ii/frames/%s%d.png" % [prefix, i])):
			out.append(Frame.new(_load("dungeontileset_ii/frames/%s%d.png" % [prefix, i])))
			i += 1
		if not out.is_empty():
			break
	return out


## Kareyi side x side tuvale koyar: hizalama noktası tuvalin alt ortasına (en alt satırın üstüne).
## Taşan pikseller kırpılır (blit_rect sınır dışını atar).
func _place(f: Frame, anchor: Vector2i, side: int) -> Image:
	var cell := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	var at := Vector2i(side / 2, side - 2) - anchor + f.shift
	cell.blend_rect(f.image, Rect2i(Vector2i.ZERO, f.image.get_size()), at)
	return cell


## Ölüm satırı üretir. fall: ayakların üstünden geriye devrilir (UnitSprites._rotated gibi).
## flop: hayvan sarsılır, sonra sırt üstü yatar (dikey çevrilmiş beden yere oturur).
func _synth_death(base: Image, mode: String, side: int) -> Array:
	var out: Array = []
	if mode == "flop":
		out.append(base)
		var lying := base.duplicate() as Image
		lying.flip_y()
		var used := lying.get_used_rect()
		var cell := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
		# Çevrilen bedenin sırtı yere (ayak çizgisine) değsin.
		cell.blend_rect(lying, used, Vector2i(used.position.x, side - 1 - used.size.y))
		out.append(cell)
		return out
	for degrees: float in FALL:
		out.append(_rotated(base, degrees, side))
	return out


func _rotated(src: Image, degrees: float, side: int) -> Image:
	var out := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	var theta := deg_to_rad(degrees)
	var pivot := Vector2(side / 2.0, side - 3.0)
	var shift := Vector2(side * 0.375 * degrees / 90.0, 0)
	var cos_t := cos(theta)
	var sin_t := sin(theta)
	for y in side:
		for x in side:
			# Hedef pikselden kaynağa geri dönülür (ters döndürme): sonuçta delik kalmaz.
			var d := Vector2(x, y) - pivot - shift
			var s := Vector2(d.x * cos_t - d.y * sin_t, d.x * sin_t + d.y * cos_t) + pivot
			var sx := roundi(s.x)
			var sy := roundi(s.y)
			if sx >= 0 and sy >= 0 and sx < side and sy < side:
				var c := src.get_pixel(sx, sy)
				if c.a > 0.0:
					out.set_pixel(x, y, c)
	return out


## Krallık rengine uydurma: ton kaydırma, doygunluk/parlaklık, gri figürü boyama.
## Kenar çizgisi gibi çok koyu pikseller olduğu gibi kalır. Her zaman kopya döner: aynı kaynak
## resim birkaç karede paylaşılıyor (hamle kareleri), sonradan büyütme hepsini etkilemesin.
func _recolor(src: Image, spec: Dictionary) -> Image:
	var hue: float = spec.get("hue", 0.0)
	var sat: float = spec.get("sat", 1.0)
	var val: float = spec.get("val", 1.0)
	var colorize: float = spec.get("colorize", -1.0)
	var out := src.duplicate() as Image
	if hue == 0.0 and sat == 1.0 and val == 1.0 and colorize < 0.0:
		return out
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a == 0.0 or c.v < 0.18:
				continue
			var h := fposmod(c.h + hue, 1.0)
			var s := clampf(c.s * sat, 0.0, 1.0)
			if colorize >= 0.0:
				h = colorize
				s = maxf(s, 0.55)
			out.set_pixel(x, y, Color.from_hsv(h, s, clampf(c.v * val, 0.0, 1.0), c.a))
	return out
