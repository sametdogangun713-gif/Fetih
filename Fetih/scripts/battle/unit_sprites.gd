class_name UnitSprites
## Birlik sprite sayfaları (sprite sheet).
##
## SAYFA DÜZENİ (kendi çizimlerin de bu düzende olmalı):
## - 4 satır: 0 durma, 1 yürüme, 2 saldırı, 3 ölüm.
## - Her satırda o animasyonun kareleri soldan sağa. Satırlarda farklı sayıda kare olabilir:
##   tamamen saydam kareler sayılmaz. Bir satır boşsa durma satırı kullanılır.
## - Kareler kare biçimlidir; boyutu = resim yüksekliği / 4 (asker 32x32, boss 64x64 önerilir).
## - Figür sağa bakar (sola giderken oyun çevirir). Ayakların ortası karenin alt ortasında,
##   en alt satırın bir üstünde durur.
## - Ölüm satırının son karesi yerde kalan bedendir.
##
## DOSYA: assets/sprites/units/<birlik id>.png varsa o kullanılır (ör. elf_archer.png,
## boss için human_boss.png). Yoksa sprite koddan üretilir (bkz. generate): beden türü krallık ve
## role göre seçilir (atlı, kentaur, golem, top, insansı), renkler birliğin rengi ve krallığın
## görünümünden gelir. Çizim parçaları scripts/battle/unit_art/ altında.

enum Anim { IDLE, WALK, ATTACK, DEATH }
const ROWS := 4
const SIZE := 32  ## Üretilen asker karesi (hazır CC0 sayfalarla aynı ölçek).
## Üretilen sayfada satır başına kare: durma 4 (2 kare/sn nefes), yürüme 6 (7 kare/sn adım
## döngüsü), saldırı 6 (0.2 sn: hazırlık, vuruş, takip, toparlanma), ölüm 6 (0.36 sn devrilme).
const GEN_FRAMES: Array[int] = [4, 6, 6, 6]
const BOSS_SCALE := 2
const USER_DIR := "res://assets/sprites/units/"

const OUTLINE := SpritePainter.OUTLINE
const GOLD := Color("e8c25a")

## Krallığa göre görünüm (ten, saç, metal, göz...). Birliğin rengi `cloth` olarak eklenir.
## Listede olmayan krallık DEFAULT_LOOK ile çizilir.
const DEFAULT_LOOK := {
	skin = Color("e8c09a"), hair = Color("5a3a24"), pants = Color("4a4038"), boots = Color("3a2a20"),
	metal = Color("b8bec8"), leather = Color("7a5232"), wood = Color("8a6038"), trim = Color("c8443a"),
	eye = Color("1c1612"), glow = Color("9fe8ff"),
}
const KINGDOM_LOOKS := {}


## Bir birliğin çizime hazır sprite sayfası.
class Sheet:
	var texture: Texture2D
	var flash: Texture2D  ## Aynı şeklin beyaz silueti: vurulma anında üstüne çizilir.
	var frame_size: Vector2i
	var counts: Array[int] = [1, 1, 1, 1]  ## Animasyon başına kare sayısı.
	var rows: Array[int] = [0, 1, 2, 3]  ## Animasyon -> sayfadaki satır (boş satır durmaya düşer).

	func count(anim: int) -> int:
		return counts[anim]

	func region(anim: int, frame: int) -> Rect2:
		var f := clampi(frame, 0, counts[anim] - 1)
		return Rect2(Vector2(f * frame_size.x, rows[anim] * frame_size.y), frame_size)


static var _cache := {}  ## birlik id -> Sheet


static func sheet_for(unit: UnitData) -> Sheet:
	if not _cache.has(unit.id):
		_cache[unit.id] = _build(unit)
	return _cache[unit.id]


## Arayüzde (kartlar, ordu kutuları) kullanılacak tek kare: birliğin durma hali, figürün dolu
## kısmına kırpılmış (kare boyutu sayfadan sayfaya değişir: 24, 32, 64...).
static func icon(unit: UnitData) -> Texture2D:
	var sheet := sheet_for(unit)
	var region := Rect2i(sheet.region(Anim.IDLE, 0))
	var used := sheet.texture.get_image().get_region(region).get_used_rect()
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet.texture
	atlas.region = Rect2(region.position + used.position, used.size) if used.has_area() else Rect2(region)
	return atlas


## Önbelleği boşaltır (yeni çizim dosyası eklenince oyunu kapatmadan görmek için).
static func clear_cache() -> void:
	_cache.clear()


static func user_path(unit: UnitData) -> String:
	return USER_DIR + String(unit.id) + ".png"


