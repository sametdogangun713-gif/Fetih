class_name LivesHearts
extends Control
## Canlar: piksel kalpler (koddan çizilir, Resurrect 64). Tam kalpler sırayla hafifçe "nefes alır";
## can kaybında kalp sallanır, ikiye kırılır, parçalar düşerek solar; yerinde boş kontur kalır.
## Godot: _draw her karede yeniden çizer (queue_redraw); draw_set_transform ölçek/dönme verir,
## böylece tek dokuyla büyüme ve dönen parçalar çizilir.

const GAP := 3.0
const BREATH_TIME := 1.2  ## Bir nefes döngüsü (sn).
const BREATH_AMOUNT := 0.07
const SHAKE_TIME := 0.18  ## Kırılmadan önce sallanma.
const BREAK_TIME := 0.7  ## Sallanma + parçaların düşüp solması.
const MASK: Array[String] = [
	".##...##.",
	"####.####",
	"#########",
	"#########",
	".#######.",
	"..#####..",
	"...###...",
	"....#....",
]

static var _full: Texture2D
static var _empty: Texture2D
static var _halves: Array[Texture2D] = []

var _lives := 3
var _max := 3
var _time := 0.0
var _breaking := {}  ## kalp sırası -> kırılma başladığından beri geçen süre


func _init(lives := 3, max_lives := 3) -> void:
	_lives = lives
	_max = max_lives
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_textures()
	var size := _full.get_size()
	custom_minimum_size = Vector2(_max * (size.x + GAP) - GAP, size.y + 2)


func full_count() -> int:
	return _lives


func heart_count() -> int:
	return _max


## Can sayısını günceller. animate: azalan her kalp kırılma animasyonuyla boşalır.
func set_lives(lives: int, animate := true) -> void:
	if animate:
		for i in range(lives, _lives):
			_breaking[i] = 0.0
	else:
		_breaking.clear()
	_lives = clampi(lives, 0, _max)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	for i in _breaking.keys():
		_breaking[i] += delta / UiKit.anim_scale()
		if _breaking[i] >= BREAK_TIME:
			_breaking.erase(i)
	queue_redraw()


func _draw() -> void:
	var size := _full.get_size()
	for i in _max:
		var at := Vector2(i * (size.x + GAP), 1)
		if i < _lives:
			# Sırayla nefes: her kalp bir önceki kalpten biraz sonra büyür.
			var phase := sin((_time - i * 0.15) * TAU / BREATH_TIME) * 0.5 + 0.5
			var s := 1.0 + BREATH_AMOUNT * phase
			var center := at + size / 2.0
			draw_set_transform(center, 0.0, Vector2.ONE * s)
			draw_texture(_full, -size / 2.0)
			draw_set_transform(Vector2.ZERO)
			continue
		draw_texture(_empty, at)
		if _breaking.has(i):
			_draw_breaking(at, size, _breaking[i])


## Kırılan kalp: önce yerinde sallanır, sonra iki yarısı ayrılıp dönerek düşer ve solar.
func _draw_breaking(at: Vector2, size: Vector2, t: float) -> void:
	if t < SHAKE_TIME:
		var shake := Vector2(sin(t * 90.0) * 1.5, 0).round()
		draw_texture(_full, at + shake)
		return
	var k := (t - SHAKE_TIME) / (BREAK_TIME - SHAKE_TIME)
	var alpha := 1.0 - k
	var half := Vector2(size.x / 2.0, size.y)
	for side in 2:
		var dir := -1.0 if side == 0 else 1.0
		var offset := Vector2(dir * k * 5.0, k * k * 10.0)
		var pivot := at + Vector2(half.x * (0.5 + side), half.y / 2.0) + offset
		draw_set_transform(pivot, dir * k * 0.6, Vector2.ONE)
		draw_texture(_halves[side], -half / 2.0, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO)


static func _build_textures() -> void:
	if _full != null:
		return
	var w := MASK[0].length() + 2
	var h := MASK.size() + 2
	var full := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var empty := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in MASK.size():
		for x in MASK[y].length():
			if MASK[y][x] != "#":
				continue
			var c := Color("e83b3b")
			if (x <= 2 and y <= 2) or (x == 1 and y == 3):
				c = Color("f68181")  # parlak sol üst
			elif x + y >= 9:
				c = Color("ae2334")  # koyu sağ alt
			full.set_pixel(x + 1, y + 1, c)
			empty.set_pixel(x + 1, y + 1, Color("3e3546", 0.55))
	_outline(full, Color("2e222f"))
	_outline(empty, Color("625565"))
	_full = ImageTexture.create_from_image(full)
	_empty = ImageTexture.create_from_image(empty)
	_halves = [
		ImageTexture.create_from_image(full.get_region(Rect2i(0, 0, w / 2, h))),
		ImageTexture.create_from_image(full.get_region(Rect2i(w / 2, 0, w - w / 2, h))),
	]


static func _outline(img: Image, color: Color) -> void:
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
		img.set_pixelv(p, color)
