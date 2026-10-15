class_name MenuBackdrop
extends Control
## Menü ekranlarının canlı arka planı (renkli fantastik): gün batımı gökyüzü, parlayan güneş, yıldızlar,
## kayan bulut katmanları, uzak dağlar, tepede kale (pencereleri titrer, burçlarda dalgalanan sancaklar),
## ön tepeler ve ağaçlar, arada geçen kuş sürüsü. Fare hareketiyle hafif paralaks (yakın katman çok kayar).
## Tamamı koddan; konumlar boyuta oranlı, boyut değişince katmanlar yeniden kurulur. Sadece görüntü.
## Godot: _draw her karede yeniden çizilir (queue_redraw). draw_polygon köşe renkleriyle yumuşak degrade verir;
## doku (ağaç, sancak) Nearest süzmeyle piksel net kalır.

const CLOUD_SPEEDS: Array[float] = [3.0, 6.0, 11.0]  ## Uzaktan yakına bulut katmanı hızı (düzen pikseli/sn).
const PARALLAX: Array[float] = [1.0, 2.0, 4.0, 7.0, 10.0]  ## gök, bulut, dağ, kale, ön tepe
const BIRD_PERIOD := 18.0  ## Kuş sürüsü kaç saniyede bir geçer.
const BIRD_TIME := 9.0  ## Ekranı geçme süresi.
const MARCH_SPEED := 9.0  ## Ön tepede yürüyen ordunun hızı (düzen pikseli/sn).
const MARCH_GAP := 12.0  ## Askerler arası.
const EMBERS := 26  ## Yükselen kıvılcım sayısı.
const SKY: Array[Color] = [Color("323353"), Color("484a77"), Color("905ea9"), Color("f68181"), Color("fbb954")]

## Karartma (0..1): menü öğeleri öne çıksın diye arka plan koyulaşır (krallık seçimi 0.35).
var dim := 0.0:
	set(value):
		dim = clampf(value, 0.0, 1.0)
		queue_redraw()
var parallax := true  ## Fareyle kayma (ekran görüntüsü/test için kapatılabilir).

var _time := 0.0
var _mouse_shift := Vector2.ZERO  ## -1..1, yumuşatılmış fare sapması
var _built_size := Vector2.ZERO
var _far_mountains := PackedVector2Array()
var _near_mountains := PackedVector2Array()
var _hills := PackedVector2Array()
var _stars: Array[Vector3] = []  ## x, y, evre
var _clouds: Array[Array] = []  ## katman -> [[x, y, ölçek], ...]
var _trees: Array[Array] = []  ## [doku, gövde dibi (zemindeki nokta), dokudaki gövde dibi]
var _castle_ground := Vector2.ZERO  ## Kalenin oturduğu nokta: yakın dağların tepesi.
var _cloud_tex: Array[Texture2D] = []
var _banners: Array[KingdomData] = []
var _army: Array[UnitSprites.Sheet] = []  ## Ön tepede soldan sağa yürüyen bölük (sancaktar başta).
var _army_banner: KingdomData
var _bushes: Array[Array] = []  ## [doku, konum] ön plan çalı ve otları


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	resized.connect(_rebuild)
	_rebuild()


## Test kancası: bulut katmanının şu anki kayması.
func cloud_offset(layer: int) -> float:
	return _time * CLOUD_SPEEDS[layer]


## Test kancası: yürüyen askerlerin şu anki konumları (sancaktar dahil, öndeki ilk).
func army_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in _army.size() + 1:
		out.append(_soldier_pos(i))
	return out


## Test kancası: kalenin oturduğu nokta (paralakssız).
func castle_ground() -> Vector2:
	return _castle_ground


func near_ridge_y(x: float) -> float:
	return _ridge_y(_near_mountains, x)


func hill_ridge_y(x: float) -> float:
	return _ridge_y(_hills, x)


## Test kancası: ağaç gövdelerinin yere değdiği noktalar.
func tree_feet() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for tree in _trees:
		out.append(tree[1])
	return out


## Test kancası: katmanların kurulduğu genişlik.
func layer_width() -> int:
	return int(_built_size.x)


func _process(delta: float) -> void:
	_time += delta
	if parallax and is_visible_in_tree():
		var vp := get_viewport_rect().size
		var target := Vector2.ZERO
		if vp.x > 0.0:
			target = (get_viewport().get_mouse_position() / vp - Vector2(0.5, 0.5)) * 2.0
		_mouse_shift = _mouse_shift.lerp(target.clamp(Vector2(-1, -1), Vector2(1, 1)), minf(delta * 3.0, 1.0))
	queue_redraw()


