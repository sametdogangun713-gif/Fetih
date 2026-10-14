class_name UnitSprites
## Birlik sprite sayfaları (sprite sheet).
##
## SAYFA DÜZENİ (kendi çizimlerin de bu düzende olmalı):
## - 4 satır: 0 durma, 1 yürüme, 2 saldırı, 3 ölüm.
## - Her satırda o animasyonun kareleri soldan sağa. Satırlarda farklı sayıda kare olabilir:
##   tamamen saydam kareler sayılmaz. Bir satır boşsa durma satırı kullanılır.
## - Kareler kare biçimlidir; boyutu = resim yüksekliği / 4 (asker 24x24, boss 48x48 önerilir).
## - Figür sağa bakar (sola giderken oyun çevirir). Ayakların ortası karenin alt ortasında,
##   en alt satırın bir üstünde durur.
## - Ölüm satırının son karesi yerde kalan bedendir.
##
## DOSYA: assets/sprites/units/<birlik id>.png varsa o kullanılır (ör. elf_archer.png,
## boss için human_boss.png). Yoksa sprite role göre koddan üretilir ve birliğin rengiyle boyanır.
## tools/export_sprite_templates.gd üretilen sayfaları çizime başlangıç şablonu olarak kaydeder.

enum Anim { IDLE, WALK, ATTACK, DEATH }
const ROWS := 4
const SIZE := 24  ## Üretilen asker karesi.
const GEN_FRAMES: Array[int] = [2, 4, 4, 4]  ## Üretilen sayfada satır başına kare.
const BOSS_SCALE := 2
const USER_DIR := "res://assets/sprites/units/"

const OUTLINE := Color("1c1612")
const SKIN := Color("e8c8a0")
const METAL := Color("d4d8e0")
const METAL_DARK := Color("7f8491")
const WOOD := Color("7a5636")
const BOOT := Color("2e241c")
const STRING := Color("e4e4d8")
const FLASH := Color("ffe070")
const SMOKE := Color("a8a49c")
const GOLD := Color("e8c25a")


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

## Role göre 24x24 karelik sayfa (boss ise 2 kat büyük ve taçlı). Şablon aracı da bunu kullanır.
static func generate(unit: UnitData) -> Image:
	var body := unit.placeholder_color
	var pal := {
		body = body,
		dark = body.darkened(0.35),
		mid = body.darkened(0.15),
		light = body.lightened(0.3),
		skin = SKIN.lerp(body, 0.3),
		glow = body.lightened(0.6),
		mount = body.darkened(0.45),
	}
	var columns: int = GEN_FRAMES.max()
	var sheet := Image.create_empty(SIZE * columns, SIZE * ROWS, false, Image.FORMAT_RGBA8)
	for anim in ROWS:
		for f in GEN_FRAMES[anim]:
			var img := _frame(unit.role, anim, f, pal)
			sheet.blit_rect(img, Rect2i(0, 0, SIZE, SIZE), Vector2i(f * SIZE, anim * SIZE))
	if unit.is_boss:
		sheet = _boss_sheet(sheet)
	return sheet


static func _frame(role: StringName, anim: int, f: int, pal: Dictionary) -> Image:
	if anim == Anim.DEATH:
		# Ölüm: önce sarsılır, sonra ayaklarının üstünden geriye devrilir.
		var hit := _canvas()
		var pose := _pose(role, Anim.IDLE, 0)
		pose.lean = -1
		_paint_role(hit, role, pose, pal)
		_outline(hit)
		if f == 0:
			return hit
		return _rotated(hit, [0.0, 35.0, 70.0, 90.0][f])
	var img := _canvas()
	_paint_role(img, role, _pose(role, anim, f), pal)
	_outline(img)
	return img


static func _canvas() -> Image:
	return Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)


