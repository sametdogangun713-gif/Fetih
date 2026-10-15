class_name MiniUnitArt
## Minik birlik sanatı (9 Kings tarzı): her asker 16x16 hücrede 10-12 piksel boyunda, rolüne
## göre tek bakışta ayırt edilen bir siluet. Gövde takım renginde (oyuncu altın, rakip kırmızı),
## silah/şapka vurgusu birliğin placeholder_color'ı. Sayfa biçimi UnitSprites ile aynı:
## 4 satır (durma 2, yürüme 4, saldırı 3, ölüm 4 kare), figür sağa bakar, ayak ortası (8, 14).
## Her kare Image.set_pixel / fill_rect ile elle çizilir, sonra 1 px koyu çerçeve eklenir ve sayfa
## Resurrect 64 paletine indirilir.

const CELL := 16
const FRAMES: Array[int] = [2, 4, 3, 4]  ## durma, yürüme, saldırı, ölüm
const FOOT := Vector2i(8, 14)

const OUTLINE := Color("2e222f")
const SKIN := Color("fca790")
const METAL := Color("c7dcd0")
const WOOD := Color("966c6c")
const SPEAR_SHAFT := Color("ab947a")
const DARK_WOOD := Color("4c3e24")
const IRON := Color("625565")
const IRON_LIGHT := Color("7f708a")
const HORSE_DARK := Color("694f62")
const PANTS := Color("3e3546")
const GLOW := Color("8fd3ff")
const SPARK := Color("fbff86")
const FIRE := Color("f79617")
const STONE_DARK := Color("625565")
const STONE := Color("7f708a")
const STONE_LIGHT := Color("9babb2")
const MUD := Color("4c3e24")
const BONE := Color("fdcbb0")
const GINGER := Color("cd683d")
const BLONDE := Color("fbb954")
const PLUME := Color("905ea9")
const EMBER := Color("f79617")
const TEAL := Color("30e1b9")
## Krallığa göre ten rengi (listede yoksa SKIN).
const SKINS := {
	&"orcs": Color("a2a947"), &"undead": Color("c7dcd0"), &"golems": Color("9babb2"),
	&"demons": Color("b33831"), &"mud": Color("ab947a"), &"elves": Color("fdcbb0"),
	&"dwarves": Color("e6904e"), &"slimes": Color("cddf6c"), &"centaurs": Color("cd683d"),
}
## Krallığa göre metal tonu (miğfer, silah ucu); listede yoksa METAL.
const METALS := {
	&"orcs": Color("7f708a"), &"dwarves": Color("9babb2"), &"undead": Color("9babb2"),
	&"golems": STONE, &"demons": Color("625565"), &"slimes": Color("91db69"),
	&"elves": Color("cddf6c"), &"mud": Color("966c6c"),
}
## Binek renkleri: [gövde, koyu taraf]. Listede yoksa WOOD / HORSE_DARK (at).
const MOUNTS := {
	&"elves": [Color("e6904e"), Color("9e4539")], &"orcs": [Color("7f708a"), Color("625565")],
	&"undead": [Color("c7dcd0"), Color("7f708a")], &"demons": [Color("6e2727"), Color("3e3546")],
	&"centaurs": [Color("9e4539"), Color("7a3045")], &"slimes": [Color("1ebc73"), Color("239063")],
}

enum Kind { HUMANOID, RIDER, CANNON, CATAPULT }


## Birliğin sprite sayfası: CELL * 4 yüksekliğinde, en geniş satır kadar sütun.
static func sheet(unit: UnitData, team_color: Color) -> Image:
	var c := _colors(unit, team_color)
	var kind := kind_of(unit)
	var columns: int = FRAMES.max()
	var out := Image.create_empty(CELL * columns, CELL * FRAMES.size(), false, Image.FORMAT_RGBA8)
	for anim in FRAMES.size():
		for f in FRAMES[anim]:
			var img := _frame(kind, unit.role, c, anim, f)
			_outline(img)
			out.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(f * CELL, anim * CELL))
	SpritePalette.quantize(out)
	return out


static func kind_of(unit: UnitData) -> Kind:
	if unit.role == RoleRules.CAVALRY:
		return Kind.RIDER
	if unit.role == RoleRules.SIEGE:
		return Kind.CATAPULT if unit.kingdom == &"golems" else Kind.CANNON
	return Kind.HUMANOID