func _rebuild() -> void:
	var s := size if size.x > 0.0 else Vector2(640, 360)
	_built_size = s
	var rng := RandomNumberGenerator.new()
	rng.seed = 1453
	_far_mountains = _ridge(s, s.y * 0.55, s.y * 0.16, 0.012, rng)
	_near_mountains = _ridge(s, s.y * 0.66, s.y * 0.10, 0.02, rng)
	_hills = _ridge(s, s.y * 0.82, s.y * 0.05, 0.01, rng)
	_stars.clear()
	for i in 40:
		_stars.append(Vector3(rng.randf() * s.x, rng.randf() * s.y * 0.35, rng.randf() * TAU))
	if _cloud_tex.is_empty():
		for i in 3:
			_cloud_tex.append(_cloud_texture(rng, 40 + i * 14, 12 + i * 4))
	_clouds.clear()
	for layer in 3:
		var row: Array = []
		for i in 4 - layer:
			row.append([rng.randf() * s.x, s.y * (0.12 + 0.1 * layer) + rng.randf_range(-12, 12), 1.0])
		_clouds.append(row)
	_castle_ground = _peak(_near_mountains, s.x * 0.66, s.x * 0.9) + Vector2(0, 3)
	_trees.clear()
	var plants := _tree_textures()
	if not plants.is_empty():
		# Öbekler: düğmelerin (sol) ve kalenin önü boş; her ağaç gövdesi tepe çizgisinin 2 px altında.
		for center: float in [0.45, 0.55, 0.63, 0.93]:
			for j in rng.randi_range(2, 3):
				var x := s.x * center + rng.randf_range(-14.0, 14.0)
				var tex: Texture2D = plants[rng.randi_range(0, plants.size() - 1)]
				_trees.append([tex, Vector2(round(x), round(_ridge_y(_hills, x) + 2.0)), _trunk_base(tex)])
		_trees.sort_custom(func(a: Array, b: Array) -> bool: return a[1].y < b[1].y)
	_banners.clear()
	var all := KingdomCatalog.all()
	for i in 3:
		_banners.append(all[(i * 3 + 1) % all.size()])
	_army.clear()
	_army_banner = all[0]
	for i in 9:  # birkaç krallığın başlangıç birliklerinden karışık bir sefer kolu
		var kingdom: KingdomData = all[i % 4]
		if kingdom.starting_units.is_empty():
			continue
		var unit: UnitData = kingdom.starting_units[i % kingdom.starting_units.size()]
		_army.append(UnitSprites.sheet_for(unit, SquadState.Team.PLAYER))
	_bushes.clear()
	for i in 22:  # ön tepe boyunca küçük çalı ve otlar (düğmelerin altında da: kısa boylu)
		var kind: StringName = [&"dry_bush", &"savanna_grass", &"mushroom", &"rock"][rng.randi_range(0, 3)]
		var x := rng.randf_range(0.0, s.x)
		_bushes.append([TerrainProps.texture(kind, rng.randi_range(0, TerrainProps.VARIANTS - 1)),
				Vector2(x, _ridge_y(_hills, x) + rng.randf_range(6.0, s.y * 0.12))])
	_bushes.sort_custom(func(a: Array, b: Array) -> bool: return a[1].y < b[1].y)
	queue_redraw()


