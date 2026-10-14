extends SceneTree
## Zemin dokularını piksel sanata çevirir (görsel yön A, görev 2.3).
##   godot --headless --path Fetih -s res://tools/build_ground.gd
##   Sonra: godot --headless --path Fetih --import
## Girdi (Godot dışı, CC0 rubberduck): kaynak_assetler/rubberduck_grassland/sheet_ground_128x64_shaded.png
## ve kaynak_assetler/rubberduck_plants/*.png. Çıktı: Fetih/assets/terrain/px/
##  - ground_<biyom>.png: 8 sütun x 8 satır, hücre 64x64 (1x dünya pikseli).
##    Satır 0 alt yarısı (y 32..63): 64x32 çimen karoları (alan içi). Satır 1-2 ot, 3 bitki, 4 kuru ot,
##    5-6 kaya: 64x64 süsler. Satır 7 alt yarısı: 64x32 koyu çimen (alanın dışı, eski modulate yerine).
##  - plants/<ad>.png: ağaç/çalı, 0.34x (eski TREE_SCALE; dünyada yaklaşık 87 px).
## Her şey 0.5x/0.34x alan ortalamasıyla küçültülür, alfa 1 bit'e çevrilir, biyom tonu uygulanır ve
## Resurrect 64 paletine indirilir (palet dışı piksel yok). Biyom tonları GroundArt.BIOMES'tan gelir.

const SRC_SHEET := "../kaynak_assetler/rubberduck_grassland/sheet_ground_128x64_shaded.png"
const SRC_PLANTS := "../kaynak_assetler/rubberduck_plants/"
const OUT_DIR := "res://assets/terrain/px/"
const SRC_CELL := 128
const CELL := 64
const COLUMNS := 8
const ROWS := 8
const TREE_SCALE := 0.34
const ALPHA_CUT := 0.5
const TREE_TARGET_V := 0.6  ## ağacın en açık %5'i bu parlaklığa gelecek şekilde kazanç
const TREE_SAT := 1.2
const TREE_GREEN_HUE := 0.40  ## Resurrect 64 yeşilleri (239063, 1ebc73) ~0.40-0.43
const TREE_HUE_PULL := 0.65
const DARK_SHARE := 0.55  ## karo pikselinin bu oranı rampanın koyu rengi
const LIGHT_FROM := 0.96  ## bu yüzdelikten sonrası açık renk
## Çim karosunda alfa maskesi elmasa uyar: kenar piksellerini komşu karoya doğru 1/16 şişir, çizimde
## karolar üst üste biner ve arada boşluk kalmaz.
const DIAMOND_SLACK := 1.0 + 1.0 / 16.0


func _init() -> void:
	var biomes: Dictionary = load("res://scripts/battle/ground_art.gd").BIOMES
	var root := ProjectSettings.globalize_path("res://")
	var sheet := Image.load_from_file(root.path_join(SRC_SHEET))
	if sheet == null:
		push_error("kaynak zemin sayfası yok: " + SRC_SHEET)
		quit(1)
		return
	sheet.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + "plants/"))
	# 1) Zemin: önce 0.5x küçült (tint'siz). Çimen karoları (satır 0 ve 7) biyomun rampasına luma
	# yüzdeliğine göre dağıtılır; süsler (satır 1-6) biyom tonuyla boyanıp palete indirilir.
	var small := _downscale(sheet, sheet.get_width() / 2, sheet.get_height() / 2)
	var luma := _blurred_luma(small)
	var cuts := _luma_cuts(luma)
	var total_off := 0
	for biome: StringName in biomes:
		var tint: Color = biomes[biome].tint
		var ramp: Array[Color] = []
		for hex: String in biomes[biome].ramp:
			ramp.append(Color(hex))
		var dark := SpritePalette.nearest_step(ramp[0], ramp[0], false)
		var outside_ramp: Array[Color] = [dark, ramp[0], ramp[1]]
		var out := Image.create_empty(CELL * COLUMNS, CELL * ROWS, false, Image.FORMAT_RGBA8)
		var src_rows := small.get_height() / CELL
		for row in src_rows:
			out.blit_rect(small, Rect2i(0, row * CELL, CELL * COLUMNS, CELL), Vector2i(0, row * CELL))
		# Satır 7: alan dışı koyu çimen = satır 0'ın bir kademe koyu rampası.
		out.blit_rect(small, Rect2i(0, 0, CELL * COLUMNS, CELL), Vector2i(0, 7 * CELL))
		var decals := out.get_region(Rect2i(0, CELL, CELL * COLUMNS, 6 * CELL))
		_tint(decals, tint)
		out.blit_rect(decals, Rect2i(0, 0, CELL * COLUMNS, 6 * CELL), Vector2i(0, CELL))
		_ramp_map(out, 0, ramp, luma, cuts)
		_ramp_map(out, 7, outside_ramp, luma, cuts)
		for row in [0, 7]:
			_diamond_mask(out, row)
		var off := SpritePalette.off_palette_count(out, Color(-1, -1, -1))
		total_off += off
		var path := OUT_DIR + "ground_%s.png" % biome
		var err := out.save_png(path)
		print("%s  %dx%d  palet dışı: %d  %s" % [path, out.get_width(), out.get_height(), off,
				"ok" if err == OK else error_string(err)])
	# 2) Ağaçlar ve çalılar: tek set (biyoma göre tonlanmıyordu), palete indirilir.
	var prefixes := {}
	for biome: StringName in biomes:
		for p: String in biomes[biome].trees:
			prefixes[p] = true
	var made := 0
	for file in DirAccess.get_files_at(root.path_join(SRC_PLANTS)):
		if not file.ends_with(".png"):
			continue
		var wanted := false
		for p: String in prefixes:
			wanted = wanted or file.begins_with(p)
		if not wanted:
			continue
		var img := Image.load_from_file(root.path_join(SRC_PLANTS).path_join(file))
		img.convert(Image.FORMAT_RGBA8)
		var w := maxi(1, roundi(img.get_width() * TREE_SCALE))
		var h := maxi(1, roundi(img.get_height() * TREE_SCALE))
		var px := _downscale(img, w, h)
		_lift(px)
		_soften_shadow(px, file)
		total_off += SpritePalette.off_palette_count(px, Color(-1, -1, -1))
		px.save_png(OUT_DIR + "plants/" + file)
		made += 1
	print("%d bitki/ağaç yazıldı. Palet dışı piksel toplamı: %d (hedef 0)" % [made, total_off])
	print("Şimdi: godot --headless --path Fetih --import")
	quit()