static func _build(unit: UnitData) -> Sheet:
	var image: Image
	var path := user_path(unit)
	if ResourceLoader.exists(path):
		image = (load(path) as Texture2D).get_image()
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
	else:
		image = generate(unit)
	var sheet := Sheet.new()
	var side := image.get_height() / ROWS
	sheet.frame_size = Vector2i(side, side)
	for anim in ROWS:
		sheet.counts[anim] = _count_frames(image, anim, side)
	for anim in ROWS:
		if sheet.counts[anim] == 0:
			sheet.rows[anim] = Anim.IDLE
			sheet.counts[anim] = maxi(sheet.counts[Anim.IDLE], 1)
	sheet.texture = ImageTexture.create_from_image(image)
	sheet.flash = ImageTexture.create_from_image(_silhouette(image))
	return sheet


## Satırdaki dolu (en az bir görünür pikseli olan) kareleri soldan sayar.
static func _count_frames(image: Image, row: int, side: int) -> int:
	var n := 0
	for col in image.get_width() / side:
		var cell := image.get_region(Rect2i(col * side, row * side, side, side))
		if cell.is_invisible():
			break
		n += 1
	return n


# --- Koddan üretim ---

## 32x32 karelik sayfa (boss ise 2 kat büyük ve taçlı). Beden türü body_kind() ile seçilir.
static func generate(unit: UnitData) -> Image:
	var look := _look(unit)
	var kind := body_kind(unit)
	var columns: int = GEN_FRAMES.max()
	var sheet := Image.create_empty(SIZE * columns, SIZE * ROWS, false, Image.FORMAT_RGBA8)
	for anim in ROWS:
		for f in GEN_FRAMES[anim]:
			var img := _frame(kind, unit.role, anim, f, look)
			sheet.blit_rect(img, Rect2i(0, 0, SIZE, SIZE), Vector2i(f * SIZE, anim * SIZE))
	if unit.is_boss:
		sheet = _boss_sheet(sheet)
	return sheet


## Beden türü: krallık ve rolden. humanoid her rolü çizebilir (yedek).
static func body_kind(_unit: UnitData) -> StringName:
	return &"humanoid"


static func _frame(_kind: StringName, role: StringName, anim: int, f: int, look: Dictionary) -> Image:
	return HumanoidArt.frame(role, anim, f, look)


## Krallık görünümü + birlik rengi (cloth) + hazır renk rampaları (r).
static func _look(unit: UnitData) -> Dictionary:
	var look := DEFAULT_LOOK.duplicate()
	look.merge(KINGDOM_LOOKS.get(unit.kingdom, {}), true)
	look.cloth = unit.placeholder_color
	look.id = unit.id
	look.r = HumanoidArt.ramps(look)
	return look


## Boss: asker figürünün iki katı büyüklüğü ve başının üstünde altın taç (ölüm karelerinde düşer).
static func _boss_sheet(small: Image) -> Image:
	var big := small.duplicate() as Image
	big.resize(small.get_width() * BOSS_SCALE, small.get_height() * BOSS_SCALE, Image.INTERPOLATE_NEAREST)
	var side := SIZE * BOSS_SCALE
	for anim in [Anim.IDLE, Anim.WALK, Anim.ATTACK]:
		for f in GEN_FRAMES[anim]:
			var cell := big.get_region(Rect2i(f * side, anim * side, side, side))
			_crown(cell)
			big.blit_rect(cell, Rect2i(0, 0, side, side), Vector2i(f * side, anim * side))
	return big


static func _crown(img: Image) -> void:
	var top := img.get_height()
	var head_x := img.get_width() / 2
	for x in range(img.get_width() / 3, img.get_width() * 2 / 3):
		for y in img.get_height():
			if img.get_pixel(x, y).a > 0.0:
				if y < top:
					top = y
					head_x = x
				break
	var y0 := maxi(top - 4, 0)
	var x0 := clampi(head_x - 3, 0, img.get_width() - 8)
	_rect(img, x0, y0 + 2, 8, 3, GOLD)
	_rect(img, x0, y0 + 4, 8, 1, GOLD.darkened(0.3))
	for dx in [0, 3, 4, 7]:
		_rect(img, x0 + dx, y0, 1, 2, GOLD)
	_px(img, x0 + 3, y0 + 3, Color("c0303a"))
	_px(img, x0 + 4, y0 + 3, Color("c0303a"))


static func _silhouette(image: Image) -> Image:
	var out := image.duplicate() as Image
	for y in out.get_height():
		for x in out.get_width():
			var a := out.get_pixel(x, y).a
			if a > 0.0:
				out.set_pixel(x, y, Color(1, 1, 1, a))
	return out


static func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	var r := Rect2i(x, y, w, h).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.has_area():
		img.fill_rect(r, color)


static func _px(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, color)