## Dağ sırtı: sin toplamı silüet, alt kenar ekranın altı (doldurulacak çokgen).
func _ridge(s: Vector2, base: float, height: float, freq: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var a := rng.randf() * TAU
	var b := rng.randf() * TAU
	var step := 6.0
	var x := -20.0
	while x <= s.x + 20.0:
		var y := base - height * (0.55 * sin(x * freq + a) + 0.3 * sin(x * freq * 2.7 + b) + 0.15 * sin(x * freq * 6.1))
		pts.append(Vector2(x, y))
		x += step
	pts.append(Vector2(s.x + 20.0, s.y + 20.0))
	pts.append(Vector2(-20.0, s.y + 20.0))
	return pts


## Sırtın [x0, x1] aralığındaki en yüksek noktası (ekranda en küçük y).
func _peak(ridge: PackedVector2Array, x0: float, x1: float) -> Vector2:
	var best := Vector2(x0, INF)
	for i in ridge.size() - 2:
		var p := ridge[i]
		if p.x >= x0 and p.x <= x1 and p.y < best.y:
			best = p
	return best


## Ağaç dokusunun gövde dibi: dolu alanın alt ortası (dokuların altında 3-12 px boşluk var).
static var _base_cache := {}


static func _trunk_base(tex: Texture2D) -> Vector2:
	if not _base_cache.has(tex.resource_path):
		var used := tex.get_image().get_used_rect()
		_base_cache[tex.resource_path] = Vector2(used.position.x + used.size.x / 2, used.end.y - 1)
	return _base_cache[tex.resource_path]


func _ridge_y(ridge: PackedVector2Array, x: float) -> float:
	for i in ridge.size() - 3:
		if ridge[i + 1].x >= x:
			var t := (x - ridge[i].x) / maxf(ridge[i + 1].x - ridge[i].x, 0.001)
			return lerpf(ridge[i].y, ridge[i + 1].y, t)
	return _built_size.y * 0.8


func _draw() -> void:
	var s := _built_size
	if s.x <= 0.0:
		return
	_draw_sky(s)
	_draw_sun(s)
	_draw_stars()
	for layer in 3:
		_draw_clouds(s, layer)
	_draw_layer(_far_mountains, Color("6b3e75"), Color("905ea9"), PARALLAX[2] * 0.6)
	_draw_layer(_near_mountains, Color("45293f"), Color("6b3e75"), PARALLAX[2])
	_draw_castle(s)
	_draw_birds(s)
	_draw_layer(_hills, Color("165a4c"), Color("239063"), PARALLAX[4])
	for tree: Array in _trees:
		var tex: Texture2D = tree[0]
		var at: Vector2 = tree[1] + _shift(PARALLAX[4])
		draw_texture(tex, (at - tree[2]).round())
	_draw_army()
	for bush: Array in _bushes:
		var tex: Texture2D = bush[0]
		var at: Vector2 = bush[1] + _shift(PARALLAX[4])
		draw_texture(tex, (at - Vector2(tex.get_width() / 2.0, tex.get_height())).round())
	_draw_embers(s)
	if dim > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.03, 0.08, dim))


func _shift(amount: float) -> Vector2:
	return -_mouse_shift * amount


func _draw_sky(s: Vector2) -> void:
	var stops := SKY.size()
	for i in stops - 1:
		var y0 := s.y * 0.7 * i / (stops - 1)
		var y1 := s.y * 0.7 * (i + 1) / (stops - 1)
		draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(s.x, y0), Vector2(s.x, y1), Vector2(0, y1)]),
				PackedColorArray([SKY[i], SKY[i], SKY[i + 1], SKY[i + 1]]))
	draw_rect(Rect2(0, s.y * 0.7, s.x, s.y * 0.3), SKY[stops - 1])


func _draw_sun(s: Vector2) -> void:
	var at := Vector2(s.x * 0.68, s.y * 0.5) + _shift(PARALLAX[0])
	var pulse := 0.5 + 0.5 * sin(_time * 0.8)
	for i in 4:
		draw_circle(at, 26.0 + i * 9.0 + pulse * 2.0, Color(1.0, 0.85, 0.5, 0.08))
	draw_circle(at, 22.0, Color("fbff86"))
	draw_circle(at, 19.0, Color("fdcbb0"))


func _draw_stars() -> void:
	for star in _stars:
		var a := 0.35 + 0.35 * sin(_time * 1.7 + star.z)
		draw_rect(Rect2(Vector2(star.x, star.y) + _shift(PARALLAX[0]), Vector2(1, 1)), Color(1, 1, 1, a))


func _draw_clouds(s: Vector2, layer: int) -> void:
	var tex := _cloud_tex[layer]
	var w := tex.get_width()
	for cloud: Array in _clouds[layer]:
		var x: float = fposmod(float(cloud[0]) + cloud_offset(layer), s.x + w) - w
		draw_texture(tex, (Vector2(x, cloud[1]) + _shift(PARALLAX[1] * (layer + 1) * 0.5)).round(),
				Color(1, 1, 1, 0.75 + 0.08 * layer))


func _draw_layer(ridge: PackedVector2Array, body: Color, rim: Color, amount: float) -> void:
	var shift := _shift(amount)
	var pts := PackedVector2Array()
	for p in ridge:
		pts.append(p + shift)
	draw_colored_polygon(pts, body)
	var top := pts.slice(0, pts.size() - 2)
	draw_polyline(top, rim, 1.0)