## Alan ağırlıklı (kutu) küçültme: saydam pikseller rengi kirletmez; alfa 1 bit'e çevrilir.
static func _downscale(src: Image, out_w: int, out_h: int) -> Image:
	var out := Image.create_empty(out_w, out_h, false, Image.FORMAT_RGBA8)
	var sx := float(src.get_width()) / out_w
	var sy := float(src.get_height()) / out_h
	for y in out_h:
		for x in out_w:
			var x0 := x * sx
			var y0 := y * sy
			var r := 0.0
			var g := 0.0
			var b := 0.0
			var a := 0.0
			var weight := 0.0
			var ix := floori(x0)
			while ix < ceili(x0 + sx):
				var iy := floori(y0)
				while iy < ceili(y0 + sy):
					# Kaynak pikselin hedef hücreyle örtüşme alanı.
					var wx := minf(ix + 1.0, x0 + sx) - maxf(float(ix), x0)
					var wy := minf(iy + 1.0, y0 + sy) - maxf(float(iy), y0)
					var wgt := wx * wy
					if wgt > 0.0 and ix < src.get_width() and iy < src.get_height():
						var c := src.get_pixel(ix, iy)
						r += c.r * c.a * wgt
						g += c.g * c.a * wgt
						b += c.b * c.a * wgt
						a += c.a * wgt
						weight += wgt
					iy += 1
				ix += 1
			if weight <= 0.0 or a / weight < ALPHA_CUT:
				continue
			out.set_pixel(x, y, Color(r / a, g / a, b / a, 1.0))
	return out


## Çimen karolarının (satır 0 alt yarısı) 3x3 bulanık luması: piksel gürültüsü yerine yumuşak lekeler
## çıksın diye eşikleme bulanık değer üzerinden yapılır. Saydam piksel = -1.
static func _blurred_luma(small: Image) -> PackedFloat32Array:
	var w := CELL * COLUMNS
	var h := CELL / 2
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in h:
		for x in w:
			var sum := 0.0
			var n := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var px := x + dx
					var py := y + dy
					# Komşu başka karoya taşmasın: sütun hücre sınırında kırpılır.
					if px < 0 or px >= w or py < 0 or py >= h or px / CELL != x / CELL:
						continue
					var c := small.get_pixel(px, h + py)
					if c.a > 0.0:
						sum += SpritePalette.luma(c)
						n += 1
			var center := small.get_pixel(x, h + y)
			out[y * w + x] = sum / n if center.a > 0.0 and n > 0 else -1.0
	return out


## Bulanık luma dağılımından iki eşik: alt DARK_SHARE koyu, üst %(1-LIGHT_FROM) açık.
static func _luma_cuts(luma: PackedFloat32Array) -> Vector2:
	var lumas: Array[float] = []
	for l in luma:
		if l >= 0.0:
			lumas.append(l)
	lumas.sort()
	return Vector2(lumas[int(lumas.size() * DARK_SHARE)], lumas[int(lumas.size() * LIGHT_FROM)])


## Satırın alt yarısını (karolar) rampaya boyar: bulanık luma eşiklerine göre koyu / orta / açık.
static func _ramp_map(img: Image, row: int, ramp: Array[Color], luma: PackedFloat32Array, cuts: Vector2) -> void:
	var w := CELL * COLUMNS
	for y in CELL / 2:
		for x in w:
			var l := luma[y * w + x]
			if l < 0.0:
				continue
			img.set_pixel(x, row * CELL + CELL / 2 + y, ramp[0] if l < cuts.x else (ramp[1] if l < cuts.y else ramp[2]))