static func _colors(unit: UnitData, team_color: Color) -> Dictionary:
	var main := SpritePalette.nearest(team_color)
	var shade := SpritePalette.nearest_step(main, main, false)
	var mount: Array = MOUNTS.get(unit.kingdom, [WOOD, HORSE_DARK])
	return {
		main = main,
		shade = shade,
		deep = SpritePalette.nearest_step(shade, shade, false),
		accent = SpritePalette.nearest(unit.placeholder_color),
		skin = SKINS.get(unit.kingdom, SKIN),
		metal = METALS.get(unit.kingdom, METAL),
		kingdom = unit.kingdom,
		mount = mount[0],
		mount_dark = mount[1],
	}


static func _frame(kind: Kind, role: StringName, c: Dictionary, anim: int, f: int) -> Image:
	var im := Image.create_empty(CELL, CELL, false, Image.FORMAT_RGBA8)
	match kind:
		Kind.RIDER:
			_rider(im, c, anim, f)
		Kind.CANNON:
			_cannon(im, c, anim, f)
		Kind.CATAPULT:
			_catapult(im, c, anim, f)
		_:
			_humanoid(im, role, c, anim, f)
	return im


# --- Yardımcılar ---

static func _px(im: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < CELL and y < CELL:
		im.set_pixel(x, y, col)


static func _rect(im: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	var r := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, CELL, CELL))
	if r.has_area():
		im.fill_rect(r, col)


## Dolu piksellerin boş 4-komşularına 1 px koyu çerçeve.
static func _outline(im: Image) -> void:
	var src := im.duplicate() as Image
	for y in CELL:
		for x in CELL:
			if src.get_pixel(x, y).a > 0.0:
				continue
			if (x > 0 and src.get_pixel(x - 1, y).a > 0.0) or (x < CELL - 1 and src.get_pixel(x + 1, y).a > 0.0) \
					or (y > 0 and src.get_pixel(x, y - 1).a > 0.0) or (y < CELL - 1 and src.get_pixel(x, y + 1).a > 0.0):
				im.set_pixel(x, y, OUTLINE)


# --- İnsansı roller ---