## Kale: sağdaki tepede gövde + 3 kule, mazgallar, titreyen pencereler, kulelerde sancak.
func _draw_castle(s: Vector2) -> void:
	var shift := _shift(PARALLAX[2])  # dağla aynı kayar: kale yerinden oynamaz
	var origin := (_castle_ground + shift).round()
	var dark := Color("2e222f")
	var wall := Color("3e3546")
	# Kaya temeli: dağ renginde, kalenin altından yamaçlara açılır (kale tepeye oturur, altı boş kalmaz).
	draw_colored_polygon(PackedVector2Array([origin + Vector2(-50, -6), origin + Vector2(50, -6),
			origin + Vector2(78, 34), origin + Vector2(-78, 34)]), Color("45293f"))
	for r: Vector3 in [Vector3(-46, -2, 5), Vector3(44, -1, 4), Vector3(-30, 1, 3), Vector3(30, 2, 3)]:
		draw_circle(origin + Vector2(r.x, r.y), r.z, Color("3e3546"))
	var body := Rect2(origin + Vector2(-34, -30), Vector2(68, 30))
	draw_rect(body, wall)
	_crenels(Vector2(body.position.x, body.position.y), body.size.x, wall)
	var towers := [Rect2(origin + Vector2(-44, -52), Vector2(16, 52)), Rect2(origin + Vector2(-9, -66), Vector2(18, 66)),
			Rect2(origin + Vector2(28, -48), Vector2(16, 48))]
	var lit := Color("7f708a")  # güneşe bakan (sol) kenar
	draw_rect(Rect2(body.position, Vector2(1, body.size.y)), lit)
	for i in towers.size():
		var t: Rect2 = towers[i]
		draw_rect(t, dark if i == 1 else wall)
		draw_rect(Rect2(t.position, Vector2(1, t.size.y)), lit)
		# Sivri çatı: sol yarı açık, sağ yarı koyu kırmızı; sancak tepeden yükselir.
		var apex := t.position + Vector2(t.size.x / 2.0, -16)
		var left := t.position + Vector2(-2, 0)
		var right := t.position + Vector2(t.size.x + 2, 0)
		var mid := t.position + Vector2(t.size.x / 2.0, 0)
		draw_colored_polygon(PackedVector2Array([apex, mid, left]), Color("b33831"))
		draw_colored_polygon(PackedVector2Array([apex, right, mid]), Color("6e2727"))
		var flicker := 0.7 + 0.3 * sin(_time * 5.0 + i * 1.7)
		draw_rect(Rect2(t.position + Vector2(t.size.x / 2.0 - 2, 14), Vector2(4, 6)), Color(Color("f9c22b"), flicker))
		if i < _banners.size():
			var frame := int(_time * 4.0 + i) % BannerArt.FRAMES
			var tex := BannerArt.texture(_banners[i], frame)
			var at := apex + Vector2(0, 2) - Vector2(BannerArt.ANCHOR)
			draw_texture(tex, at.round())
	var gate := origin + Vector2(0, -14)  # kemerli kapı
	draw_rect(Rect2(gate + Vector2(-6, 0), Vector2(12, 14)), dark)
	draw_circle(gate, 6.0, dark)
	for side in [-1.0, 1.0]:  # kapı meşaleleri: titreyen ışık halesi
		var torch := origin + Vector2(side * 11.0, -12)
		var f := 0.75 + 0.25 * sin(_time * 9.0 + side * 2.0) * sin(_time * 5.3)
		draw_circle(torch, 7.0 * f, Color(1.0, 0.6, 0.2, 0.18))
		draw_circle(torch, 2.0, Color(Color("fbb954"), f))
		draw_rect(Rect2(torch + Vector2(-0.5, 1), Vector2(1, 4)), Color("694f62"))
	for i in 3:  # gövde pencereleri
		var flicker := 0.6 + 0.4 * sin(_time * 3.0 + i * 2.3)
		draw_rect(Rect2(origin + Vector2(-26 + i * 18, -22), Vector2(3, 4)), Color(Color("fbb954"), flicker))


func _crenels(top_left: Vector2, width: float, color: Color) -> void:
	var x := 0.0
	while x + 4.0 <= width:
		draw_rect(Rect2(top_left + Vector2(x, -4), Vector2(4, 4)), color)
		x += 7.0


