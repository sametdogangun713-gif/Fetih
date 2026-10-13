class_name UnitSprites
## Birlik sprite sayfaları (sprite sheet). Her sayfa yan yana 4 karedir: durma, yürüme A,
## yürüme B, saldırı. Figür sağa bakar; sola bakarken çizim yatay çevrilir (flip).
##
## UnitData.sprite_sheet doluysa o resim kullanılır (gerçek çizim / satın alınmış paket).
## Boşsa role göre koddan piksel sanat üretilir ve birliğin rengiyle boyanır.
## Üretilen sayfalar birlik başına bir kez yapılıp önbellekte tutulur.

enum Frame { IDLE, WALK_A, WALK_B, ATTACK }
const FRAME_COUNT := 4
const SOLDIER_FRAME := Vector2i(14, 14)
const BOSS_SCALE := 2
const BOSS_HEADROOM := 4  ## Boss karesinin üstünde taç için boş satır.

const OUTLINE := Color("1c1612")
const SKIN := Color("e8c8a0")
const METAL := Color("c9ccd4")
const METAL_DARK := Color("7f8491")
const WOOD := Color("7a5636")
const BOOT := Color("2e241c")
const STRING := Color("dcdcd0")
const FLASH := Color("ffd060")
const GOLD := Color("e8c25a")


## Bir birliğin çizime hazır sprite sayfası.
class Sheet:
	var texture: Texture2D
	var flash: Texture2D  ## Aynı şeklin beyaz silueti: vurulma anında üstüne çizilir.
	var frame_size: Vector2i

	func region(frame: int) -> Rect2:
		return Rect2(Vector2(frame * frame_size.x, 0), frame_size)


static var _cache := {}  ## birlik id -> Sheet


static func sheet_for(unit: UnitData) -> Sheet:
	if not _cache.has(unit.id):
		_cache[unit.id] = _build(unit)
	return _cache[unit.id]


## Arayüzde (kartlar, ordu kutuları) kullanılacak tek kare: birliğin durma hali.
static func icon(unit: UnitData) -> Texture2D:
	var sheet := sheet_for(unit)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet.texture
	atlas.region = sheet.region(Frame.IDLE)
	return atlas


static func _build(unit: UnitData) -> Sheet:
	var image: Image
	if unit.sprite_sheet:
		image = unit.sprite_sheet.get_image()
		image.convert(Image.FORMAT_RGBA8)
	else:
		image = _generate(unit)
	var sheet := Sheet.new()
	sheet.frame_size = Vector2i(image.get_width() / FRAME_COUNT, image.get_height())
	sheet.texture = ImageTexture.create_from_image(image)
	sheet.flash = ImageTexture.create_from_image(_silhouette(image))
	return sheet


# --- Üretim ---

static func _generate(unit: UnitData) -> Image:
	var body := unit.placeholder_color
	var pal := {
		body = body,
		dark = body.darkened(0.35),
		mid = body.darkened(0.15),
		light = body.lightened(0.35),
		face = SKIN.lerp(body, 0.35),
		glow = body.lightened(0.65),
	}
	var frame := SOLDIER_FRAME
	var sheet := Image.create_empty(frame.x * FRAME_COUNT, frame.y, false, Image.FORMAT_RGBA8)
	for f in FRAME_COUNT:
		var img := Image.create_empty(frame.x, frame.y, false, Image.FORMAT_RGBA8)
		_paint_role(img, unit.role, f, pal)
		_outline(img, OUTLINE)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, frame), Vector2i(f * frame.x, 0))
	if unit.is_boss:
		sheet = _boss_sheet(sheet, frame)
	return sheet


## Boss: asker figürünün iki katı büyüklüğü ve başının üstünde altın taç.
static func _boss_sheet(small: Image, frame: Vector2i) -> Image:
	var big_frame := frame * BOSS_SCALE + Vector2i(0, BOSS_HEADROOM)
	var sheet := Image.create_empty(big_frame.x * FRAME_COUNT, big_frame.y, false, Image.FORMAT_RGBA8)
	for f in FRAME_COUNT:
		var img := small.get_region(Rect2i(Vector2i(f * frame.x, 0), frame))
		img.resize(frame.x * BOSS_SCALE, frame.y * BOSS_SCALE, Image.INTERPOLATE_NEAREST)
		var out := Image.create_empty(big_frame.x, big_frame.y, false, Image.FORMAT_RGBA8)
		out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(0, BOSS_HEADROOM))
		_crown(out)
		sheet.blit_rect(out, Rect2i(Vector2i.ZERO, big_frame), Vector2i(f * big_frame.x, 0))
	return sheet


## Figürün en üst noktasının (baş) hemen üstüne üç dişli taç.
static func _crown(img: Image) -> void:
	var top := img.get_height()
	var head_x := 12
	for x in range(8, 18):
		for y in img.get_height():
			if img.get_pixel(x, y).a > 0.0:
				if y < top:
					top = y
					head_x = x
				break
	var y0 := maxi(top - 3, 0)
	var x0 := clampi(head_x - 2, 0, img.get_width() - 7)
	_rect(img, x0, y0 + 2, 7, 2, GOLD)
	for dx in [0, 3, 6]:
		_rect(img, x0 + dx, y0, 1, 2, GOLD)
	_px(img, x0 + 3, y0 + 2, Color("c0303a"))  # yakut


