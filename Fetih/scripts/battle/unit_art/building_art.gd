class_name BuildingArt
extends RefCounted
## Krallık kamp ve kale yapıları (koddan piksel sanatı; sadece görüntü). 9 Kings tarzı: tıknaz,
## izometrik 2:1 kutular ve çatılar, sol yüz açık, sağ yüz koyu, 1 px koyu çerçeve (2e222f).
## Her parça sabit bir tuvalde çizilir (W x H); yerin değdiği nokta ANCHOR (KingdomCamp bunu konuma oturtur).
## piece(): gövde (+ istenirse parlayan kısım), glow(): sadece parlayan kısım (aynı tuval, ayrı Sprite2D).
## Her şey sonunda Resurrect 64 paletine indirilir.

const W := 48
const H := 60
const ANCHOR := Vector2i(24, 50)  ## Zemin temas noktası (footprint merkezi).
const FRAME := Color("2e222f")
const NONE := Color(0, 0, 0, 0)
const FLAME_OUT := Color("f79617")
const FLAME_MID := Color("f9c22b")
const FLAME_CORE := Color("fbff86")
const WOOD := Color("966c6c")
const BONE := Color("c7dcd0")
const DARK_ROCK := Color("625565")

static var _cache := {}


## Parça görseli. with_glow: parlayan kısım da gövdeye basılır (tek görsel isteyenler için).
static func piece(kind: StringName, main: Color, accent: Color, with_glow := true) -> Image:
	var key := "%s|%s|%s|%s" % [kind, main.to_html(), accent.to_html(), with_glow]
	if not _cache.has(key):
		var parts := _build(kind, main, accent)
		var body: Image = parts[0]
		if with_glow:
			SpritePainter.stamp(body, parts[1])
		SpritePainter.outline(body, FRAME)
		SpritePalette.quantize(body, FRAME)
		_cache[key] = body
	return (_cache[key] as Image).duplicate()


## Sadece parlayan kısım (pencere, alev, rün): gövdeyle aynı tuval ve konum, çerçevesiz.
static func glow(kind: StringName, main: Color, accent: Color) -> Image:
	var key := "%s|%s|%s|glow" % [kind, main.to_html(), accent.to_html()]
	if not _cache.has(key):
		var lit: Image = _build(kind, main, accent)[1]
		SpritePalette.quantize(lit, FRAME)
		_cache[key] = lit
	return (_cache[key] as Image).duplicate()


static func has_glow(kind: StringName) -> bool:
	return glow(kind, Color.WHITE, Color.WHITE).get_used_rect().size.x > 0


static func _build(kind: StringName, main: Color, accent: Color) -> Array[Image]:
	var body := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var lit := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var s := _stone(main)
	var m := SpritePainter.ramp(main)
	var a := SpritePainter.ramp(accent)
	match kind:
		&"wall": _wall(body, s, m)
		&"tower": _tower(body, lit, s, m, a)
		&"tent": _tent(body, m, a)
		&"banner": _banner(body, m, a)
		&"fire": _fire(body, lit)
		&"signature_humans": _humans(body, lit, s, m, a)
		&"signature_elves": _elves(body, lit, m, a)
		&"signature_orcs": _orcs(body, lit, m, a)
		&"signature_dwarves": _dwarves(body, lit, s, m, a)
		&"signature_undead": _undead(body, lit, s, m, a)
		&"signature_demons": _demons(body, lit, m, a)
		&"signature_slimes": _slimes(body, lit, m, a)
		&"signature_mud": _mud(body, lit, m, a)
		&"signature_golems": _golems(body, lit, s, m, a)
		&"signature_centaurs": _centaurs(body, lit, m, a)
		_: _tower(body, lit, s, m, a)
	var out: Array[Image] = [body, lit]
	return out


# --- Renkler ---

## Krallık rengine hafif çalan taş rampası: [en koyu, gölge, ana, ışık].
static func _stone(main: Color) -> Array[Color]:
	return SpritePainter.ramp(main.lerp(Color("9babb2"), 0.6))


static func _wood() -> Array[Color]:
	return SpritePainter.ramp(WOOD)