## Kare başına duruş: gövde inip kalkması, bacak evresi, el konumu, silah açısı (derece; 0 = sağ,
## -90 = yukarı), uzanma, parıltı, geri tepme.
static func _pose(role: StringName, anim: int, f: int) -> Dictionary:
	var p := {bob = 0, lean = 0, legs = 0, hand = Vector2i(16, 13), angle = -60.0, glow = 0, recoil = 0,
			fx = 0, wheel = 0}
	match anim:
		Anim.IDLE:
			p.bob = f  # nefes alır gibi bir piksel iner
		Anim.WALK:
			p.legs = [1, 2, 3, 2][f]
			p.bob = [0, -1, 0, -1][f]
			p.wheel = f
		Anim.ATTACK:
			p.lean = [-1, 0, 1, 0][f]
			p.fx = f + 1
	match role:
		RoleRules.WARRIOR:
			if anim == Anim.ATTACK:  # kılıcı başın üstünden aşağı savurur
				p.hand = [Vector2i(14, 9), Vector2i(17, 10), Vector2i(18, 13), Vector2i(17, 14)][f]
				p.angle = [-150.0, -45.0, 20.0, 50.0][f]
		RoleRules.SPEARMAN:
			p.hand = Vector2i(15, 14)
			p.angle = -88.0
			if anim == Anim.ATTACK:  # geri çeker, ileri saplar
				p.hand = [Vector2i(13, 12), Vector2i(18, 12), Vector2i(19, 12), Vector2i(16, 13)][f]
				p.angle = [-8.0, -5.0, -3.0, -30.0][f]
		RoleRules.TANK:
			p.recoil = [0, 1, 3, 1][f] if anim == Anim.ATTACK else 0  # kalkanla itme
		RoleRules.CAVALRY:
			p.hand = Vector2i(14, 7)
			p.angle = -80.0
			if anim == Anim.ATTACK:  # mızrak hücumda indirilir
				p.hand = [Vector2i(14, 7), Vector2i(15, 8), Vector2i(17, 8), Vector2i(15, 8)][f]
				p.angle = [-45.0, -10.0, -3.0, -30.0][f]
		RoleRules.SIEGE:
			p.recoil = [0, -2, -1, 0][f] if anim == Anim.ATTACK else 0
	return p


static func _paint_role(img: Image, role: StringName, p: Dictionary, pal: Dictionary) -> void:
	var o := Vector2i(p.lean, p.bob)
	match role:
		RoleRules.WARRIOR:
			_legs(img, p, pal)
			_torso(img, o, pal)
			_head(img, o, pal)
			_rect(img, 10 + o.x, 3 + o.y, 5, 2, METAL)  # miğfer
			_rect(img, 10 + o.x, 3 + o.y, 1, 4, METAL_DARK)
			_px(img, 12 + o.x, 2 + o.y, pal.body)  # sorguç
			_px(img, 11 + o.x, 2 + o.y, pal.body)
			_arm(img, o, p.hand + o, pal)
			_sword(img, p.hand + o, p.angle)
		RoleRules.SPEARMAN:
			_legs(img, p, pal)
			_torso(img, o, pal)
			_head(img, o, pal)
			_rect(img, 10 + o.x, 3 + o.y, 5, 1, METAL)  # konik miğfer
			_rect(img, 11 + o.x, 2 + o.y, 3, 1, METAL)
			_px(img, 12 + o.x, 1 + o.y, METAL)
			_shaft(img, p.hand + o, p.angle, 4, 14, WOOD)
			_tip(img, p.hand + o, p.angle, 14, 3)
			_arm(img, o, p.hand + o, pal)
		RoleRules.TANK:
			_legs(img, p, pal)
			_torso(img, o, pal, true)
			_head(img, o, pal)
			_rect(img, 10 + o.x, 3 + o.y, 5, 5, METAL)  # kapalı miğfer
			_rect(img, 10 + o.x, 3 + o.y, 1, 5, METAL_DARK)
			_rect(img, 12 + o.x, 6 + o.y, 3, 1, OUTLINE)  # göz yarığı
			_arm(img, o, Vector2i(16, 12) + o, pal)
			var sx: int = 15 + p.recoil + o.x
			_rect(img, sx, 8 + o.y, 5, 12, METAL_DARK)  # kalkan
			_rect(img, sx + 1, 9 + o.y, 3, 10, pal.body)
			_rect(img, sx + 1, 9 + o.y, 3, 1, pal.light)
			_px(img, sx + 2, 13 + o.y, METAL)  # kalkan göbeği
			_px(img, sx + 2, 14 + o.y, METAL)
		RoleRules.ARCHER:
			_rect(img, 7 + o.x, 9 + o.y, 2, 7, WOOD)  # sadak
			_px(img, 7 + o.x, 8 + o.y, Color.WHITE)
			_px(img, 8 + o.x, 7 + o.y, pal.light)
			_legs(img, p, pal)
			_torso(img, o, pal)
			_head(img, o, pal)
			_rect(img, 9 + o.x, 3 + o.y, 6, 2, pal.light)  # kukuleta
			_rect(img, 9 + o.x, 5 + o.y, 2, 4, pal.light)
			_bow(img, o, int(p.fx), pal)
		RoleRules.MAGE:
			_robe(img, o, p, pal)
			_head(img, o, pal)
			_hat(img, o, pal)
			_staff(img, o, int(p.fx), pal)
		RoleRules.CAVALRY:
			_cavalry(img, p, pal)
		RoleRules.SIEGE:
			_cannon(img, p, pal)
		_:
			_legs(img, p, pal)
			_torso(img, o, pal)
			_head(img, o, pal)