static func _paint_role(img: Image, role: StringName, f: int, pal: Dictionary) -> void:
	var attack := f == Frame.ATTACK
	match role:
		RoleRules.WARRIOR:
			_humanoid(img, f, pal)
			_rect(img, 5, 1, 3, 2, METAL)  # miğfer
			if attack:  # aşağı doğru kılıç savuruşu
				_px(img, 8, 6, pal.body)
				_px(img, 9, 7, pal.face)
				for i in 4:
					_px(img, 10 + i, 8 + i, METAL)
			else:
				_rect(img, 9, 1, 1, 5, METAL)
				_rect(img, 9, 6, 2, 1, METAL_DARK)
				_px(img, 9, 7, WOOD)
				_px(img, 8, 7, pal.face)
		RoleRules.SPEARMAN:
			if attack:  # mızrak öne uzatılmış
				_humanoid(img, f, pal)
				_rect(img, 3, 6, 9, 1, WOOD)
				_rect(img, 12, 6, 2, 1, METAL)
				_px(img, 9, 6, pal.face)
			else:
				_rect(img, 9, 0, 1, 12, WOOD)
				_rect(img, 9, 0, 1, 2, METAL)
				_humanoid(img, f, pal)
				_px(img, 8, 7, pal.face)
			_rect(img, 5, 1, 3, 1, METAL)
			_px(img, 4, 2, METAL)
		RoleRules.TANK:
			_humanoid(img, f, pal, true)
			_rect(img, 4, 1, 4, 3, METAL)  # kapalı miğfer
			_px(img, 7, 3, OUTLINE)  # göz yarığı
			var sx := 9 if attack else 8  # kalkanla itiş
			_rect(img, sx, 4, 3, 7, METAL_DARK)
			_rect(img, sx + 1, 5, 1, 5, pal.body)
		RoleRules.ARCHER:
			_rect(img, 3, 4, 1, 4, WOOD)  # sadak
			_humanoid(img, f, pal)
			_rect(img, 4, 1, 3, 1, pal.light)  # kukuleta
			_rect(img, 4, 2, 1, 3, pal.light)
			for p in [Vector2i(9, 3), Vector2i(10, 4), Vector2i(10, 5), Vector2i(10, 6),
					Vector2i(10, 7), Vector2i(10, 8), Vector2i(9, 9)]:
				_px(img, p.x, p.y, WOOD)
			if attack:  # yay gerilmiş, ok takılı
				for p in [Vector2i(9, 4), Vector2i(8, 5), Vector2i(8, 7), Vector2i(9, 8)]:
					_px(img, p.x, p.y, STRING)
				_rect(img, 7, 6, 5, 1, WOOD)
				_px(img, 12, 6, METAL)
				_px(img, 7, 6, pal.face)
			else:
				_rect(img, 9, 4, 1, 5, STRING)
				_px(img, 8, 6, pal.face)
		RoleRules.MAGE:
			_robe(img, f, pal)
			_rect(img, 4, 1, 4, 1, pal.light)  # sivri şapka
			_rect(img, 5, 0, 2, 1, pal.light)
			_px(img, 4, 2, pal.light)
			if attack:  # asa kalkık, küre parlıyor
				_rect(img, 10, 2, 1, 9, WOOD)
				_rect(img, 9, 0, 3, 3, pal.glow)
				_px(img, 10, 1, Color.WHITE)
				_px(img, 13, 1, pal.glow)
				_px(img, 12, 4, pal.glow)
				_px(img, 9, 5, pal.face)
			else:
				_rect(img, 10, 2, 1, 11, WOOD)
				_rect(img, 10, 0, 2, 2, pal.glow)
				_px(img, 9, 7, pal.face)
		RoleRules.CAVALRY:
			_cavalry(img, f, pal)
		RoleRules.SIEGE:
			_cannon(img, f, pal)
		_:
			_humanoid(img, f, pal)


## İnsan gövdesi: baş, gövde, kol, bacaklar (yürüme karesine göre).
static func _humanoid(img: Image, f: int, pal: Dictionary, wide := false) -> void:
	_legs(img, f, pal)
	var x := 3 if wide else 4
	var w := 5 if wide else 4
	_rect(img, x, 5, w, 4, pal.body)
	_rect(img, x, 5, 1, 4, pal.dark)  # sırt gölgesi
	_rect(img, x, 8, w, 1, pal.dark)  # kemer
	_rect(img, 5, 2, 3, 3, pal.face)
	_px(img, 7, 3, OUTLINE)  # göz
	_rect(img, 8, 5, 1, 2, pal.light)  # ön kol