# --- Ilkel çizimler (tuval içinde kırpılır) ---

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _line(img: Image, a: Vector2i, b: Vector2i, c: Color) -> void:
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var p := a
	while true:
		_px(img, p.x, p.y, c)
		if p == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy


## Işık sol üstten: elips/kubbe/tepe gölgelemesi. clip_y: bu satırdan aşağısı çizilmez.
static func _blob(img: Image, cx: int, cy: int, rx: int, ry: int, pal: Array[Color], clip_y := 9999) -> void:
	for y in range(cy - ry, cy + ry + 1):
		if y >= clip_y:
			continue
		for x in range(cx - rx, cx + rx + 1):
			var nx := (x - cx + 0.5) / rx
			var ny := (y - cy + 0.5) / ry
			if nx * nx + ny * ny > 1.0:
				continue
			var l := -nx * 0.6 - ny * 0.8
			var c: Color = pal[3] if l > 0.55 else (pal[2] if l > -0.1 else (pal[1] if l > -0.65 else pal[0]))
			_px(img, x, y, c)


## Dikey silindir (gövde/direk): sol açık, sağ koyu.
static func _post(img: Image, x: int, y: int, w: int, h: int, pal: Array[Color]) -> void:
	for i in w:
		var c: Color = pal[3] if i == 0 and w > 2 else (pal[2] if i < w * 0.6 else pal[1])
		_rect(img, x + i, y, 1, h, c)


## Alev: tabandan (cx, base_y) yukarı, üç katman (dış turuncu, orta sarı, çekirdek açık sarı).
static func _flame(img: Image, cx: int, base_y: int, h: int, w: int) -> void:
	var layers := [[1.0, FLAME_OUT], [0.62, FLAME_MID], [0.3, FLAME_CORE]]
	for layer in layers:
		var f: float = layer[0]
		var lh := int(round(h * (0.55 + 0.45 * f)))
		for r in lh:
			var t := float(r) / lh
			var half := int(round(w * 0.5 * f * (1.0 - pow(t, 1.5))))
			if r == 0:
				half = maxi(0, half - 1)
			# Hafif sola yatık uç: alev canlı dursun
			var shift := -1 if t > 0.65 else 0
			_rect(img, cx - half + shift, base_y - r, half * 2 + 1, 1, layer[1])


## Kutu: footprint merkezi c (bu yükseklikte), sol yüz genişliği wl, sağ yüz wr (piksel), yükseklik h.
## pal = [en koyu, gölge, ana, ışık]: üst ışık, sol ana, sağ gölge. band: yüz üstünde renkli şerit.
static func _box(img: Image, c: Vector2i, wl: int, wr: int, h: int, pal: Array[Color],
		band := NONE, brick := true) -> void:
	var fx := c.x - (wr - wl) / 2
	var fy := c.y + (wl + wr) / 4
	for k in wl:
		_face_col(img, fx - 1 - k, fy - k / 2, h, k, pal[2], pal[1], band, brick)
	for k in wr:
		_face_col(img, fx + k, fy - k / 2, h, k, pal[1], pal[0], band, brick)
	for d in range(-(wl - 1), wr):
		var s_min := maxi(0, -d)
		var s_max := mini(wl - 1, wr - 1 - d)
		var edge := (-d - 1) / 2 if d < 0 else d / 2
		var lower := fy - edge - h
		_rect(img, fx + d, lower - (s_max - s_min), 1, s_max - s_min + 1, pal[3])


static func _face_col(img: Image, x: int, yb: int, h: int, k: int, base: Color, mortar: Color,
		band: Color, brick: bool) -> void:
	_rect(img, x, yb - h + 1, 1, h, base)
	if brick:
		for r in h:
			var course := r / 4
			var y := yb - h + 1 + r
			if r % 4 == 3 and r < h - 1:
				_px(img, x, y, mortar)
			elif r % 4 != 3 and (k + course * 3) % 6 == 0 and r > 0:
				_px(img, x, y, mortar)
	if band.a > 0.0 and h > 6:
		_rect(img, x, yb - h + 2, 1, 2, band)