static func _legs(img: Image, p: Dictionary, pal: Dictionary) -> void:
	var back: Color = pal.dark.darkened(0.1)
	var front: Color = pal.mid
	match int(p.legs):
		1:  # adım: arka bacak geride, ön bacak önde
			_rect(img, 9, 17, 2, 2, back)
			_rect(img, 8, 19, 2, 3, back)
			_rect(img, 12, 17, 2, 2, front)
			_rect(img, 13, 19, 2, 3, front)
			_rect(img, 7, 21, 3, 1, BOOT)
			_rect(img, 13, 21, 3, 1, BOOT)
		2:  # bacaklar yan yana geçiyor
			_rect(img, 10, 17, 2, 5, back)
			_rect(img, 11, 17, 2, 4, front)
			_rect(img, 10, 21, 4, 1, BOOT)
		3:  # öbür adım
			_rect(img, 12, 17, 2, 2, back)
			_rect(img, 13, 19, 2, 3, back)
			_rect(img, 9, 17, 2, 2, front)
			_rect(img, 8, 19, 2, 3, front)
			_rect(img, 7, 21, 3, 1, BOOT)
			_rect(img, 13, 21, 3, 1, BOOT)
		_:
			_rect(img, 9, 17, 2, 5, back)
			_rect(img, 12, 17, 2, 5, front)
			_rect(img, 9, 21, 3, 1, BOOT)
			_rect(img, 12, 21, 3, 1, BOOT)


static func _torso(img: Image, o: Vector2i, pal: Dictionary, wide := false) -> void:
	var x := (8 if wide else 9) + o.x
	var w := 8 if wide else 6
	_rect(img, x, 10 + o.y, w, 6, pal.body)
	_rect(img, x, 10 + o.y, 1, 6, pal.dark)  # sırt gölgesi
	_rect(img, x + 1, 10 + o.y, w - 2, 1, pal.light)  # omuz ışığı
	_rect(img, x, 15 + o.y, w, 1, pal.dark)  # kemer
	_px(img, x + w - 2, 15 + o.y, GOLD)  # toka
	_rect(img, x - o.x, 16, w, 1, pal.mid)  # kalça: gövde inip kalkarken bacaklarla arası açılmasın


static func _head(img: Image, o: Vector2i, pal: Dictionary) -> void:
	_rect(img, 10 + o.x, 4 + o.y, 5, 6, pal.skin)
	_rect(img, 10 + o.x, 4 + o.y, 1, 6, pal.skin.darkened(0.2))
	_px(img, 13 + o.x, 6 + o.y, OUTLINE)  # göz
	_px(img, 14 + o.x, 8 + o.y, pal.skin.darkened(0.25))


## Ön kol: omuzdan ele.
static func _arm(img: Image, o: Vector2i, hand: Vector2i, pal: Dictionary) -> void:
	var shoulder := Vector2i(14, 11) + o
	_line(img, shoulder, hand, pal.light)
	_line(img, shoulder + Vector2i(0, 1), hand + Vector2i(0, 1), pal.body)
	_rect(img, hand.x, hand.y, 2, 2, pal.skin)


