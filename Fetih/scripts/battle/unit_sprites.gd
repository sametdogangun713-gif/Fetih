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
## DOSYA (sadece boss): assets/sprites/units/<birlik id>.png varsa o kullanılır (ör. elf_archer.png,
## boss için human_boss.png). Yoksa sprite koddan üretilir (bkz. generate): beden türü krallık ve
## role göre seçilir (atlı, top, mancınık, insansı), renkler birliğin rengi ve krallığın
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

## Krallığa göre görünüm (ten, saç, metal, göz, binek...). Renkler Resurrect 64 paletinden
## (bkz. SpritePalette) ve gorsel_yon_dokumani.md krallık renk kimliğinden seçildi.
## Birliğin rengi (placeholder_color) `cloth` olur; krallık `cloth` verirse o kullanılır ve
## birliğin rengi bineğe geçer (`coat_unit`). Listede olmayan krallık DEFAULT_LOOK ile çizilir.
const DEFAULT_LOOK := {
	skin = Color("fca790"), hair = Color("4c3e24"), pants = Color("3e3546"), boots = Color("2e222f"),
	metal = Color("c7dcd0"), leather = Color("9e4539"), wood = Color("966c6c"), trim = Color("e83b3b"),
	eye = Color("2e222f"), glow = Color("8fd3ff"),
	mount = &"horse", coat = Color("9e4539"), mane = Color("4c3e24"),
}
const KINGDOM_LOOKS := {
	&"humans": {  # şövalye: kestane at, kraliyet moru örtü, sorguçlu kapalı miğfer, flamalı kargı
		trim = Color("f9c22b"), barding = Color("6b3e75"), barding_on = true, rider_helm = &"full", metal = Color("9babb2"),
		pennant = true, hair = Color("7a3045"),
	},
	&"elves": {  # geyik binici: açık saçlı, yeşil giysili; geyik birliğin renginde
		hair = Color("fbb954"), long_hair = true, cloth = Color("239063"), trim = Color("cddf6c"),
		mount = &"stag", coat_unit = true, rider_helm = &"none", leather = Color("7a3045"),
	},
	&"orcs": {  # kurt binici: yeşil ten, dişler, boynuzlu kara demir miğfer; kurt birliğin renginde
		skin = Color("a2a947"), face = &"orc", eye = Color("e83b3b"), cloth = Color("676633"),
		metal = Color("625565"), trim = Color("ae2334"), mount = &"wolf", coat_unit = true,
		mane = Color("3e3546"), mount_eye = Color("f9c22b"), rider_helm = &"horned",
	},
	&"undead": {  # ölü şövalye: kafatası, parlayan vizör, iskelet at, yırtık örtü
		skin = Color("c7dcd0"), face = &"skull", eye = Color("30e1b9"), hair_on = false,
		metal = Color("484a77"), visor = Color("30e1b9"), plume = false, trim = Color("0b8a8f"),
		mount = &"undead_horse", coat = Color("3e3546"), mane = Color("30e1b9"), mount_eye = Color("8ff8e2"),
		barding = Color("45293f"), barding_on = true, tattered = true, rider_helm = &"full",
	},
}


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


## Minik birliklerin gövde renkleri (9 Kings gibi: oyuncu altın, rakip kırmızı).
const TEAM_PLAYER := Color("f9c22b")
const TEAM_ENEMY := Color("e83b3b")

static var _cache := {}  ## "birlik id_takım" -> Sheet


## Birliğin sprite sayfası. Boss dışındakiler MiniUnitArt ile takım renginde çizilir
## (önbellek anahtarı birlik + takım); boss büyük çizimle (dosya ya da generate) kalır.
static func sheet_for(unit: UnitData, team := SquadState.Team.PLAYER) -> Sheet:
	var key := "%s_%d" % [unit.id, team]
	if not _cache.has(key):
		_cache[key] = _build(unit, team)
	return _cache[key]


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


static func team_color(team: int) -> Color:
	return TEAM_ENEMY if team == SquadState.Team.ENEMY else TEAM_PLAYER


static func _build(unit: UnitData, team: int) -> Sheet:
	var image: Image
	var path := user_path(unit)
	if not unit.is_boss:
		image = MiniUnitArt.sheet(unit, team_color(team))
	elif ResourceLoader.exists(path):
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
	var kind := body_kind(unit)
	var look := _look(unit, kind)
	var columns: int = GEN_FRAMES.max()
	var sheet := Image.create_empty(SIZE * columns, SIZE * ROWS, false, Image.FORMAT_RGBA8)
	for anim in ROWS:
		for f in GEN_FRAMES[anim]:
			var img := _frame(kind, unit.role, anim, f, look)
			sheet.blit_rect(img, Rect2i(0, 0, SIZE, SIZE), Vector2i(f * SIZE, anim * SIZE))
	SpritePalette.quantize(sheet)  # iç kontur, efekt gibi ara renkler de Resurrect 64'e
	if unit.is_boss:
		sheet = _boss_sheet(sheet)
	return sheet


## Beden türü: krallık ve rolden. rider: binekli kargıcı (süvari); humanoid her rolü çizebilir (yedek).
static func body_kind(unit: UnitData) -> StringName:
	if unit.role == RoleRules.CAVALRY:
		return &"rider"
	if unit.role == RoleRules.SIEGE and not unit.is_boss:  # boss (Thrain) taçlı insansı kalır
		return &"catapult" if unit.kingdom == &"golems" else &"cannon"
	return &"humanoid"


static func _frame(kind: StringName, role: StringName, anim: int, f: int, look: Dictionary) -> Image:
	match kind:
		&"rider":
			return RiderArt.frame(look, anim, f)
		&"cannon", &"catapult":
			return SiegeArt.frame(kind, anim, f, look)
	return HumanoidArt.frame(role, anim, f, look)


## Krallık görünümü + birlik rengi + hazır renk rampaları (r).
static func _look(unit: UnitData, kind: StringName) -> Dictionary:
	var look := DEFAULT_LOOK.duplicate()
	var kingdom: Dictionary = KINGDOM_LOOKS.get(unit.kingdom, {})
	look.merge(kingdom, true)
	if not kingdom.has("cloth"):
		look.cloth = unit.placeholder_color
	if look.get("coat_unit", false):
		look.coat = unit.placeholder_color
	look.id = unit.id
	if kind == &"rider":  # binici kafası biraz küçük: atlı figürü ~22 piksel boyda kalsın
		look.head_r = Vector2(3.3, 3.2)
		look.head_dy = -3.5
	look.r = HumanoidArt.ramps(look)
	MountArt.add_ramps(look)
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