## Yüz üzerinde pencere/kapı: yüzün alt kenarından y0 yukarıda, hh yüksekliğinde, k0'dan kw sütun.
static func _face_hole(img: Image, c: Vector2i, wl: int, wr: int, left: bool, k0: int, kw: int,
		y0: int, hh: int, color: Color) -> void:
	var fx := c.x - (wr - wl) / 2
	var fy := c.y + (wl + wr) / 4
	for k in range(k0, k0 + kw):
		var x := fx - 1 - k if left else fx + k
		var yb := fy - k / 2 - y0
		_rect(img, x, yb - hh + 1, 1, hh, color)


## Kutunun ön üst kenarlarına küçük mazgal kuleleri (2x2 küp) dizer.
static func _crenels(img: Image, c: Vector2i, wl: int, wr: int, h: int, pal: Array[Color], step := 6) -> void:
	var fx := c.x - (wr - wl) / 2
	var fy := c.y + (wl + wr) / 4 - h
	var t := wr - 3
	while t >= 1:  # arkadan öne
		_box(img, Vector2i(fx + t, fy - t / 2 - 1), 2, 2, 2, pal, NONE, false)
		t -= step
	var s := step - 2
	while s <= wl - 3:
		_box(img, Vector2i(fx - 1 - s, fy - s / 2 - 1), 2, 2, 2, pal, NONE, false)
		s += step


## Kare tabanlı piramit çatı: merkez c (taban yüksekliği), kenar w, tepe yüksekliği rh.
static func _pyramid(img: Image, c: Vector2i, w: int, rh: int, pal: Array[Color]) -> void:
	var fx := c.x
	var fy := c.y + w / 2
	for k in w:
		var yb := fy - k / 2
		var yt := c.y - rh + roundi(float(rh) * k / (w - 1))
		_rect(img, fx - 1 - k, yt, 1, yb - yt + 1, pal[2])
		_rect(img, fx + k, yt, 1, yb - yt + 1, pal[1])
		_px(img, fx - 1 - k, yt, pal[3])
		_px(img, fx + k, yt, pal[2])
	# orta sırt çizgisi (ön köşe)
	_rect(img, fx - 1, c.y - rh, 1, w / 2 + rh + 1, pal[3])


## Sancak: direk (cx, base_y)'den h yukarı, bayrak w x fh.
static func _flag(img: Image, cx: int, base_y: int, h: int, w: int, fh: int, col: Array[Color]) -> void:
	_rect(img, cx, base_y - h, 1, h, _wood()[1])
	for i in w:
		var wave := 1 if (i / 2) % 2 == 1 else 0
		_rect(img, cx + 1 + i, base_y - h + wave, 1, fh, col[2] if i < w - 2 else col[1])
	_rect(img, cx + 1, base_y - h, w, 1, col[3])


# --- Ortak kit ---

static func _wall(img: Image, s: Array[Color], m: Array[Color]) -> void:
	var c := ANCHOR
	_box(img, c, 4, 24, 8, s, m[2])
	_crenels(img, c, 4, 24, 8, s, 6)


static func _tower(img: Image, lit: Image, s: Array[Color], m: Array[Color], a: Array[Color]) -> void:
	var c := ANCHOR
	_box(img, c, 10, 10, 13, s, m[2])
	_face_hole(img, c, 10, 10, true, 4, 2, 4, 4, s[0])
	_face_hole(img, c, 10, 10, false, 3, 2, 4, 4, s[0])
	_face_hole(lit, c, 10, 10, true, 4, 2, 4, 4, Color("fbb954"))
	var top := Vector2i(c.x, c.y - 13)
	_box(img, top, 12, 12, 2, s, NONE, false)
	_pyramid(img, Vector2i(c.x, top.y - 2), 12, 9, m)
	_flag(img, c.x, top.y - 2 - 9 + 1, 6, 5, 3, a)


static func _tent(img: Image, m: Array[Color], a: Array[Color]) -> void:
	var c := ANCHOR
	_box(img, c, 14, 14, 3, m, NONE, false)
	_pyramid(img, Vector2i(c.x, c.y - 3), 14, 13, m)
	# Ön köşe boyunca vurgu şeridi ve kapı
	_rect(img, c.x, c.y - 3 - 13 + 3, 1, 22, a[2])
	_face_hole(img, c, 14, 14, true, 0, 4, 0, 6, a[0] if a[0].v < 0.3 else FRAME)
	_rect(img, c.x - 1, c.y - 3 - 13 - 4, 1, 5, _wood()[1])
	_rect(img, c.x, c.y - 3 - 13 - 4, 4, 2, a[2])