## Piyade, mızrakçı, okçu, büyücü, tank. Vücut parçaları (bacak, gövde, baş) ortak; rol silahı ve
## başlığı farklı. dy/ox = üst gövdenin kayması (nefes, adım, atılma).
static func _humanoid(im: Image, role: StringName, c: Dictionary, anim: int, f: int) -> void:
	var dy := 0
	var ox := 0
	var lift_a := false
	var lift_b := false
	var leg_a := 6
	var leg_b := 9
	var swing := f  # saldırı karesi: 0 hazırlık, 1 vuruş, 2 toparlanma
	match anim:
		UnitSprites.Anim.IDLE:
			dy = f
		UnitSprites.Anim.WALK:
			dy = -1 if f % 2 == 1 else 0
			lift_a = f == 2
			lift_b = f == 0
			if f % 2 == 1:
				leg_a = 7
				leg_b = 8
		UnitSprites.Anim.ATTACK:
			ox = [-1, 1, 0][f]
		UnitSprites.Anim.DEATH:
			_humanoid_death(im, role, c, f)
			return
	var main: Color = c.main
	var shade: Color = c.shade
	var accent: Color = c.accent
	var metal: Color = c.metal
	var tank := role == RoleRules.TANK
	var kingdom: StringName = c.kingdom
	var golem := kingdom == &"golems"
	var centaur := kingdom == &"centaurs"
	var wide := 1 if (tank or golem) else 0
	var pants := PANTS
	if golem:
		pants = STONE_DARK
	elif kingdom == &"mud":
		pants = MUD
	elif kingdom == &"slimes":
		pants = Color("239063")
	# bacaklar (kentaurda at gövdesinin alt yarısı)
	if centaur:
		_centaur_lower(im, c, ox, anim, f)
	else:
		for leg in [[leg_a, lift_a], [leg_b, lift_b]]:
			_rect(im, leg[0] - wide, 13 if leg[1] else 12, 1 + wide, 1 if leg[1] else 2, pants)
	if role == RoleRules.MAGE:  # cüppe ayakları örter
		_rect(im, 5 + ox, 11, 6, 3, shade)
		_rect(im, 6 + ox, 11, 4, 3, main)
	# gövde
	var top := 7 + dy
	var bw := 6 if tank else (5 if golem else 4)
	var bx := 5 + ox if (tank or golem) else 6 + ox
	_rect(im, bx, top, bw, 12 - top, main)
	_rect(im, bx, top, 1, 12 - top, shade)  # arka kenar gölgede
	_rect(im, bx, 11, bw, 1, shade)  # kemer
	_body_extras(im, c, role, bx, bw, top)
	# baş
	var hx := 6 + ox
	var hy := 4 + dy
	match role:
		RoleRules.ARCHER:
			_rect(im, hx, hy, 4, 3, accent)
			_rect(im, hx + 2, hy + 1, 2, 2, c.skin)
			_px(im, hx + 3, hy + 1, OUTLINE)
			_px(im, hx - 1, hy + 1, accent)  # kukuleta ucu
		RoleRules.MAGE:
			_px(im, hx + 2, hy - 1, accent)  # sivri uç
			_rect(im, hx + 1, hy, 3, 1, accent)  # şapka gövdesi
			_rect(im, hx - 1, hy + 1, 6, 1, accent)  # şapka kenarı
			_rect(im, hx + 1, hy + 2, 3, 1, c.skin)
			_px(im, hx + 3, hy + 2, OUTLINE)
		RoleRules.TANK:
			_rect(im, hx - 1, hy, 6, 3, metal)
			_rect(im, hx + 2, hy + 1, 3, 1, OUTLINE)  # vizör
			_px(im, hx + 1, hy - 1, accent)  # tepelik
			_px(im, hx + 2, hy - 1, accent)
		_:  # piyade, mızrakçı: yuvarlak kask (mızrakçının tepesi vurgu renginde)
			_rect(im, hx, hy, 4, 2, metal)
			if role == RoleRules.SPEARMAN:
				_rect(im, hx, hy, 4, 1, accent)
			_px(im, hx, hy + 2, metal)
			_rect(im, hx + 1, hy + 2, 3, 1, c.skin)
			_rect(im, hx + 2, hy + 1, 2, 1, c.skin)
			_px(im, hx + 3, hy + 1, OUTLINE)
	_head_extras(im, c, role, hx, hy)
	var hand_y := 8 + dy
	match role:
		RoleRules.WARRIOR:
			_rect(im, 4 + ox, 8 + dy, 2, 3, accent)  # kalkan
			_px(im, 4 + ox, 9 + dy, shade)
			_px(im, 10 + ox, hand_y, c.skin)
			match swing if anim == UnitSprites.Anim.ATTACK else -1:
				0:  # kılıç yukarıda, geriye
					_rect(im, 10 + ox, 2 + dy, 1, 5, metal)
					_px(im, 10 + ox, 7 + dy, WOOD)
				1:  # ileri kesiş
					_rect(im, 11 + ox, hand_y, 4, 1, metal)
					_px(im, 10 + ox, hand_y, WOOD)
				2:  # aşağı
					_rect(im, 11 + ox, 8 + dy, 1, 4, metal)
					_px(im, 11 + ox, 7 + dy, WOOD)
				_:
					_rect(im, 11 + ox, 4 + dy, 1, 4, metal)
					_px(im, 11 + ox, 8 + dy, WOOD)
		RoleRules.SPEARMAN:
			_px(im, 10 + ox, hand_y, c.skin)
			if anim == UnitSprites.Anim.ATTACK and swing == 1:  # ileri saplama
				_rect(im, 7 + ox, hand_y, 6, 1, SPEAR_SHAFT)
				_rect(im, 13 + ox, hand_y, 2, 1, metal)
			elif anim == UnitSprites.Anim.ATTACK and swing == 0:  # geri çekiş
				_rect(im, 6 + ox, hand_y, 6, 1, SPEAR_SHAFT)
				_rect(im, 12 + ox, hand_y, 2, 1, metal)
			else:
				_rect(im, 11 + ox, 5 + dy, 1, 8 - dy, SPEAR_SHAFT)
				_rect(im, 11 + ox, 3 + dy, 1, 2, metal)
		RoleRules.ARCHER:
			var draw := anim == UnitSprites.Anim.ATTACK and swing == 0
			var bow_x := (13 if draw else 12) + ox
			_px(im, bow_x - 1, 5 + dy, WOOD)
			_rect(im, bow_x, 6 + dy, 1, 5, WOOD)
			_px(im, bow_x - 1, 11 + dy, WOOD)
			if not draw:
				_rect(im, bow_x - 1, 6 + dy, 1, 5, metal)  # kiriş
			_rect(im, 10 + ox, hand_y, 2 if not draw else 1, 1, c.skin)
			if draw:  # ok kirişte
				_rect(im, 9 + ox, hand_y, 5, 1, metal)
				_px(im, 14 + ox, hand_y, metal)
			elif anim == UnitSprites.Anim.ATTACK and swing == 1:  # ok uçtu
				_rect(im, 13, hand_y, 2, 1, metal)
			_rect(im, 5 + ox, 6 + dy, 1, 3, accent)  # sadak
		RoleRules.MAGE:
			var orb_dy := -1 if (anim == UnitSprites.Anim.ATTACK and swing == 0) else 0
			_px(im, 10 + ox, hand_y, c.skin)
			_rect(im, 11 + ox, 5 + dy, 1, 8 - dy, WOOD)
			var orb := GLOW
			if anim == UnitSprites.Anim.ATTACK and swing == 1:  # büyü patlar
				_rect(im, 10 + ox, 2 + dy + orb_dy, 3, 3, SPARK)
				_px(im, 11 + ox, 3 + dy, Color.WHITE)
			else:
				_rect(im, 11 + ox, 3 + dy + orb_dy, 2, 2, orb)
				_px(im, 11 + ox, 3 + dy + orb_dy, Color.WHITE)
		RoleRules.TANK:
			var push := 1 if (anim == UnitSprites.Anim.ATTACK and swing == 1) else 0
			var back := -1 if (anim == UnitSprites.Anim.ATTACK and swing == 0) else 0
			_rect(im, 11 + push + back + ox, 6 + dy, 3, 6, main)
			_rect(im, 11 + push + back + ox, 6 + dy, 1, 6, shade)
			_rect(im, 12 + push + back + ox, 8 + dy, 1, 2, accent)  # kalkan göbeği
			_px(im, 10 + ox, hand_y, c.skin)