## Ağaç/çalı: orijinal dokular çok koyu; doğrudan en yakın palet rengi hepsini mor-siyaha düşürüyor.
## Her görselde en açık %5 hedef parlaklığa gelecek kazanç uygulanır (ton korunur), sonra palete oturur.
static func _lift(img: Image) -> void:
	var values: Array[float] = []
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				values.append(c.v)
	if values.is_empty():
		return
	values.sort()
	var gain := clampf(TREE_TARGET_V / maxf(values[int(values.size() * 0.95)], 0.01), 1.0, 8.0)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var hue := c.h
			if c.s > 0.12 and hue > 0.15 and hue < 0.5:
				hue = lerpf(hue, TREE_GREEN_HUE, TREE_HUE_PULL)  # sarı-yeşil -> palet yeşili (zeytin olmasın)
			var lifted := Color.from_hsv(hue, clampf(c.s * TREE_SAT, 0.0, 1.0), clampf(c.v * gain, 0.0, 1.0))
			img.set_pixel(x, y, SpritePalette.nearest(lifted))


## Kaynak ağaçlardaki iri koyu mor/siyah gölge lekesini siler (görüntünün alt kısmındaki koyu pikseller),
## yerine ağacın altına küçük, koyu yeşil bir gölge elipsi koyar. Ağaç/çalı tacındaki en koyu tonlar
## (2e222f, 3e3546) koyu yeşile çekilir: taç zeminden net ayrılır. Çamların gri-mavi tonlarına dokunulmaz.
static func _soften_shadow(img: Image, file: String) -> void:
	var used := img.get_used_rect()
	if used.size.x == 0:
		return
	var is_pine := file.begins_with("pine")
	var cut := used.position.y + roundi(used.size.y * (0.72 if is_pine else 0.6))
	var dark_green := Color("165a4c")
	var side := used.size.x * 0.35
	var mid_x := used.position.x + used.size.x / 2
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			# Gövdeden yana uzanan ince gölge çizgisi (alt %40, orta bölgenin dışı, koyu): silinir.
			if y >= used.position.y + used.size.y * 0.6 and absf(x - mid_x) > side and c.v < 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif y >= cut and c.v < 0.42:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif c.v <= 0.3 and not is_pine:
				# Taç/çalı: en koyu tonlar koyu yeşile çekilir.
				img.set_pixel(x, y, dark_green)
	used = img.get_used_rect()
	# Küçük gölge: ağacın altında ince koyu yeşil elips (genişlik tacın ~%35'i).
	var rx := maxi(2, roundi(used.size.x * 0.17))
	var bottom := used.end.y - roundi(used.size.y * 0.12)
	var cx := used.position.x + used.size.x / 2
	for dy in range(-1, 2):
		var half := rx if dy == 0 else rx - 2
		for dx in range(-half, half + 1):
			var px_x := cx + dx
			var px_y := bottom + dy
			if px_x >= 0 and px_x < img.get_width() and px_y >= 0 and px_y < img.get_height() 					and img.get_pixel(px_x, px_y).a == 0.0:
				img.set_pixel(px_x, px_y, dark_green)


## Rengi tonla çarpar ve palete indirir (saydam piksellere dokunmaz).
static func _tint(img: Image, tint: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var t := Color(minf(c.r * tint.r, 1.0), minf(c.g * tint.g, 1.0), minf(c.b * tint.b, 1.0), 1.0)
			img.set_pixel(x, y, SpritePalette.nearest(t))


## Satırın alt yarısındaki karoları 64x32 elmasa göre kırpar (1/16 şişkin), kenarlarda yarım kalan
## yumuşak piksel kalmasın. Çimen karosu elmas dışında zaten saydam; maske sadece boşluğu kapatır.
static func _diamond_mask(img: Image, row: int) -> void:
	for col in COLUMNS:
		var ox := col * CELL
		var oy := row * CELL + CELL / 2
		# Elmasın içinde kalıp saydam kalan pikselleri (kenar) komşu renkle doldur.
		for y in CELL / 2:
			for x in CELL:
				var dx := absf(x + 0.5 - CELL / 2.0) / (CELL / 2.0)
				var dy := absf(y + 0.5 - CELL / 4.0) / (CELL / 4.0)
				var inside := dx + dy <= DIAMOND_SLACK
				var c := img.get_pixel(ox + x, oy + y)
				if inside and c.a == 0.0:
					var fill := _nearest_opaque(img, ox, oy, x, y)
					if fill.a > 0.0:
						img.set_pixel(ox + x, oy + y, fill)
				elif not inside and c.a > 0.0:
					img.set_pixel(ox + x, oy + y, Color(0, 0, 0, 0))


static func _nearest_opaque(img: Image, ox: int, oy: int, x: int, y: int) -> Color:
	for r in range(1, 4):
		for d in [Vector2i(0, -r), Vector2i(0, r), Vector2i(-r, 0), Vector2i(r, 0)]:
			var px: int = x + d.x
			var py: int = y + d.y
			if px < 0 or py < 0 or px >= CELL or py >= CELL / 2:
				continue
			var c := img.get_pixel(ox + px, oy + py)
			if c.a > 0.0:
				return c
	return Color(0, 0, 0, 0)