static func _banner(img: Image, m: Array[Color], a: Array[Color]) -> void:
	var c := ANCHOR
	var s := _stone(m[2])
	_box(img, c, 6, 6, 3, s)
	_flag(img, c.x, c.y - 3, 26, 11, 9, m)
	# Bayrakta vurgu rengi: orta şerit
	for i in 9:
		_rect(img, c.x + 2 + i, c.y - 3 - 26 + 3 + (1 if (i / 2) % 2 == 1 else 0), 1, 2, a[2])


static func _fire(img: Image, lit: Image) -> void:
	var c := ANCHOR
	var st := SpritePainter.ramp(Color("7f708a"))
	var wd := _wood()
	# Taş halka (arka yarı önce)
	for i in 12:
		var ang := TAU * i / 12.0
		var p := Vector2i(c.x + roundi(cos(ang) * 8.0), c.y + roundi(sin(ang) * 4.0))
		_rect(img, p.x - 1, p.y - 1, 3, 2, st[2] if i % 3 != 0 else st[3])
		_px(img, p.x, p.y, st[1])
	# Çapraz kütükler
	_line(img, Vector2i(c.x - 6, c.y + 1), Vector2i(c.x + 5, c.y - 3), wd[1])
	_line(img, Vector2i(c.x - 5, c.y - 3), Vector2i(c.x + 6, c.y + 1), wd[2])
	_flame(lit, c.x, c.y - 1, 14, 9)
	# Közün ışıltısı
	_rect(img, c.x - 3, c.y - 1, 6, 1, Color("ea4f36"))


# --- Krallık imza yapıları ---

static func _humans(img: Image, lit: Image, s: Array[Color], m: Array[Color], a: Array[Color]) -> void:
	var c := ANCHOR + Vector2i(0, 2)
	_box(img, c, 14, 14, 11, s, m[2])
	_face_hole(img, c, 14, 14, true, 2, 4, 0, 7, s[0])  # kapı
	_face_hole(img, c, 14, 14, true, 3, 2, 0, 3, s[0])
	_face_hole(img, c, 14, 14, false, 6, 2, 4, 3, s[0])
	_crenels(img, c, 14, 14, 11, s, 5)
	var top := Vector2i(c.x, c.y - 11)
	_box(img, top, 8, 8, 8, s, m[2])
	_face_hole(img, top, 8, 8, true, 3, 2, 3, 3, s[0])
	_face_hole(lit, top, 8, 8, true, 3, 2, 3, 3, Color("fbb954"))
	_pyramid(img, Vector2i(top.x, top.y - 8), 10, 9, m)
	_flag(img, top.x, top.y - 8 - 9 + 1, 8, 6, 4, a)


static func _elves(img: Image, lit: Image, m: Array[Color], a: Array[Color]) -> void:
	var wd := _wood()
	var c := ANCHOR
	# Gövde: alta doğru genişleyen kökler
	_post(img, c.x - 4, c.y - 30, 8, 30, wd)
	_rect(img, c.x - 6, c.y - 3, 12, 3, wd[2])
	_rect(img, c.x - 7, c.y - 1, 3, 2, wd[1])
	_rect(img, c.x + 4, c.y - 1, 3, 2, wd[0])
	# Platform ve kapı
	_box(img, Vector2i(c.x, c.y - 17), 10, 10, 2, wd, NONE, false)
	_rect(img, c.x - 1, c.y - 14, 2, 5, wd[0])
	# Taç
	_blob(img, c.x, c.y - 36, 12, 8, m)
	_blob(img, c.x - 11, c.y - 29, 8, 6, m)
	_blob(img, c.x + 11, c.y - 29, 8, 6, m)
	_blob(img, c.x, c.y - 42, 8, 5, m)
	for p in [Vector2i(-7, -34), Vector2i(5, -31), Vector2i(10, -38), Vector2i(-2, -44)]:
		_rect(img, c.x + p.x, c.y + p.y, 2, 1, a[3])
	# Fener ve ateşböcekleri
	_rect(lit, c.x + 5, c.y - 22, 2, 3, Color("fbff86"))
	for p in [Vector2i(-9, -30), Vector2i(8, -34), Vector2i(0, -38), Vector2i(12, -27)]:
		_rect(lit, c.x + p.x, c.y + p.y, 2, 2, Color("cddf6c"))