# --- Krallık ayrıntıları ---
# Her krallık aynı rol siluetine 1-3 piksellik ayırt edici işaret ekler (sorguç, kulak, diş, sakal...).

## Kentaur: insan gövdesi ata oturmaz, at gövdesinin üstünden çıkar (arka yarı solda).
static func _centaur_lower(im: Image, c: Dictionary, ox: int, anim: int, f: int) -> void:
	var gather := anim == UnitSprites.Anim.WALK and f % 2 == 1
	var lift_a := anim == UnitSprites.Anim.WALK and f == 2
	var lift_b := anim == UnitSprites.Anim.WALK and f == 0
	var mount: Color = c.mount
	var dark: Color = c.mount_dark
	# [x, koyu mu (uzak taraf), kalkık mı]
	var legs := [[3 + (1 if gather else 0), false, lift_a], [5 + (1 if gather else 0), true, lift_b],
			[8 - (1 if gather else 0), true, lift_a], [10 - (1 if gather else 0), false, lift_b]]
	for leg in legs:
		_rect(im, leg[0] + ox, 13 if leg[2] else 12, 1, 1 if leg[2] else 2, dark if leg[1] else mount)
	_rect(im, 3 + ox, 10, 8, 2, mount)
	_rect(im, 3 + ox, 11, 8, 1, dark)
	_px(im, 2 + ox, 10, dark)  # kuyruk
	_px(im, 2 + ox, 11, dark)


## Gövdeye bağlı ayrıntılar: golem taş kol ve çatlak, balçık akıntısı, jöle yuvarlaklığı, iblis kuyruğu.
static func _body_extras(im: Image, c: Dictionary, role: StringName, bx: int, bw: int, top: int) -> void:
	var shade: Color = c.shade
	match c.kingdom:
		&"golems":
			# iç gölge: sol sütun gölge, sağ sütun ve kemer koyu; takım rengi ortada net kalır
			_rect(im, bx + bw - 1, top, 1, 12 - top, c.deep)
			_rect(im, bx, 11, bw, 1, c.deep)
			_px(im, bx + 2, top + 1, shade)  # çatlaklar
			_px(im, bx + 1, top + 2, shade)
			_px(im, bx, top, STONE_LIGHT)  # taş omuzlar
			_px(im, bx + bw - 1, top, STONE)
			_rect(im, bx - 1, top + 1, 1, 3, STONE_DARK)  # taş kol
		&"mud":
			_px(im, bx + 1, top + 2, MUD)  # akan çamur
			_px(im, bx + 1, top + 3, MUD)
			_px(im, bx + bw - 2, top + 3, MUD)
			_px(im, bx + 1, 11, MUD)
			_px(im, bx + bw - 2, 11, MUD)
		&"slimes":
			var clear := Color(0, 0, 0, 0)
			im.set_pixel(bx, top, clear)  # yuvarlak üst köşeler
			im.set_pixel(bx + bw - 1, top, clear)
			_rect(im, bx - 1, 10, bw + 2, 2, c.main)  # damla tabanı geniş
			_rect(im, bx - 1, 11, bw + 2, 1, shade)
			_px(im, bx, 10, shade)
			_px(im, bx + 1, top + 1, Color.WHITE)  # jöle parıltısı
		&"demons":
			_px(im, bx - 1, 10, c.skin)  # kuyruk
			_px(im, bx - 2, 10, c.skin)
			_px(im, bx - 2, 9, c.skin)


