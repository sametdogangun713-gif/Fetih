class_name BannerArt
## Krallık sancağı: direk + krallık renginde bez + ortada vurgu renginde amblem (koddan, Resurrect 64 paleti).
## Her ordunun arkasında bir sancak durur (Battlefield.set_banners); krallık seçiminde de kullanılır.
## Bez 3 karede dalgalanır: direğe yakın sütunlar sabit, uca doğru dalga büyür.
## Godot: Image piksel piksel çizilir, ImageTexture'a çevrilip önbelleğe alınır; Nearest süzme proje varsayılanı.

const SIZE := Vector2i(24, 40)  ## Tuval (sancak resmi) boyutu.
const ANCHOR := Vector2i(4, 39)  ## Direğin yere değdiği nokta (konuma bu oturtulur).
const FRAMES := 3
const CLOTH := Rect2i(5, 4, 16, 20)  ## Bezin dalgasız kutusu (tuval pikseli).
const OUTLINE := Color("2e222f")
const POLE := Color("694f62")
const POLE_LIGHT := Color("966c6c")
const FINIAL := Color("f9c22b")

## 7x7 amblem maskeleri ("#" dolu). Krallık id'sine göre; yoksa "default".
const EMBLEMS := {
	&"humans": [".......", "#..#..#", "##.#.##", "#######", "#######", ".......", "......."],  # taç
	&"elves": ["....##.", "...###.", "..####.", ".####..", ".###...", "#.#....", "#......"],  # yaprak
	&"orcs": ["###....", "####...", "####.#.", ".###.#.", "....#..", "...#...", "..#...."],  # balta
	&"dwarves": ["#######", "#######", "..###..", "...#...", "...#...", "...#...", "...#..."],  # çekiç
	&"undead": [".#####.", "#######", "#..#..#", "#######", ".#####.", ".#.#.#.", "......."],  # kafatası
	&"demons": ["#.....#", "#.....#", "##...##", ".#####.", ".#####.", "..###..", "......."],  # boynuz
	&"slimes": ["...#...", "..###..", ".#####.", ".#####.", "#######", "#######", ".#####."],  # damla
	&"mud": [".......", "##...##", "#.#.#.#", "...#...", "##...##", "#.#.#.#", "...#..."],  # dalga
	&"golems": ["...#...", "..###..", ".#####.", "#######", ".#####.", "..###..", "...#..."],  # kristal
	&"centaurs": ["..###..", ".##.##.", "##...##", "#.....#", "#.....#", "##...##", "#.....#"],  # at nalı
	&"default": ["...#...", "..###..", ".##.##.", "##...##", ".##.##.", "..###..", "...#..."],
}

static var _textures := {}  ## "id|kare" -> Texture2D
static var _emblems := {}  ## "id|renk|ölçek" -> Texture2D


## Sancağın dalga kareleri (FRAMES adet Image, SIZE boyutunda).
static func frames(kingdom: KingdomData) -> Array[Image]:
	var out: Array[Image] = []
	for f in FRAMES:
		out.append(_draw(kingdom, f))
	return out


static func texture(kingdom: KingdomData, frame: int) -> Texture2D:
	var key := "%s|%d" % [kingdom.id, frame]
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(_draw(kingdom, frame % FRAMES))
	return _textures[key]


## Amblem tek başına (arayüz simgesi): 7*scale kare, şeffaf zemin.
static func emblem_texture(kingdom_id: StringName, color: Color, scale := 2) -> Texture2D:
	var key := "%s|%s|%d" % [kingdom_id, color.to_html(), scale]
	if not _emblems.has(key):
		var img := Image.create_empty(7, 7, false, Image.FORMAT_RGBA8)
		emblem(img, kingdom_id, Vector2i.ZERO, color)
		if scale > 1:
			img.resize(7 * scale, 7 * scale, Image.INTERPOLATE_NEAREST)
		_emblems[key] = ImageTexture.create_from_image(img)
	return _emblems[key]


## Amblemi resme çizer (origin: sol üst köşe). Görünür sınır dışı pikseller atlanır.
static func emblem(image: Image, kingdom_id: StringName, origin: Vector2i, color: Color) -> void:
	var mask: Array = EMBLEMS.get(kingdom_id, EMBLEMS[&"default"])
	for y in mask.size():
		var row: String = mask[y]
		for x in row.length():
			if row[x] != "#":
				continue
			var p := origin + Vector2i(x, y)
			if p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height():
				image.set_pixelv(p, color)


static func _draw(kingdom: KingdomData, frame: int) -> Image:
	var main := SpritePalette.nearest(kingdom.color)
	var dark := SpritePalette.nearest(kingdom.color.darkened(0.3))
	var accent := SpritePalette.nearest(kingdom.accent_color)
	if SpritePalette.distance(accent, main) < 0.05:  # vurgu bezle aynı tona düştüyse amblem okunmaz
		accent = SpritePalette.nearest(main.lightened(0.5) if SpritePalette.luma(main) < 0.5 else main.darkened(0.5))
	# Bez önce düz bir tuvale çizilir (amblem dahil), sonra sütun sütun dalgayla kaydırılır.
	var cloth := Image.create_empty(CLOTH.size.x, CLOTH.size.y, false, Image.FORMAT_RGBA8)
	for y in CLOTH.size.y:
		for x in CLOTH.size.x:
			# Kırlangıç kuyruğu: son 4 satırda ortada V kesik.
			var notch := y - (CLOTH.size.y - 4)
			if notch >= 0 and absi(x - CLOTH.size.x / 2) <= notch:
				continue
			var c := main
			if x == 0 or y == 0:
				c = dark  # direğe ve üste yakın kenar gölgeli
			elif y >= CLOTH.size.y - 6 and y < CLOTH.size.y - 4:
				c = accent  # saçak şeridi
			cloth.set_pixel(x, y, c)
	emblem(cloth, kingdom.id, Vector2i(CLOTH.size.x / 2 - 3, 4), accent)
	var img := Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	for x in CLOTH.size.x:
		var amp := 1.5 * float(x) / float(CLOTH.size.x - 1)  # direğe bağlı uç sabit
		var dy := roundi(sin(x * 0.45 + frame * TAU / FRAMES) * amp)
		for y in CLOTH.size.y:
			var c := cloth.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(CLOTH.position.x + x, CLOTH.position.y + y + dy, c)
	for y in range(3, SIZE.y):  # direk (2 px, sol açık)
		img.set_pixel(ANCHOR.x - 1, y, POLE_LIGHT)
		img.set_pixel(ANCHOR.x, y, POLE)
	for p in [Vector2i(ANCHOR.x - 1, 1), Vector2i(ANCHOR.x, 1), Vector2i(ANCHOR.x - 1, 2), Vector2i(ANCHOR.x, 2)]:
		img.set_pixelv(p, FINIAL)
	_add_outline(img)
	return img


## Dolu piksellere komşu (4 yön) boş pikseller koyu kenar olur.
static func _add_outline(image: Image) -> void:
	var edge: Array[Vector2i] = []
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < image.get_width() and n.y < image.get_height() \
						and image.get_pixelv(n).a > 0.0:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		image.set_pixelv(p, OUTLINE)