static func _orcs(img: Image, lit: Image, m: Array[Color], a: Array[Color]) -> void:
	var wd := _wood()
	var c := ANCHOR
	_box(img, c, 14, 14, 8, wd, NONE, false)
	for k in 14:  # dikey kalaslar
		if k % 3 == 0:
			_face_hole(img, c, 14, 14, true, k, 1, 0, 8, wd[1])
	_face_hole(img, c, 14, 14, true, 4, 4, 0, 6, FRAME)
	_face_hole(lit, c, 14, 14, true, 5, 2, 0, 3, Color("f57d4a"))
	_pyramid(img, Vector2i(c.x, c.y - 8), 16, 10, m)
	# Kemik dikenler: çatı köşelerinde ve ön palisat
	for sp in [[-8, -10, -10, -19], [4, -12, 6, -21], [10, -7, 15, -13], [-14, -6, -19, -10]]:
		_spike(img, Vector2i(c.x + sp[0], c.y + sp[1]), Vector2i(c.x + sp[2], c.y + sp[3]))
	for i in 3:
		var x := c.x - 15 + i * 4
		var y := c.y + 9 - i * 2
		_rect(img, x, y - 8, 2, 8, wd[2])
		_rect(img, x, y - 9, 1, 1, wd[3])
		_px(img, x + 1, y - 9, wd[2])
		_px(img, x, y - 10, BONE)


static func _spike(img: Image, base: Vector2i, tip: Vector2i) -> void:
	var dir := Vector2(tip - base)
	var n := Vector2(-dir.y, dir.x).normalized()
	for t in 6:
		var f := t / 5.0
		var p := Vector2(base) + dir * f
		var wdt := 1.6 * (1.0 - f)
		for o: float in [-1.0, 0.0, 1.0]:
			if absf(o) <= wdt:
				var q := p + n * o
				_px(img, roundi(q.x), roundi(q.y), BONE if o <= 0.0 else Color("9babb2"))


static func _dwarves(img: Image, lit: Image, s: Array[Color], m: Array[Color], a: Array[Color]) -> void:
	var wd := _wood()
	var c := ANCHOR
	_blob(img, c.x, c.y + 2, 19, 17, s, c.y + 5)
	_blob(img, c.x - 10, c.y - 6, 7, 5, s, c.y)
	# Giriş: dolu karanlık ağız, ahşap iskele
	_rect(img, c.x - 6, c.y - 12, 12, 17, FRAME)
	_rect(img, c.x - 5, c.y - 11, 10, 16, a[0])
	_rect(img, c.x - 5, c.y - 11, 10, 3, FRAME)
	_post(img, c.x - 8, c.y - 14, 3, 20, wd)
	_post(img, c.x + 5, c.y - 14, 3, 20, wd)
	_rect(img, c.x - 9, c.y - 16, 18, 3, wd[2])
	_rect(img, c.x - 9, c.y - 16, 18, 1, wd[3])
	# Ray ve vagon
	_line(img, Vector2i(c.x - 3, c.y + 5), Vector2i(c.x - 10, c.y + 9), wd[1])
	_line(img, Vector2i(c.x + 3, c.y + 5), Vector2i(c.x - 4, c.y + 9), wd[1])
	_box(img, Vector2i(c.x + 12, c.y + 6), 6, 6, 4, SpritePainter.ramp(Color("7f708a")), m[2], false)
	_rect(img, c.x + 10, c.y + 1, 5, 1, m[3])
	# Fener ve ağız ışıltısı
	_rect(img, c.x - 1, c.y - 12, 2, 3, Color("fbb954"))
	_rect(lit, c.x - 2, c.y - 13, 4, 5, Color("fbb954"))
	_rect(lit, c.x - 4, c.y - 6, 8, 11, Color("f79617"))
	_rect(lit, c.x - 2, c.y - 3, 4, 8, Color("f9c22b"))