## Baş ayrıntıları (kafa konumu hx, hy). Yüz satırı: büyücüde hy + 2, diğerlerinde hy + 1.
static func _head_extras(im: Image, c: Dictionary, role: StringName, hx: int, hy: int) -> void:
	var mage := role == RoleRules.MAGE
	var archer := role == RoleRules.ARCHER
	var tank := role == RoleRules.TANK
	var eye_y := hy + 2 if mage else hy + 1
	match c.kingdom:
		&"humans":  # sorguçlu miğfer
			if not mage and not tank:
				_px(im, hx, hy - 1, PLUME)
				_px(im, hx + 1, hy - 1, PLUME)
				if not archer:
					_px(im, hx - 1, hy, PLUME)
		&"elves":  # sivri kulak, uzun açık saç
			if not (archer or mage):
				_px(im, hx - 1, hy + 1, c.skin)
				_px(im, hx - 2, hy, c.skin)
			elif mage:
				_px(im, hx - 2, hy + 1, c.skin)
			_rect(im, hx - 1, hy + 2, 1, 3, BLONDE)
		&"orcs":  # öne çıkan beyaz diş
			_px(im, hx + 4, hy + 2, Color.WHITE)
		&"dwarves":  # gür sakal
			var by := hy + 3 if (mage or tank) else hy + 2
			_rect(im, hx + 1, by, 4 if tank else 3, 2 if not (mage or tank) else 1, GINGER)
			_px(im, hx + 2, by + 2 if not (mage or tank) else by + 1, GINGER)
		&"undead":  # kafatası: kara göz çukuru, parlayan göz, diş aralığı
			if not tank:
				_px(im, hx + 2, eye_y, OUTLINE)
				_px(im, hx + 3, eye_y, TEAL)
				if not mage:
					_px(im, hx + 2, hy + 2, OUTLINE)
		&"demons":  # küçük boynuzlar
			if tank:
				_px(im, hx - 1, hy - 1, BONE)
				_px(im, hx + 4, hy - 1, BONE)
			elif mage:
				_px(im, hx, hy, BONE)
				_px(im, hx + 4, hy, BONE)
			else:
				_px(im, hx, hy - 1, BONE)
				_px(im, hx + 3, hy - 1, BONE)
		&"golems":  # taş kafa: ışık, çatlak, kor göz
			if not (tank):
				_px(im, hx + 3, eye_y, c.accent if mage else EMBER)
				if not (mage or archer):
					_px(im, hx + 1, hy, STONE_LIGHT)
					_px(im, hx + 1, hy + 1, STONE_DARK)
			else:
				_px(im, hx + 3, hy + 1, EMBER)
		&"slimes":  # jöle kafa parıltısı
			if not (mage or archer):
				_px(im, hx + 1, hy, Color.WHITE)


## Ölüm: kısa sarsıntı, devrilme, yerde yatan 8x3 beden (son iki kare).
static func _humanoid_death(im: Image, role: StringName, c: Dictionary, f: int) -> void:
	var main: Color = c.main
	var shade: Color = c.shade
	var metal: Color = c.metal
	var head: Color = c.accent if role == RoleRules.ARCHER or role == RoleRules.MAGE else metal
	match f:
		0:  # sendeler
			_rect(im, 6, 12, 1, 2, PANTS)
			_rect(im, 8, 12, 1, 2, PANTS)
			_rect(im, 5, 8, 4, 4, main)
			_rect(im, 5, 8, 1, 4, shade)
			_rect(im, 4, 5, 4, 2, head)
			_rect(im, 5, 7, 3, 1, c.skin)
		1:  # yana yatıyor
			_rect(im, 9, 12, 2, 2, PANTS)
			_rect(im, 5, 10, 4, 3, main)
			_rect(im, 5, 12, 4, 1, shade)
			_rect(im, 3, 9, 3, 3, head)
			_px(im, 4, 11, c.skin)
		_:  # yerde: baş solda, bacaklar sağda
			_rect(im, 10, 12, 2, 2, PANTS)
			_rect(im, 6, 11, 4, 3, main)
			_rect(im, 6, 13, 4, 1, shade)
			_rect(im, 4, 11, 2, 3, head)
			_px(im, 5, 12, c.skin)
			if f == 3:  # silah yere düştü
				var weapon: Color = metal
				if role == RoleRules.ARCHER:
					weapon = WOOD
				_rect(im, 12, 13, 2, 1, weapon)
				_px(im, 12, 12, c.accent)