static func _sword(img: Image, hand: Vector2i, angle: float) -> void:
	var dir := Vector2.from_angle(deg_to_rad(angle))
	var side := Vector2(-dir.y, dir.x)
	var h := Vector2(hand) + Vector2(0.5, 0.5)
	_line(img, _v(h - dir), _v(h), WOOD)  # kabza
	_line(img, _v(h + dir - side * 2.0), _v(h + dir + side * 2.0), METAL_DARK)  # balçak
	_line(img, _v(h + dir * 2.0), _v(h + dir * 9.0), METAL)  # namlu
	_line(img, _v(h + dir * 2.0 + side), _v(h + dir * 8.0 + side), METAL_DARK)


## Sap (mızrak, asa, kargı): elden geriye `back`, ileriye `length` piksel.
static func _shaft(img: Image, hand: Vector2i, angle: float, back: float, length: float, color: Color) -> void:
	var dir := Vector2.from_angle(deg_to_rad(angle))
	var h := Vector2(hand) + Vector2(0.5, 0.5)
	_line(img, _v(h - dir * back), _v(h + dir * length), color)


static func _tip(img: Image, hand: Vector2i, angle: float, at: float, length: float) -> void:
	var dir := Vector2.from_angle(deg_to_rad(angle))
	var h := Vector2(hand) + Vector2(0.5, 0.5)
	_line(img, _v(h + dir * at), _v(h + dir * (at + length)), METAL)


## Yay: önde dışa bükük ağaç, kiriş. fx: 0 bekleme, 1 ok takılı, 2 gerilmiş, 3 bırakıldı, 4 toparlanma.
static func _bow(img: Image, o: Vector2i, fx: int, pal: Dictionary) -> void:
	var cx := 17 + o.x
	var cy := 12 + o.y
	for dy in range(-5, 6):
		var bulge := roundi(2.0 * (1.0 - pow(dy / 5.0, 2.0)))
		_px(img, cx + bulge, cy + dy, WOOD)
	var pull := 3 if fx == 2 else 0
	var nock := Vector2i(cx - pull, cy)
	_line(img, Vector2i(cx, cy - 5), nock, STRING)
	_line(img, nock, Vector2i(cx, cy + 5), STRING)
	if fx == 1 or fx == 2:  # ok
		_line(img, nock, nock + Vector2i(7, 0), WOOD)
		_px(img, nock.x + 7, cy, METAL)
		_px(img, nock.x + 8, cy, METAL)
		_px(img, nock.x, cy - 1, Color.WHITE)  # tüy
	_arm(img, o, Vector2i(cx - 1, cy - 1), pal)
	if fx == 2:  # geri çeken el
		_rect(img, nock.x - 1, cy - 1, 2, 2, pal.skin)


## Büyücü cübbesi: aşağı doğru genişler; yürürken etek ucu sallanır.
static func _robe(img: Image, o: Vector2i, p: Dictionary, pal: Dictionary) -> void:
	var sway: int = [0, 1, 0, -1][int(p.legs)] if int(p.legs) > 0 else 0
	for y in range(10, 22):
		var half := 3 + (y - 10) / 4
		var shift := sway if y >= 19 else 0
		var oy := o.y if y < 16 else 0
		var oxx := o.x if y < 16 else 0
		_rect(img, 12 - half + shift + oxx, y + oy, half * 2, 1, pal.body)
		_px(img, 12 - half + shift + oxx, y + oy, pal.dark)
	_rect(img, 9 + sway, 21, 7, 1, pal.dark)  # etek ucu
	_rect(img, 10 + o.x, 10 + o.y, 5, 1, pal.light)
	_px(img, 13 + o.x, 13 + o.y, GOLD)  # kuşak


static func _hat(img: Image, o: Vector2i, pal: Dictionary) -> void:
	_rect(img, 8 + o.x, 4 + o.y, 9, 1, pal.light)  # siper
	var rows := [[10, 5], [10, 4], [11, 3], [11, 2], [12, 1]]
	for i in rows.size():
		_rect(img, rows[i][0] + o.x, 3 - i + o.y, rows[i][1], 1, pal.light)
	_rect(img, 10 + o.x, 3 + o.y, 5, 1, pal.dark)  # bant