static func _undead(img: Image, lit: Image, s: Array[Color], m: Array[Color], a: Array[Color]) -> void:
	var c := ANCHOR + Vector2i(0, 1)
	var rock := SpritePainter.ramp(DARK_ROCK)
	_box(img, c, 12, 12, 3, rock, NONE, false)
	_box(img, Vector2i(c.x, c.y - 3), 8, 8, 17, s, NONE)
	_pyramid(img, Vector2i(c.x, c.y - 20), 10, 10, rock)
	# Haç oyuğu (sol yüz) ve hayalet pencere
	_face_hole(img, Vector2i(c.x, c.y - 3), 8, 8, true, 3, 1, 4, 8, s[0])
	_face_hole(img, Vector2i(c.x, c.y - 3), 8, 8, true, 1, 5, 7, 1, s[0])
	_face_hole(lit, Vector2i(c.x, c.y - 3), 8, 8, true, 3, 1, 4, 8, Color("8ff8e2"))
	_face_hole(lit, Vector2i(c.x, c.y - 3), 8, 8, true, 1, 5, 7, 1, Color("8ff8e2"))
	_face_hole(img, Vector2i(c.x, c.y - 3), 8, 8, false, 3, 2, 9, 4, a[0])
	_face_hole(lit, Vector2i(c.x, c.y - 3), 8, 8, false, 3, 2, 9, 4, Color("30e1b9"))
	# Küçük mezar taşları
	for gx in [-17, 15]:
		_post(img, c.x + gx, c.y - 3, 5, 9, s)
		_rect(img, c.x + gx + 1, c.y - 4, 3, 1, s[3])
		_rect(img, c.x + gx + 2, c.y, 1, 4, s[0])


static func _demons(img: Image, lit: Image, m: Array[Color], a: Array[Color]) -> void:
	var rock := SpritePainter.ramp(Color("4a3a5c"))
	var c := ANCHOR + Vector2i(0, 4)
	_box(img, c, 18, 18, 4, rock, m[1])
	_box(img, Vector2i(c.x, c.y - 4), 12, 12, 4, rock, m[2])
	_box(img, Vector2i(c.x, c.y - 8), 6, 6, 4, SpritePainter.ramp(Color("2e222f").lerp(Color("625565"), 0.4)), m[3], false)
	# Köşe dikenleri
	for p in [[-17, 1], [16, 1], [-1, 12], [-1, -6]]:
		var base := Vector2i(c.x + p[0], c.y + p[1] - 3)
		_rect(img, base.x, base.y - 8, 2, 8, rock[1])
		_rect(img, base.x, base.y - 9, 1, 1, rock[3])
		_px(img, base.x + 1, base.y - 9, rock[2])
	# Rünler ve alev
	_face_hole(lit, c, 18, 18, true, 5, 8, 1, 1, Color("ea4f36"))
	_face_hole(lit, c, 18, 18, false, 5, 8, 1, 1, Color("ea4f36"))
	_flame(lit, c.x, c.y - 10, 18, 11)
	_flame(lit, c.x - 5, c.y - 9, 8, 5)


static func _slimes(img: Image, lit: Image, m: Array[Color], a: Array[Color]) -> void:
	var c := ANCHOR
	# Balçık gölü ve kubbe
	_blob(img, c.x, c.y + 1, 19, 6, a, c.y + 5)
	_blob(img, c.x, c.y - 3, 15, 15, m, c.y + 3)
	_blob(img, c.x - 13, c.y + 1, 6, 5, m, c.y + 4)
	_blob(img, c.x + 14, c.y + 1, 4, 4, m, c.y + 4)
	# İç kabarcıklar
	for p in [[-5, -4, 2], [4, 0, 3], [-1, -10, 1], [7, -8, 1]]:
		_blob(img, c.x + p[0], c.y + p[1], p[2], p[2], a)
	# Parlayan parlama ve damlalar
	_rect(lit, c.x - 9, c.y - 12, 4, 2, Color("8ff8e2"))
	_rect(lit, c.x - 11, c.y - 9, 2, 3, Color("8ff8e2"))
	_rect(lit, c.x + 3, c.y - 2, 2, 2, Color("8ff8e2"))
	_rect(lit, c.x - 6, c.y - 5, 2, 2, Color("8ff8e2"))