# --- Atlı ---

static func _rider(im: Image, c: Dictionary, anim: int, f: int) -> void:
	var main: Color = c.main
	var shade: Color = c.shade
	var accent: Color = c.accent
	var metal: Color = c.metal
	var bob := 0
	var ox := 0
	var head_up := 0
	var near_front := 10
	var near_back := 4
	var far_front := 9
	var far_back := 5
	var near_lift := false
	match anim:
		UnitSprites.Anim.IDLE:
			bob = f
		UnitSprites.Anim.WALK:
			bob = -1 if f % 2 == 1 else 0
			near_lift = f % 2 == 0
			if f % 2 == 1:  # dörtnala toplanma: bacaklar altta birleşir
				near_front = 9
				near_back = 5
		UnitSprites.Anim.ATTACK:
			ox = [-1, 1, 0][f]
			head_up = 1 if f == 0 else 0
		UnitSprites.Anim.DEATH:
			_rider_death(im, c, f)
			return
	var body_y := 8 + bob
	# bacaklar (uzak tarafta olanlar koyu)
	for leg in [[far_back, true], [far_front, true], [near_back, false], [near_front, false]]:
		var lifted: bool = near_lift and not leg[1]
		var length := 1 if lifted else 3 - bob
		_rect(im, leg[0] + ox, 14 - length if length > 0 else 13, 1, maxi(length, 1), c.mount_dark if leg[1] else c.mount)
	# gövde, boyun, baş, kuyruk
	_rect(im, 3 + ox, body_y, 8, 3, c.mount)
	_rect(im, 3 + ox, body_y + 2, 8, 1, c.mount_dark)
	_rect(im, 10 + ox, 6 + bob - head_up, 2, 3, c.mount)
	_rect(im, 11 + ox, 5 + bob - head_up, 2, 2, c.mount)
	_px(im, 12 + ox, 7 + bob - head_up, c.mount)
	_px(im, 12 + ox, 5 + bob - head_up, OUTLINE)  # göz
	_px(im, 10 + ox, 5 + bob - head_up, c.mount_dark)  # yele
	_rect(im, 2 + ox, body_y, 1, 3, c.mount_dark)
	_px(im, 2 + ox, body_y + 3, c.mount_dark)
	# eyer örtüsü (vurgu rengi)
	_rect(im, 5 + ox, body_y, 4, 1, accent)
	# binici
	_rect(im, 6 + ox, 5 + bob, 3, 3, main)
	_rect(im, 6 + ox, 5 + bob, 1, 3, shade)
	_rect(im, 6 + ox, 3 + bob, 3, 2, metal)
	_px(im, 8 + ox, 4 + bob, c.skin)
	_px(im, 7 + ox, 3 + bob, accent)  # tepelik
	_rider_extras(im, c, ox, bob, head_up)
	# mızrak
	if anim == UnitSprites.Anim.ATTACK:
		if f == 1:
			_rect(im, 8 + ox, 6, 7, 1, WOOD)
			_rect(im, 14 + ox, 6, 2, 1, metal)
		elif f == 0:
			_rect(im, 6 + ox, 6, 7, 1, WOOD)
	else:
		_rect(im, 9 + ox, 4 + bob, 1, 4, WOOD)
		_px(im, 9 + ox, 3 + bob, metal)


