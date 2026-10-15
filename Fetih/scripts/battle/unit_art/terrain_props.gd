class_name TerrainProps
## Krallık manzara süsleri (mezar taşı, lav çatlağı, kristal, gölcük...): koddan çizilen küçük piksel resimler.
## Her krallığın savaş alanı kendi süsleriyle tanınsın (GroundArt.BIOMES[id].props). Sadece görüntü.
## Renkler Resurrect 64 paletinden; resmin alt ortası yere değen noktadır (GroundArt oraya oturtur).
## flat: yere yapışık (gölcük, lav, sis), birliklerin altında çizilir. glow: parlayan kısmı ayrı resim
## (glow_image), GroundArt onu yavaşça "nefes aldırır".
## Godot: Image piksel piksel çizilir, ImageTexture önbelleğe alınır; çizim seed'li RNG ile deterministik.

const OUTLINE := Color("2e222f")
const VARIANTS := 3

const KINDS := {
	&"wheat": {size = Vector2i(16, 12), glow = false, flat = false},
	&"fence": {size = Vector2i(18, 11), glow = false, flat = false},
	&"hay": {size = Vector2i(13, 11), glow = false, flat = false},
	&"giant_tree": {size = Vector2i(26, 36), glow = false, flat = false},
	&"mushroom": {size = Vector2i(9, 9), glow = false, flat = false},
	&"firefly": {size = Vector2i(9, 9), glow = true, flat = false},
	&"bones": {size = Vector2i(14, 8), glow = false, flat = false},
	&"spikes": {size = Vector2i(16, 15), glow = false, flat = false},
	&"dry_bush": {size = Vector2i(13, 10), glow = false, flat = false},
	&"rock": {size = Vector2i(15, 11), glow = false, flat = false},
	&"minecart": {size = Vector2i(15, 12), glow = false, flat = false},
	&"crystal_vein": {size = Vector2i(15, 12), glow = true, flat = false},
	&"tombstone": {size = Vector2i(11, 15), glow = false, flat = false},
	&"dead_tree": {size = Vector2i(17, 25), glow = false, flat = false},
	&"fog": {size = Vector2i(26, 9), glow = false, flat = true},
	&"lava_crack": {size = Vector2i(22, 9), glow = true, flat = true},
	&"obsidian": {size = Vector2i(11, 17), glow = false, flat = false},
	&"pond": {size = Vector2i(24, 11), glow = false, flat = true},
	&"bubble": {size = Vector2i(7, 7), glow = true, flat = false},
	&"puddle": {size = Vector2i(20, 9), glow = false, flat = true},
	&"reeds": {size = Vector2i(11, 15), glow = false, flat = false},
	&"crystal": {size = Vector2i(13, 18), glow = true, flat = false},
	&"ruin_pillar": {size = Vector2i(11, 21), glow = false, flat = false},
	&"savanna_grass": {size = Vector2i(14, 11), glow = false, flat = false},
	&"acacia": {size = Vector2i(28, 25), glow = false, flat = false},
}

static var _textures := {}  ## "tür|varyant|glow" -> Texture2D


static func texture(kind: StringName, variant: int, glow := false) -> Texture2D:
	var key := "%s|%d|%s" % [kind, variant, glow]
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(glow_image(kind, variant) if glow else image(kind, variant))
	return _textures[key]


## Süsün resmi (KINDS[kind].size). variant: 0..VARIANTS-1, şekli ve ayrıntıyı değiştirir.
static func image(kind: StringName, variant: int) -> Image:
	return _render(kind, variant)[0]


## Parlayan kısım (aynı boyut, sadece ışıklı pikseller). glow olmayan türde boş resim.
static func glow_image(kind: StringName, variant: int) -> Image:
	return _render(kind, variant)[1]