## Kuş sürüsü: BIRD_PERIOD'da bir, BIRD_TIME sürede soldan sağa, kanatlar iki karede çırpar.
func _draw_birds(s: Vector2) -> void:
	var t := fmod(_time, BIRD_PERIOD)
	if t > BIRD_TIME:
		return
	var k := t / BIRD_TIME
	var lead := Vector2(lerpf(-40.0, s.x + 40.0, k), s.y * 0.3 + sin(k * TAU) * 8.0) + _shift(PARALLAX[3])
	var flap := int(_time * 6.0) % 2 == 0
	var formation := [Vector2(0, 0), Vector2(-9, 5), Vector2(-9, -5), Vector2(-18, 10), Vector2(-18, -10), Vector2(-26, 3)]
	for off: Vector2 in formation:
		var p := (lead + off).round()
		var wing := -2.0 if flap else 1.0
		draw_line(p + Vector2(-3, wing), p, Color("2e222f"), 1.0)
		draw_line(p, p + Vector2(3, wing), Color("2e222f"), 1.0)


## Yumuşak piksel bulut: üst üste daireler, alt kenar gölgeli (Resurrect 64 pembe-krem tonları).
static func _cloud_texture(rng: RandomNumberGenerator, w: int, h: int) -> Texture2D:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var blobs: Array[Vector3] = []
	for i in 5:
		blobs.append(Vector3(rng.randf_range(h * 0.5, w - h * 0.5), rng.randf_range(h * 0.45, h * 0.65),
				rng.randf_range(h * 0.3, h * 0.5)))
	for y in h:
		for x in w:
			for b in blobs:
				if Vector2(x - b.x, y - b.y).length() <= b.z:
					var shade := Color("fdcbb0") if y < h * 0.55 else Color("fca790")
					img.set_pixel(x, y, shade)
					break
	return ImageTexture.create_from_image(img)


static func _tree_textures() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var dir := "res://assets/terrain/px/plants/"
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".png") and (file.begins_with("pine-none") or file.begins_with("bigtree")):
			out.append(load(dir + file))
	return out


## Ön tepe boyunca soldan sağa yürüyen sefer kolu: başta sancaktar, ardından askerler (yürüme kareleri).
func _soldier_pos(i: int) -> Vector2:
	var span := _built_size.x + 160.0
	var x := fposmod(_built_size.x * 0.45 + _time * MARCH_SPEED - i * MARCH_GAP, span) - 60.0  # ilk anda ortada
	return Vector2(x, _ridge_y(_hills, x) + 3.0)


func _draw_army() -> void:
	var shift := _shift(PARALLAX[4])
	var bearer := _soldier_pos(0) + shift
	var frame := int(_time * 4.0) % BannerArt.FRAMES
	draw_texture(BannerArt.texture(_army_banner, frame), (bearer - Vector2(BannerArt.ANCHOR)).round())
	for i in _army.size():
		var sheet := _army[i]
		var at := _soldier_pos(i + 1) + shift
		var walk := UnitSprites.Anim.WALK
		var region := sheet.region(walk, int(_time * 8.0 + i * 0.7) % sheet.count(walk))
		var bob := 0.0 if int(_time * 8.0 + i) % 2 == 0 else -1.0
		draw_rect(Rect2(at + Vector2(-4, -1), Vector2(8, 2)), Color(0, 0, 0, 0.25))
		draw_texture_rect_region(sheet.texture,
				Rect2((at - Vector2(region.size.x / 2.0, region.size.y - bob)).round(), region.size), region)


## Gün batımı kıvılcımları: alttan yavaşça yükselir, sağa sola salınır, söner.
func _draw_embers(s: Vector2) -> void:
	for i in EMBERS:
		var seed_x := fposmod(i * 97.13, 1.0)
		var speed := 8.0 + fposmod(i * 13.7, 9.0)
		var life := s.y * 0.55
		var travel := fposmod(_time * speed + i * 37.0, life)
		var k := travel / life
		var x := seed_x * s.x + sin(_time * 0.7 + i) * 6.0
		var y := s.y - travel
		var a := sin(k * PI) * (0.55 + 0.45 * sin(_time * 6.0 + i * 1.3))
		draw_rect(Rect2(Vector2(x, y).round(), Vector2(1, 1)), Color(1.0, 0.75, 0.35, a * 0.8))