## Atlı ayrıntıları: binici başı ve binek (geyik boynuzu, kurt kulağı, iskelet göz, jöle parıltısı).
static func _rider_extras(im: Image, c: Dictionary, ox: int, bob: int, head_up: int) -> void:
	var head_y := 5 + bob - head_up  # at başı üst satırı
	match c.kingdom:
		&"humans":
			_px(im, 6 + ox, 3 + bob, PLUME)
		&"elves":
			_px(im, 5 + ox, 4 + bob, BLONDE)
			_px(im, 5 + ox, 5 + bob, BLONDE)
			_px(im, 11 + ox, head_y - 1, BONE)  # geyik boynuzu
			_px(im, 12 + ox, head_y - 2, BONE)
		&"orcs":
			_px(im, 6 + ox, 3 + bob, Color.WHITE)
			_px(im, 8 + ox, 3 + bob, Color.WHITE)
			_px(im, 11 + ox, head_y - 1, c.mount_dark)  # kurt kulağı
		&"undead":
			_px(im, 8 + ox, 4 + bob, TEAL)
			_px(im, 12 + ox, head_y, TEAL)
		&"demons":
			_rect(im, 6 + ox, 3 + bob, 3, 2, c.skin)
			_px(im, 6 + ox, 3 + bob, BONE)
			_px(im, 8 + ox, 3 + bob, BONE)
			_px(im, 7 + ox, 3 + bob, c.accent)
			_px(im, 10 + ox, head_y, EMBER)  # köpek yelesi
		&"centaurs":
			_px(im, 5 + ox, 4 + bob, MUD)  # örgü
			_px(im, 5 + ox, 5 + bob, MUD)
		&"slimes":
			_px(im, 4 + ox, 8 + bob, Color.WHITE)


static func _rider_death(im: Image, c: Dictionary, f: int) -> void:
	var main: Color = c.main
	var metal: Color = c.metal
	match f:
		0:  # at sendeler
			_rect(im, 4, 12, 1, 2, c.mount)
			_rect(im, 9, 12, 1, 2, c.mount)
			_rect(im, 3, 9, 8, 3, c.mount)
			_rect(im, 11, 6, 2, 3, c.mount)
			_rect(im, 5, 6, 3, 3, main)
			_rect(im, 4, 4, 3, 2, metal)
		1:  # çöküyor
			_rect(im, 3, 11, 8, 3, c.mount)
			_rect(im, 11, 9, 2, 3, c.mount)
			_rect(im, 3, 13, 8, 1, c.mount_dark)
			_rect(im, 4, 8, 3, 3, main)
			_rect(im, 2, 8, 2, 2, metal)
		_:  # yerde yatan at ve binici
			_rect(im, 3, 11, 9, 3, c.mount)
			_rect(im, 3, 13, 9, 1, c.mount_dark)
			_rect(im, 11, 12, 2, 2, c.mount)
			_rect(im, 5, 9, 3, 2, main)
			_rect(im, 4, 9, 1, 2, metal)
			if f == 3:
				_px(im, 9, 10, c.accent)
				_rect(im, 10, 10, 3, 1, WOOD)


# --- Kuşatma ---

## Top: iki tekerlek, takım renginde top arabası, demir namlu. Mürettebat yok.
static func _cannon(im: Image, c: Dictionary, anim: int, f: int) -> void:
	var main: Color = c.main
	var shade: Color = c.shade
	var recoil := 0
	var dy := 0
	var flash := false
	var smoke := false
	if anim == UnitSprites.Anim.ATTACK:
		recoil = [0, -1, 0][f]
		flash = f == 1
		smoke = f == 2
	if anim == UnitSprites.Anim.DEATH:
		_cannon_death(im, c, f)
		return
	if anim == UnitSprites.Anim.WALK:
		dy = -1 if f % 2 == 1 else 0
	# tekerlekler (dönüş: parmak çizgisi yürümede değişir)
	for wx in [3, 9]:
		_rect(im, wx + 1, 11, 2, 1, DARK_WOOD)
		_rect(im, wx, 12, 4, 1, DARK_WOOD)
		_rect(im, wx + 1, 13, 2, 1, DARK_WOOD)
		_px(im, wx + 1 + (f % 2 if anim == UnitSprites.Anim.WALK else 0), 12, WOOD)
	# top arabası ve namlu
	_rect(im, 4, 10 + dy, 8, 1, main)
	_rect(im, 3 + recoil, 7 + dy, 8, 3, IRON)
	_rect(im, 3 + recoil, 7 + dy, 8, 1, IRON_LIGHT)
	_rect(im, 10 + recoil, 6 + dy, 2, 5, IRON)  # ağız halkası
	_rect(im, 10 + recoil, 6 + dy, 2, 1, IRON_LIGHT)
	_rect(im, 5 + recoil, 7 + dy, 2, 3, main)  # takım bandı
	_rect(im, 5 + recoil, 9 + dy, 2, 1, shade)
	_px(im, 2 + recoil, 8 + dy, c.accent)  # kabza topuzu
	_px(im, 2 + recoil, 9 + dy, IRON)
	if flash:
		_rect(im, 12, 6, 2, 4, FIRE)
		_rect(im, 12, 7, 3, 2, SPARK)
	elif smoke:
		_rect(im, 12, 5, 2, 2, METAL)
		_px(im, 13, 4, METAL)