static func _render(kind: StringName, variant: int) -> Array[Image]:
	var size: Vector2i = KINDS[kind].size
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var lit := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(kind)) + variant * 7919
	var outline := true
	match kind:
		&"wheat": _wheat(img, rng)
		&"fence": _fence(img, rng)
		&"hay": _hay(img, rng)
		&"giant_tree": _giant_tree(img, rng)
		&"mushroom": _mushroom(img, rng)
		&"firefly":
			_firefly(img, lit, rng)
			outline = false
		&"bones": _bones(img, rng)
		&"spikes": _spikes(img, rng)
		&"dry_bush": _dry_bush(img, rng)
		&"rock": _rock(img, rng)
		&"minecart": _minecart(img, rng)
		&"crystal_vein": _crystal_vein(img, lit, rng)
		&"tombstone": _tombstone(img, rng)
		&"dead_tree": _dead_tree(img, rng)
		&"fog":
			_fog(img, rng)
			outline = false
		&"lava_crack":
			_lava_crack(img, lit, rng)
			outline = false
		&"obsidian": _obsidian(img, rng)
		&"pond": _pond(img, rng)
		&"bubble": _bubble(img, lit, rng)
		&"puddle": _puddle(img, rng)
		&"reeds": _reeds(img, rng)
		&"crystal": _crystal(img, lit, rng)
		&"ruin_pillar": _ruin_pillar(img, rng)
		&"savanna_grass": _savanna_grass(img, rng)
		&"acacia": _acacia(img, rng)
	if outline:
		_add_outline(img)
	return [img, lit]


# --- Çizim yardımcıları ---

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _fill(img: Image, r: Rect2i, c: Color) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_px(img, x, y, c)


## Dolu elips (merkez, yarıçaplar); shade: üst-sol açık, alt-sağ koyu renk (boşsa düz).
static func _ellipse(img: Image, center: Vector2, radius: Vector2, c: Color,
		light := Color(0, 0, 0, 0), dark := Color(0, 0, 0, 0)) -> void:
	for y in range(floori(center.y - radius.y), ceili(center.y + radius.y) + 1):
		for x in range(floori(center.x - radius.x), ceili(center.x + radius.x) + 1):
			var d := Vector2((x - center.x) / radius.x, (y - center.y) / radius.y)
			if d.length_squared() > 1.0:
				continue
			var col := c
			if light.a > 0.0 and d.x + d.y < -0.7:
				col = light
			elif dark.a > 0.0 and d.x + d.y > 0.6:
				col = dark
			_px(img, x, y, col)


static func _line(img: Image, a: Vector2i, b: Vector2i, c: Color) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in steps + 1:
		var t := float(i) / maxf(steps, 1)
		_px(img, roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)), c)


## Dolu piksellere 4 yönde komşu boş pikseller koyu kenar olur.
static func _add_outline(img: Image) -> void:
	var edge: Array[Vector2i] = []
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < img.get_width() and n.y < img.get_height() \
						and img.get_pixelv(n).a > 0.0:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		img.set_pixelv(p, OUTLINE)


# --- Süsler ---