static func _legs(img: Image, f: int, pal: Dictionary) -> void:
	match f:
		Frame.WALK_A:  # adım: bacaklar açık
			_rect(img, 4, 9, 2, 2, pal.dark)
			_rect(img, 3, 11, 2, 2, pal.dark)
			_rect(img, 6, 9, 2, 2, pal.mid)
			_rect(img, 7, 11, 2, 2, pal.mid)
			_rect(img, 3, 12, 2, 1, BOOT)
			_rect(img, 7, 12, 2, 1, BOOT)
		Frame.WALK_B:  # bacaklar yan yana geçerken
			_rect(img, 5, 9, 2, 4, pal.mid)
			_rect(img, 5, 12, 2, 1, BOOT)
		_:
			_rect(img, 4, 9, 2, 4, pal.dark)
			_rect(img, 6, 9, 2, 4, pal.mid)
			_rect(img, 4, 12, 4, 1, BOOT)


## Büyücü: bacak yerine cübbe; yürürken etek ucu sallanır.
static func _robe(img: Image, f: int, pal: Dictionary) -> void:
	_rect(img, 4, 5, 4, 5, pal.body)
	_rect(img, 3, 9, 6, 4, pal.body)
	_rect(img, 3, 9, 1, 4, pal.dark)
	var hem := 1 if f == Frame.WALK_A else (-1 if f == Frame.WALK_B else 0)
	_rect(img, 3 + maxi(hem, 0), 12, 6, 1, pal.dark)
	_rect(img, 5, 2, 3, 3, pal.face)
	_px(img, 7, 3, OUTLINE)
	_rect(img, 8, 5, 1, 3, pal.light)


## Süvari: birliğin koyu renginde binek (at, kurt, geyik, kentaur gövdesi) ve üstünde binici.
static func _cavalry(img: Image, f: int, pal: Dictionary) -> void:
	var mount: Color = pal.dark
	var leg_x: Array = [3, 5, 8, 10]
	if f == Frame.WALK_A:
		leg_x = [2, 5, 9, 10]
	elif f == Frame.WALK_B:
		leg_x = [4, 5, 8, 9]
	for x in leg_x:
		_rect(img, x, 11, 1, 2, mount.darkened(0.2))
	_rect(img, 2, 8, 9, 3, mount)
	_rect(img, 10, 6, 2, 3, mount)  # boyun
	_rect(img, 11, 5, 3, 2, mount)  # baş
	_px(img, 1, 8, mount.darkened(0.3))  # kuyruk
	_px(img, 1, 9, mount.darkened(0.3))
	_rect(img, 4, 8, 4, 2, pal.body)  # eyer örtüsü
	# binici
	_rect(img, 5, 4, 3, 4, pal.body)
	_rect(img, 5, 4, 1, 4, pal.dark)
	_rect(img, 5, 1, 3, 3, pal.face)
	_rect(img, 5, 1, 3, 1, METAL)
	_px(img, 7, 2, OUTLINE)
	if f == Frame.ATTACK:  # mızrak hücumda öne indirilmiş
		_rect(img, 6, 5, 7, 1, WOOD)
		_px(img, 13, 5, METAL)
		_px(img, 8, 5, pal.face)
	else:
		_rect(img, 9, 0, 1, 8, WOOD)
		_px(img, 9, 0, METAL)
		_px(img, 8, 5, pal.face)


## Kuşatma: tekerlekli top ve birliğin renginde küçük sancak. Ateşte namlu geri teper.
static func _cannon(img: Image, f: int, pal: Dictionary) -> void:
	var recoil := -1 if f == Frame.ATTACK else 0
	_px(img, 2, 3, WOOD)
	_rect(img, 2, 4, 1, 5, WOOD)
	_rect(img, 3, 4, 2, 2, pal.body)
	_rect(img, 2, 9, 9, 2, WOOD)
	_rect(img, 4 + recoil, 6, 6, 3, METAL_DARK)
	_rect(img, 10 + recoil, 5, 2, 5, METAL_DARK)
	_rect(img, 4 + recoil, 6, 6, 1, METAL)
	_rect(img, 3, 9, 3, 3, WOOD.darkened(0.3))  # tekerlek
	_rect(img, 7, 9, 3, 3, WOOD.darkened(0.3))
	var hub := 0 if f == Frame.WALK_B else 1  # dönen tekerlek göbeği
	_px(img, 3 + hub, 10, METAL)
	_px(img, 7 + hub, 10, METAL)
	if f == Frame.ATTACK:
		_rect(img, 12, 6, 2, 3, FLASH)
		_px(img, 13, 5, FLASH)
		_px(img, 13, 9, FLASH)


## Saydam olup dolu bir komşusu olan her piksel kenar çizgisi olur.
static func _outline(img: Image, color: Color) -> void:
	var source := img.duplicate() as Image
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			if source.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h and source.get_pixelv(n).a > 0.0:
					img.set_pixel(x, y, color)
					break


static func _silhouette(image: Image) -> Image:
	var out := image.duplicate() as Image
	for y in out.get_height():
		for x in out.get_width():
			var a := out.get_pixel(x, y).a
			if a > 0.0:
				out.set_pixel(x, y, Color(1, 1, 1, a))
	return out


static func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h).intersection(Rect2i(Vector2i.ZERO, img.get_size())), color)


static func _px(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, color)