static func _cannon_death(im: Image, c: Dictionary, f: int) -> void:
	match f:
		0:  # sarsılır
			_rect(im, 4, 12, 4, 2, DARK_WOOD)
			_rect(im, 3, 8, 8, 3, IRON)
			_rect(im, 10, 7, 2, 5, IRON)
			_rect(im, 5, 8, 2, 3, c.main)
		1:  # namlu düşüyor
			_rect(im, 3, 12, 4, 2, DARK_WOOD)
			_rect(im, 5, 10, 8, 3, IRON)
			_rect(im, 11, 9, 2, 4, IRON)
			_rect(im, 7, 10, 2, 3, c.main)
		_:  # devrik namlu, kopmuş tekerlek
			_rect(im, 3, 12, 8, 2, IRON)
			_rect(im, 3, 12, 8, 1, IRON_LIGHT)
			_rect(im, 6, 12, 2, 2, c.main)
			_rect(im, 11, 11, 2, 3, DARK_WOOD)
			_px(im, 12, 12, WOOD)
			_rect(im, 1, 13, 2, 1, DARK_WOOD)


## Mancınık (golem): takım renginde kiriş, iki tekerlek, bir kol ve vurgu renginde kaya.
static func _catapult(im: Image, c: Dictionary, anim: int, f: int) -> void:
	var main: Color = c.main
	var shade: Color = c.shade
	var accent: Color = c.accent
	if anim == UnitSprites.Anim.DEATH:
		_catapult_death(im, c, f)
		return
	var dy := 0
	if anim == UnitSprites.Anim.WALK:
		dy = -1 if f % 2 == 1 else 0
	# kol konumu: 0 geride (yüklü), 1 dik (bırakıldı), 2 ileri (atış sonrası)
	var arm := 0
	if anim == UnitSprites.Anim.ATTACK:
		arm = f
	var ball := anim != UnitSprites.Anim.ATTACK or arm == 0
	# tekerlekler
	for wx in [3, 9]:
		_rect(im, wx, 12, 3, 2, DARK_WOOD)
		_px(im, wx + 1, 12 + (f % 2 if anim == UnitSprites.Anim.WALK else 0), WOOD)
	# kiriş ve ayaklıklar
	_rect(im, 3, 10 + dy, 9, 1, main)
	_rect(im, 3, 11 + dy, 9, 1, shade)
	_rect(im, 6, 8 + dy, 2, 2, WOOD)  # kol dayanağı
	match arm:
		0:  # geriye yatık kol, kovada kaya
			_px(im, 7, 8 + dy, WOOD)
			_px(im, 6, 7 + dy, WOOD)
			_px(im, 5, 6 + dy, WOOD)
			_rect(im, 2, 5 + dy, 4, 1, DARK_WOOD)
			if ball:
				_rect(im, 3, 3 + dy, 2, 2, accent)
		1:  # dik kol
			_rect(im, 7, 3 + dy, 1, 6, WOOD)
			_rect(im, 6, 2 + dy, 3, 1, DARK_WOOD)
			if f == 1:
				_rect(im, 10, 1, 2, 2, accent)  # kaya fırladı
		_:  # ileri inmiş kol
			_px(im, 8, 8 + dy, WOOD)
			_px(im, 9, 7 + dy, WOOD)
			_px(im, 10, 6 + dy, WOOD)
			_rect(im, 10, 4 + dy, 3, 2, DARK_WOOD)


static func _catapult_death(im: Image, c: Dictionary, f: int) -> void:
	match f:
		0:
			_rect(im, 3, 12, 3, 2, DARK_WOOD)
			_rect(im, 3, 10, 9, 2, c.main)
			_rect(im, 5, 5, 1, 5, WOOD)
			_rect(im, 3, 4, 3, 1, DARK_WOOD)
		1:
			_rect(im, 3, 12, 3, 2, DARK_WOOD)
			_rect(im, 3, 11, 9, 2, c.main)
			_rect(im, 4, 8, 4, 1, WOOD)
			_rect(im, 8, 9, 3, 2, DARK_WOOD)
		_:
			_rect(im, 3, 12, 9, 2, c.main)
			_rect(im, 3, 13, 9, 1, c.shade)
			_rect(im, 5, 11, 4, 1, WOOD)
			_rect(im, 10, 11, 2, 1, DARK_WOOD)
			_rect(im, 1, 13, 2, 1, DARK_WOOD)
			if f == 3:
				_rect(im, 12, 12, 2, 2, c.accent)