static func _wheat(img: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for x in range(1, w - 1, 2):
		var top := rng.randi_range(1, 4)
		for y in range(top + 2, h - 1):
			_px(img, x, y, Color("ab947a") if y > h - 4 else Color("f9c22b"))
		_px(img, x, top, Color("fbb954"))
		_px(img, x, top + 1, Color("fbb954"))
		_px(img, x - 1, top + 1, Color("f9c22b"))


static func _fence(img: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var posts := [1, w / 2, w - 3]
	for px: int in posts:
		_fill(img, Rect2i(px, 1 + rng.randi_range(0, 1), 2, h - 2), Color("694f62"))
		_px(img, px, 1, Color("966c6c"))
	for y in [3, 6]:
		_line(img, Vector2i(1, y), Vector2i(w - 2, y + rng.randi_range(-1, 1)), Color("966c6c"))


static func _hay(img: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	_ellipse(img, Vector2(w / 2.0, h / 2.0 + 1), Vector2(w / 2.0 - 1, h / 2.0 - 1),
			Color("fbb954"), Color("fbff86"), Color("e6904e"))
	for i in 4:
		var x := rng.randi_range(2, w - 3)
		_line(img, Vector2i(x, 3), Vector2i(x + rng.randi_range(-1, 1), h - 3), Color("e6904e"))


static func _giant_tree(img: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	_fill(img, Rect2i(w / 2 - 2, h - 14, 4, 13), Color("694f62"))
	_fill(img, Rect2i(w / 2 - 2, h - 14, 1, 13), Color("966c6c"))
	_px(img, w / 2 - 3, h - 2, Color("694f62"))
	_px(img, w / 2 + 2, h - 2, Color("694f62"))
	_ellipse(img, Vector2(w / 2.0, 11), Vector2(w / 2.0 - 1, 10), Color("239063"), Color("1ebc73"), Color("165a4c"))
	for i in 3:  # yaprak öbekleri
		var c := Vector2(rng.randf_range(5, w - 5), rng.randf_range(5, 15))
		_ellipse(img, c, Vector2(3, 2), Color("1ebc73"), Color("91db69"))


static func _mushroom(img: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	_fill(img, Rect2i(w / 2 - 1, h - 4, 2, 3), Color("c7dcd0"))
	_ellipse(img, Vector2(w / 2.0 - 0.5, h - 5.5), Vector2(3.5, 2.2), Color("e83b3b"), Color("f68181"), Color("ae2334"))
	_px(img, w / 2 - 2 + rng.randi_range(0, 1), h - 6, Color("ffffff"))
	_px(img, w / 2 + 1, h - 5, Color("ffffff"))


static func _firefly(img: Image, lit: Image, rng: RandomNumberGenerator) -> void:
	for i in 3:
		var p := Vector2i(rng.randi_range(1, img.get_width() - 2), rng.randi_range(1, img.get_height() - 2))
		_px(img, p.x, p.y, Color("a2a947"))
		_px(lit, p.x, p.y, Color("fbff86"))
		_px(lit, p.x + 1, p.y, Color("d5e04b"))


static func _bones(img: Image, rng: RandomNumberGenerator) -> void:
	var h := img.get_height()
	_line(img, Vector2i(1, h - 2), Vector2i(9, h - 5), Color("c7dcd0"))
	_line(img, Vector2i(2, h - 5), Vector2i(8, h - 2), Color("9babb2"))
	for p in [Vector2i(1, h - 3), Vector2i(9, h - 6), Vector2i(2, h - 6), Vector2i(8, h - 1)]:
		_px(img, p.x, p.y, Color("ffffff"))
	_ellipse(img, Vector2(11.5, h - 4.0), Vector2(1.6, 1.6), Color("c7dcd0"))  # kafatası
	_px(img, 11 + rng.randi_range(0, 1), h - 4, Color("3e3546"))


static func _spikes(img: Image, rng: RandomNumberGenerator) -> void:
	var h := img.get_height()
	for i in 3:
		var x := 2 + i * 5
		var top := 1 + rng.randi_range(0, 3)
		_fill(img, Rect2i(x, top + 2, 2, h - top - 3), Color("694f62"))
		_px(img, x, top + 1, Color("966c6c"))
		_px(img, x + 1, top + 1, Color("966c6c"))
		_px(img, x, top, Color("ab947a"))
	_line(img, Vector2i(1, h - 5), Vector2i(img.get_width() - 2, h - 6), Color("4c3e24"))


static func _dry_bush(img: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var base := Vector2i(w / 2, h - 1)
	for i in 6:
		var tip := Vector2i(rng.randi_range(1, w - 2), rng.randi_range(1, h / 2))
		_line(img, base, tip, Color("966c6c") if i % 2 == 0 else Color("ab947a"))


static func _rock(img: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var r := Vector2(rng.randf_range(4.0, w / 2.0 - 1), rng.randf_range(3.0, h / 2.0 - 1))
	_ellipse(img, Vector2(w / 2.0, h - r.y - 1), r, Color("625565"), Color("9babb2"), Color("3e3546"))
	if rng.randf() < 0.6:
		_ellipse(img, Vector2(w / 2.0 + r.x * 0.8, h - 2.5), Vector2(2, 1.5), Color("7f708a"), Color("9babb2"))


static func _minecart(img: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	_fill(img, Rect2i(2, 3, w - 4, h - 6), Color("625565"))
	_fill(img, Rect2i(2, 3, w - 4, 1), Color("9babb2"))
	_fill(img, Rect2i(2, 3, 1, h - 6), Color("7f708a"))
	for i in 4:  # cevher
		_px(img, rng.randi_range(3, w - 4), 2, Color("f9c22b") if i % 2 == 0 else Color("fbb954"))
	for x in [4, w - 5]:
		_ellipse(img, Vector2(x, h - 2.5), Vector2(1.5, 1.5), Color("3e3546"), Color("625565"))


static func _crystal_vein(img: Image, lit: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	_ellipse(img, Vector2(w / 2.0, h - 4.0), Vector2(w / 2.0 - 1, 3.5), Color("625565"), Color("9babb2"), Color("3e3546"))
	for i in 3:
		var x := rng.randi_range(3, w - 4)
		var top := rng.randi_range(1, 4)
		for y in range(top, h - 3):
			_px(img, x, y, Color("4d9be6"))
		_px(img, x, top, Color("8fd3ff"))
		_px(lit, x, top, Color("8fd3ff"))
		_px(lit, x, top + 1, Color("4d9be6"))


static func _tombstone(img: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var top := rng.randi_range(1, 3)
	_fill(img, Rect2i(2, top + 2, w - 4, h - top - 4), Color("9babb2"))
	_fill(img, Rect2i(3, top + 1, w - 6, 1), Color("9babb2"))
	_fill(img, Rect2i(4, top, w - 8, 1), Color("c7dcd0"))
	_fill(img, Rect2i(w - 3, top + 2, 1, h - top - 4), Color("625565"))  # sağ gölge
	_line(img, Vector2i(w / 2, top + 3), Vector2i(w / 2, top + 7), Color("625565"))  # haç
	_line(img, Vector2i(w / 2 - 1, top + 4), Vector2i(w / 2 + 1, top + 4), Color("625565"))
	_fill(img, Rect2i(1, h - 2, w - 2, 2), Color("4c3e24"))  # toprak


static func _dead_tree(img: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var x := w / 2
	_fill(img, Rect2i(x - 1, 8, 2, h - 9), Color("694f62"))
	_fill(img, Rect2i(x - 1, 8, 1, h - 9), Color("966c6c"))
	for i in 4:
		var y := rng.randi_range(4, h - 10)
		var dir := -1 if i % 2 == 0 else 1
		var tip := Vector2i(x + dir * rng.randi_range(4, w / 2 - 1), y - rng.randi_range(2, 5))
		_line(img, Vector2i(x, y + 3), tip, Color("694f62"))
	_line(img, Vector2i(x, 8), Vector2i(x + rng.randi_range(-2, 2), 1), Color("694f62"))


static func _fog(img: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for i in 3:
		var c := Vector2(rng.randf_range(6, w - 6), rng.randf_range(3, h - 3))
		_ellipse(img, c, Vector2(rng.randf_range(4, 7), 2.5), Color("c7dcd0", 0.22))


static func _lava_crack(img: Image, lit: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var y := h / 2
	for x in range(1, w - 1):
		y = clampi(y + rng.randi_range(-1, 1), 2, h - 3)
		_px(img, x, y - 1, Color("6e2727"))
		_px(img, x, y + 1, Color("6e2727"))
		_px(img, x, y, Color("fb6b1d"))
		_px(lit, x, y, Color("f9c22b") if x % 3 else Color("fbb954"))
		if rng.randf() < 0.15:  # yan çatlak
			_px(img, x, y + 2, Color("b33831"))


static func _obsidian(img: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var tip := Vector2i(w / 2 + rng.randi_range(-1, 1), 1)
	for y in range(tip.y, h - 1):
		var half := roundi(float(y - tip.y) / (h - 2 - tip.y) * (w / 2.0 - 1))
		for x in range(tip.x - half, tip.x + half + 1):
			_px(img, x, y, Color("6b3e75") if x < tip.x else Color("45293f"))
	_line(img, tip, Vector2i(tip.x - 2, h - 3), Color("905ea9"))


static func _pond(img: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	_ellipse(img, Vector2(w / 2.0, h / 2.0), Vector2(w / 2.0 - 1, h / 2.0 - 1), Color("165a4c"))
	_ellipse(img, Vector2(w / 2.0, h / 2.0), Vector2(w / 2.0 - 2.5, h / 2.0 - 2), Color("0b8a8f"), Color("0eaf9b"))
	for i in 3:
		_px(img, rng.randi_range(5, w - 6), rng.randi_range(3, h - 4), Color("8ff8e2"))


static func _bubble(img: Image, lit: Image, _rng: RandomNumberGenerator) -> void:
	var c := Vector2(3, 3)
	for y in 7:
		for x in 7:
			var d := Vector2(x, y).distance_to(c)
			if d <= 2.6 and d > 1.5:
				_px(img, x, y, Color("30e1b9"))
	_px(img, 2, 2, Color("8ff8e2"))
	_px(lit, 2, 2, Color("ffffff"))
	_px(lit, 3, 2, Color("8ff8e2"))


static func _puddle(img: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	_ellipse(img, Vector2(w / 2.0, h / 2.0), Vector2(w / 2.0 - 1, h / 2.0 - 1), Color("4c3e24"))
	_ellipse(img, Vector2(w / 2.0 + 1, h / 2.0), Vector2(w / 2.0 - 4, h / 2.0 - 2.5), Color("676633"))
	_px(img, rng.randi_range(4, w - 5), h / 2 - 1, Color("a2a947"))


static func _reeds(img: Image, rng: RandomNumberGenerator) -> void:
	var h := img.get_height()
	for x in range(1, img.get_width() - 1, 2):
		var top := rng.randi_range(1, 6)
		for y in range(top + 2, h - 1):
			_px(img, x, y, Color("676633") if x % 4 == 1 else Color("a2a947"))
		_px(img, x, top, Color("694f62"))
		_px(img, x, top + 1, Color("694f62"))


static func _crystal(img: Image, lit: Image, rng: RandomNumberGenerator) -> void:
	var h := img.get_height()
	var shards := [[img.get_width() / 2, 1, 2], [2, 6, 1], [img.get_width() - 4, 5, 1]]
	for s: Array in shards:
		var cx: int = s[0] + rng.randi_range(-1, 1)
		var top: int = s[1] + rng.randi_range(0, 2)
		var half: int = s[2]
		for y in range(top, h - 1):
			var hw := mini(half, (y - top) / 2)
			for x in range(cx - hw, cx + hw + 1):
				_px(img, x, y, Color("8fd3ff") if x < cx else Color("4d9be6"))
		_px(img, cx, top, Color("ffffff"))
		for y in range(top, top + 3):
			_px(lit, cx, y, Color("8fd3ff"))
		_px(lit, cx, top, Color("ffffff"))
	_fill(img, Rect2i(1, h - 2, img.get_width() - 2, 1), Color("484a77"))


static func _ruin_pillar(img: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var top := rng.randi_range(2, 7)
	_fill(img, Rect2i(1, h - 3, w - 2, 2), Color("9babb2"))  # taban
	_fill(img, Rect2i(3, top, w - 6, h - top - 3), Color("c7dcd0"))
	_fill(img, Rect2i(w - 4, top, 1, h - top - 3), Color("9babb2"))
	for x in range(3, w - 3):  # kırık tepe
		_px(img, x, top - rng.randi_range(0, 2), Color("c7dcd0"))
	for y in range(top + 2, h - 3, 3):  # yivler
		_px(img, w / 2, y, Color("9babb2"))


static func _savanna_grass(img: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for i in 7:
		var x := rng.randi_range(1, w - 2)
		_line(img, Vector2i(x, h - 1), Vector2i(x + rng.randi_range(-2, 2), rng.randi_range(1, 5)),
				Color("cddf6c") if i % 2 == 0 else Color("a2a947"))


static func _acacia(img: Image, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var x := w / 2 + rng.randi_range(-2, 2)
	_line(img, Vector2i(x, h - 1), Vector2i(x - 1, 9), Color("694f62"))
	_line(img, Vector2i(x + 1, h - 1), Vector2i(x, 9), Color("966c6c"))
	_line(img, Vector2i(x, 12), Vector2i(x + 6, 7), Color("694f62"))
	_line(img, Vector2i(x, 13), Vector2i(x - 6, 8), Color("694f62"))
	_ellipse(img, Vector2(w / 2.0, 5), Vector2(w / 2.0 - 1, 3.5), Color("547e64"), Color("92a984"), Color("374e4a"))