## Asa ve küre. fx: 1 kalkar, 2 küre büyür, 3 parlar, 4 iner.
static func _staff(img: Image, o: Vector2i, fx: int, pal: Dictionary) -> void:
	var lift := 3 if fx == 1 or fx == 2 or fx == 3 else 0
	var x := 18 + o.x
	var top := 4 - lift + o.y
	_line(img, Vector2i(x, top), Vector2i(x, 21 - lift), WOOD)
	_arm(img, o, Vector2i(x - 1, 12 - lift + o.y), pal)
	var radius := 1 if fx < 2 or fx == 4 else 2
	var glow: Color = pal.glow
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if absi(dx) + absi(dy) <= radius + 1:
				_px(img, x + dx, top - 1 + dy, glow)
	_px(img, x, top - 1, Color.WHITE)
	if fx == 3:  # büyü anı: ışık saçar
		for d in [Vector2i(-4, 0), Vector2i(4, 0), Vector2i(0, -4), Vector2i(3, -3), Vector2i(-3, -3), Vector2i(3, 3)]:
			_px(img, x + d.x, top - 1 + d.y, Color.WHITE)


## Süvari: birliğin koyu renginde binek (at, kurt, geyik, kentaur gövdesi) ve binici.
static func _cavalry(img: Image, p: Dictionary, pal: Dictionary) -> void:
	var mount: Color = pal.mount
	var hoof := mount.darkened(0.5)
	var bob: int = p.bob
	# bacaklar: ön çift ve arka çift ters evrede açılıp kapanır
	var swing: int = [0, 1, 0, -1][int(p.legs)] if int(p.legs) > 0 else 0
	for leg in [[6, -1], [8, 1], [14, 1], [16, -1]]:
		var x: int = leg[0]
		var s: int = swing * leg[1]
		_rect(img, x, 17, 2, 2, mount.darkened(0.15))
		_rect(img, x + s, 19, 2, 2, mount.darkened(0.15))
		_rect(img, x + s, 21, 2, 1, hoof)
	_rect(img, 5, 12 + bob, 12, 5, mount)  # gövde
	_rect(img, 5, 16 + bob, 12, 1, mount.darkened(0.2))  # karın gölgesi
	_rect(img, 6, 12 + bob, 10, 1, mount.lightened(0.15))
	_rect(img, 16, 8 + bob, 3, 5, mount)  # boyun
	_rect(img, 18, 6 + bob, 5, 3, mount)  # baş
	_px(img, 22, 8 + bob, hoof)  # burun
	_px(img, 18, 5 + bob, mount)  # kulak
	_px(img, 20, 7 + bob, OUTLINE)  # göz
	_line(img, Vector2i(16, 8 + bob), Vector2i(16, 12 + bob), mount.darkened(0.3))  # yele
	for t in [[4, 12], [3, 13], [3, 14], [4, 15]]:  # kuyruk
		_px(img, t[0], t[1] + bob, mount.darkened(0.3))
	_rect(img, 8, 11 + bob, 6, 3, pal.body)  # eyer örtüsü
	_rect(img, 8, 13 + bob, 6, 1, GOLD)
	# binici
	var o := Vector2i(p.lean, bob)
	_rect(img, 9 + o.x, 5 + o.y, 5, 6, pal.body)
	_rect(img, 9 + o.x, 5 + o.y, 1, 6, pal.dark)
	_rect(img, 10 + o.x, 5 + o.y, 3, 1, pal.light)
	_rect(img, 10 + o.x, 1 + o.y, 4, 4, pal.skin)
	_rect(img, 10 + o.x, 0 + o.y, 4, 2, METAL)
	_px(img, 12 + o.x, 2 + o.y, OUTLINE)
	_shaft(img, p.hand + o, p.angle, 4, 14, WOOD)
	_tip(img, p.hand + o, p.angle, 14, 2)
	_arm(img, Vector2i(-1, -5) + o, p.hand + o, pal)