static func _mud(img: Image, lit: Image, m: Array[Color], a: Array[Color]) -> void:
	var wd := _wood()
	var c := ANCHOR
	_blob(img, c.x, c.y + 1, 17, 14, m, c.y + 5)
	_blob(img, c.x - 14, c.y + 2, 7, 5, m, c.y + 5)
	_blob(img, c.x + 13, c.y + 2, 6, 4, m, c.y + 5)
	# Dal çatkı: tepeden çıkan çubuklar
	for i in 5:
		var bx := c.x - 8 + i * 4
		_line(img, Vector2i(bx, c.y - 8 + absi(i - 2) * 2), Vector2i(bx + (i - 2) * 2, c.y - 17 + absi(i - 2) * 2), wd[1 + (i % 2)])
	# Giriş deliği
	_blob(img, c.x - 2, c.y, 5, 4, SpritePainter.ramp(a[0]))
	_rect(img, c.x - 6, c.y - 1, 1, 4, FRAME)
	_rect(lit, c.x - 4, c.y + 1, 4, 2, Color("f57d4a"))
	_rect(lit, c.x - 3, c.y + 1, 2, 1, Color("f9c22b"))
	# Bataklık buharı
	for p in [[6, -12], [8, -15], [5, -18]]:
		_rect(lit, c.x + p[0], c.y + p[1], 3, 2, Color("b2ba90"))


static func _golems(img: Image, lit: Image, s: Array[Color], m: Array[Color], a: Array[Color]) -> void:
	var c := ANCHOR
	_box(img, c, 14, 14, 4, s, NONE)
	var shaft := Vector2i(c.x, c.y - 4)
	_box(img, shaft, 8, 8, 24, s, NONE)
	_pyramid(img, Vector2i(c.x, shaft.y - 24), 8, 8, SpritePainter.ramp(s[3]))
	var rune := a[1]
	var glow_c := a[3]
	# Rün çizgileri: sol yüzde dikey çizgi + çentikler
	_face_hole(img, shaft, 8, 8, true, 3, 1, 3, 17, rune)
	_face_hole(lit, shaft, 8, 8, true, 3, 1, 3, 17, glow_c)
	for y0 in [5, 10, 15]:
		_face_hole(img, shaft, 8, 8, true, 1, 5, y0, 1, rune)
		_face_hole(lit, shaft, 8, 8, true, 1, 5, y0, 1, glow_c)
	_face_hole(img, shaft, 8, 8, false, 2, 3, 12, 1, rune)
	_face_hole(lit, shaft, 8, 8, false, 2, 3, 12, 1, glow_c)
	# Dip taşları
	_box(img, Vector2i(c.x - 14, c.y + 2), 4, 6, 3, s, NONE, false)
	_box(img, Vector2i(c.x + 14, c.y + 3), 6, 4, 2, s, NONE, false)


static func _centaurs(img: Image, lit: Image, m: Array[Color], a: Array[Color]) -> void:
	var c := ANCHOR
	_tipi(img, Vector2i(c.x - 10, c.y - 6), 12, 14, m, a)
	_tipi(img, Vector2i(c.x + 9, c.y - 6), 14, 16, m, a)
	_tipi(img, Vector2i(c.x - 3, c.y + 1), 12, 13, m, a)
	# Ön ateş
	_flame(lit, c.x + 13, c.y + 7, 8, 5)
	_rect(img, c.x + 9, c.y + 6, 8, 2, _wood()[1])
	_rect(img, c.x + 10, c.y + 5, 6, 1, SpritePainter.ramp(Color("7f708a"))[2])
	# Totem direği
	_post(img, c.x - 20, c.y - 18, 3, 22, _wood())
	_rect(img, c.x - 21, c.y - 17, 5, 2, a[3])
	_rect(img, c.x - 21, c.y - 13, 5, 2, m[2])


static func _tipi(img: Image, c: Vector2i, w: int, rh: int, m: Array[Color], a: Array[Color]) -> void:
	_pyramid(img, c, w, rh, m)
	_rect(img, c.x, c.y - rh + 4, 1, rh + w / 2 - 3, a[2])
	_face_hole(img, c, w, w, true, 0, 3, 0, 5, FRAME)
	_rect(img, c.x - 1, c.y - rh - 4, 1, 5, _wood()[1])
	_rect(img, c.x + 1, c.y - rh - 4, 1, 4, _wood()[2])