## Kuşatma topu: tekerlekler, kundak, kalın namlu, krallık sancağı. Ateşte namlu geri teper.
static func _cannon(img: Image, p: Dictionary, pal: Dictionary) -> void:
	var r: int = p.recoil
	_line(img, Vector2i(4, 5), Vector2i(4, 16), WOOD)  # sancak direği
	_rect(img, 5, 5, 4, 3, pal.body)
	_rect(img, 5, 7, 4, 1, pal.dark)
	_rect(img, 6, 15, 13, 2, WOOD)  # kundak
	_rect(img, 3, 17, 4, 1, WOOD)
	for i in 3:  # kalın namlu (üç çizgi)
		_line(img, Vector2i(7 + r, 13 + i), Vector2i(19 + r, 10 + i), METAL_DARK if i > 0 else METAL)
	_rect(img, 19 + r, 9, 2, 5, METAL_DARK)  # namlu ağzı
	_px(img, 20 + r, 9, METAL)
	for wx in [9, 16]:  # tekerlekler, yürürken parmaklıkları döner
		var c := Vector2(wx, 18)
		for y in range(15, 22):
			for x in range(wx - 3, wx + 4):
				var d := Vector2(x, y).distance_to(c)
				if d >= 2.3 and d <= 3.4:
					_px(img, x, y, WOOD.darkened(0.3))
		var a := deg_to_rad(45.0 * int(p.wheel))
		var spoke := Vector2.from_angle(a) * 2.0
		_line(img, _v(c - spoke), _v(c + spoke), WOOD)
		_px(img, wx, 18, METAL)
	match int(p.fx):
		2:  # ateş
			_rect(img, 21 + r, 9, 3, 5, FLASH)
			_rect(img, 22 + r, 10, 2, 3, Color.WHITE)
		3, 4:  # duman
			var fade := 0 if int(p.fx) == 3 else 1
			for s in [Vector2i(21, 10), Vector2i(22, 7), Vector2i(20, 6)]:
				_rect(img, s.x - fade, s.y - fade, 2 + fade, 2, SMOKE)


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


## Ayakların ortası etrafında geriye (sola) devirir; yatarken kare içinde kalsın diye sağa kaydırır.
static func _rotated(src: Image, degrees: float) -> Image:
	var out := _canvas()
	var theta := deg_to_rad(degrees)
	var pivot := Vector2(12, 21)
	var shift := Vector2(9.0 * degrees / 90.0, 0)
	var cos_t := cos(theta)
	var sin_t := sin(theta)
	for y in SIZE:
		for x in SIZE:
			# Hedef pikselden kaynağa geri dönülür (ters döndürme): sonuçta delik kalmaz.
			# Ekranda y aşağı baktığı için bu dönüş baş tarafı sola (geriye) yatırır.
			var d := Vector2(x, y) - pivot - shift
			var s := Vector2(d.x * cos_t - d.y * sin_t, d.x * sin_t + d.y * cos_t) + pivot
			var sx := roundi(s.x)
			var sy := roundi(s.y)
			if sx >= 0 and sy >= 0 and sx < SIZE and sy < SIZE:
				var c := src.get_pixel(sx, sy)
				if c.a > 0.0:
					out.set_pixel(x, y, c)
	return out


## Saydam olup dolu bir komşusu olan her piksel kenar çizgisi olur.
static func _outline(img: Image) -> void:
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
					img.set_pixel(x, y, OUTLINE)
					break


static func _silhouette(image: Image) -> Image:
	var out := image.duplicate() as Image
	for y in out.get_height():
		for x in out.get_width():
			var a := out.get_pixel(x, y).a
			if a > 0.0:
				out.set_pixel(x, y, Color(1, 1, 1, a))
	return out


static func _v(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.y))


## Bresenham çizgisi.
static func _line(img: Image, a: Vector2i, b: Vector2i, color: Color) -> void:
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var p := a
	while true:
		_px(img, p.x, p.y, color)
		if p == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy


static func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	var r := Rect2i(x, y, w, h).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.has_area():
		img.fill_rect(r, color)


static func _px(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, color)
