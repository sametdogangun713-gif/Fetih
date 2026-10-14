class_name HumanoidArt
## İnsansı figürler: hazır CC0 çizimi olmayan piyade rolleri için tam figür, atlılar ve kentaurlar
## için üst gövde, kafa, kol ve silah parçaları. UnitSprites'ın yardımcısıdır.
##
## Oran hazır CC0 sprite'lara (Puny Characters, DungeonTileset II) uyar: 32x32 kare, ~16-17 piksel
## boy (hedef 14-18), iri kafa (8x7), kısa gövde (5) ve bacak (4). Ayak tabanı 29. satırda
## (kontur 30'da), figür sağa bakar. Renkler Resurrect 64 paletinden (SpritePalette).
## Kare sayıları: durma 4 (nefes), yürüme 6 (adım döngüsü), saldırı 6 (hazırlık, vuruş, takip,
## toparlanma), ölüm 6 (sarsılma, diz bükme, devrilme, yerde sekme).

const GROUND := 29.0  ## Ayak tabanı satırı.
const HIP_Y := 26.0
const NECK := Vector2(15, 21)  ## Durma halinde boyun (omuz hizası) noktası.
const GOLD := Color("e8c25a")
const WHITE := Color("fffbe8")
const SMEAR := Color(1.0, 0.98, 0.9, 0.55)

## Yürüme döngüsü (6 kare): ön/arka ayağın ileri kayması ve havaya kalkışı, gövdenin inip kalkması.
const WALK_FRONT: Array[int] = [2, 1, -1, -2, -1, 1]
const WALK_BACK: Array[int] = [-2, -1, 1, 2, 1, -1]
const WALK_FRONT_LIFT: Array[int] = [0, 0, 0, 0, 1, 1]
const WALK_BACK_LIFT: Array[int] = [0, 1, 1, 0, 0, 0]
const WALK_BOB: Array[int] = [0, -1, -1, 0, -1, -1]
## Durma (4 kare, 2 kare/sn): yarım saniye nefes alır, yarım saniye verir.
const IDLE_BOB: Array[int] = [0, 0, 1, 1]
## Yedek piyade figürlerinde role göre başlık (bkz. helmet()).
const ROLE_HELMS := {
	&"warrior": &"open", &"spearman": &"cone", &"tank": &"full", &"archer": &"hood", &"mage": &"hat",
}
## Ölüm devrilme açıları (derece) ve kayma.
const FALL_DEG: Array[float] = [0.0, 18.0, 48.0, 78.0, 90.0, 90.0]


## Görünüm sözlüğünden renk rampaları üretir (bkz. UnitSprites._look).
static func ramps(look: Dictionary) -> Dictionary:
	var r := {}
	for key in ["skin", "hair", "cloth", "pants", "boots", "metal", "leather", "wood", "trim"]:
		r[key] = SpritePainter.ramp(look[key])
	r.cloth_back = SpritePainter.ramp(look.cloth.darkened(0.22))
	r.pants_back = SpritePainter.ramp(look.pants.darkened(0.22))
	r.skin_back = SpritePainter.ramp(look.skin.darkened(0.18))
	return r


# --- Tam figür (piyade rolleri) ---

## Bir karenin tamamı (konturlu). fx katmanı (kayma izi, kıvılcım) konturdan sonra eklenir.
static func frame(role: StringName, anim: int, f: int, look: Dictionary) -> Image:
	if anim == UnitSprites.Anim.DEATH:
		return _death_frame(role, f, look)
	var p := SpritePainter.new(UnitSprites.SIZE)
	var fx := SpritePainter.new(UnitSprites.SIZE)
	var pose := _pose(role, anim, f)
	_paint(p, fx, role, pose, look)
	SpritePainter.outline(p.image)
	SpritePainter.stamp(p.image, fx.image)
	return p.image


static func _death_frame(role: StringName, f: int, look: Dictionary) -> Image:
	var p := SpritePainter.new(UnitSprites.SIZE)
	var fx := SpritePainter.new(UnitSprites.SIZE)
	var pose := _pose(role, UnitSprites.Anim.IDLE, 0)
	pose.hurt = true
	pose.o = Vector2(-1, 0) if f == 0 else Vector2(-1, 1)
	pose.legs = [1, -1, 0, 0] if f >= 1 else [0, 0, 0, 0]
	_paint(p, fx, role, pose, look)
	var img := topple(p.image, FALL_DEG[f], Vector2(15.5, GROUND + 0.5), 9.0 * FALL_DEG[f] / 90.0,
			1 if f == 4 else 0)
	SpritePainter.outline(img)
	return img


## Figürü ayak noktası etrafında geriye devirir, sonra yere oturtur (en alt pikseli zemine).
## Döndürme taşmasın diye geniş tuvalde yapılır. bounce: yere çarpınca kaç piksel sekiyor.
static func topple(src: Image, degrees: float, pivot: Vector2, shift_x: float, bounce := 0) -> Image:
	var side := src.get_width()
	if degrees == 0.0:
		return src.duplicate() as Image
	var pad := side / 2
	var big := Image.create_empty(side + pad * 2, side + pad * 2, false, Image.FORMAT_RGBA8)
	SpritePainter.stamp(big, src, Vector2i(pad, pad))
	var turned := SpritePainter.rotated(big, degrees, pivot + Vector2(pad, pad), Vector2(shift_x, 0))
	var used := turned.get_used_rect()
	var out := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	if not used.has_area():
		return out
	# Zemine oturt: en alt piksel GROUND satırına (sekmede biraz yukarı).
	var dy := int(GROUND) - (used.end.y - 1 - pad) - bounce
	var dx := 0
	var left := used.position.x - pad
	var right := used.end.x - 1 - pad
	if left < 1:
		dx = 1 - left
	elif right > side - 2:
		dx = side - 2 - right
	out.blit_rect(turned, Rect2i(pad - dx, pad - dy, side, side), Vector2i.ZERO)
	return out


## Kare başına duruş. o: üst gövde kayması; legs: [ön dx, arka dx, ön kalkış, arka kalkış];
## hand / back_hand: boyuna göre el konumu; angle: silah açısı (0 sağ, -90 yukarı); fx: saldırı evresi.
static func _pose(role: StringName, anim: int, f: int) -> Dictionary:
	var p := {o = Vector2.ZERO, legs = [0, 0, 0, 0], hand = Vector2(3, 4), back_hand = Vector2(-3, 5),
			angle = -60.0, fx = -1, pull = 0, glow = 0, shield = 0, hurt = false}
	match anim:
		UnitSprites.Anim.IDLE:
			p.o = Vector2(0, IDLE_BOB[f])
		UnitSprites.Anim.WALK:
			p.o = Vector2(0, WALK_BOB[f])
			p.legs = [WALK_FRONT[f], WALK_BACK[f], WALK_FRONT_LIFT[f], WALK_BACK_LIFT[f]]
			p.back_hand = Vector2(-3 + WALK_FRONT[f] * 0.5, 5)  # arka kol ön bacağın tersine sallanır
			p.hand = Vector2(3 + WALK_BACK[f] * 0.3, 4)
		UnitSprites.Anim.ATTACK:
			p.fx = f
			p.o = Vector2([-1, -1, 1, 2, 1, 0][f], [0, 0, 0, 1, 1, 0][f])
			p.legs = [[0, 0, 0, 0], [-1, 0, 0, 0], [2, -1, 0, 0], [3, -2, 0, 0], [3, -2, 0, 0], [1, -1, 0, 0]][f]
	match role:
		RoleRules.WARRIOR:
			if anim == UnitSprites.Anim.ATTACK:  # kılıç başın arkasına kalkar, önden aşağı iner
				p.hand = [Vector2(-1, -3), Vector2(-2, -4), Vector2(4, 0), Vector2(5, 3), Vector2(5, 3), Vector2(3, 3)][f]
				p.angle = [-135.0, -150.0, -15.0, 35.0, 40.0, -30.0][f]
		RoleRules.SPEARMAN:
			p.hand = Vector2(3, 4) + Vector2(p.hand.x - 3, 0)
			p.angle = -82.0
			if anim == UnitSprites.Anim.ATTACK:  # geri çeker, ileri saplar
				p.hand = [Vector2(0, 3), Vector2(-1, 3), Vector2(5, 3), Vector2(6, 3), Vector2(6, 3), Vector2(3, 4)][f]
				p.angle = [-12.0, -10.0, -4.0, -2.0, -2.0, -40.0][f]
		RoleRules.TANK:
			p.hand = Vector2(4, 4)
			if anim == UnitSprites.Anim.ATTACK:  # kalkanla itme
				p.shield = [-1, -1, 2, 3, 2, 0][f]
		RoleRules.ARCHER:
			p.hand = Vector2(5, 3)
			if anim == UnitSprites.Anim.ATTACK:  # ok takar, gerer, bırakır
				p.o.x = [0, 0, -1, 0, 0, 0][f]
				p.legs = [0, 0, 0, 0]
				p.pull = [1, 2, 3, 0, 0, 0][f]
		RoleRules.MAGE:
			p.hand = Vector2(4, 3)
			if anim == UnitSprites.Anim.ATTACK:  # asayı kaldırır, küre parlar, ileri savurur
				p.hand = [Vector2(3, 0), Vector2(3, -1), Vector2(5, 1), Vector2(5, 2), Vector2(5, 2), Vector2(4, 3)][f]
				p.glow = [1, 2, 3, 2, 1, 0][f]
				p.legs = [[0, 0, 0, 0], [0, 0, 0, 0], [2, -1, 0, 0], [2, -1, 0, 0], [2, -1, 0, 0], [1, 0, 0, 0]][f]
	if p.hurt:
		p.hand = Vector2(2, 1)
		p.back_hand = Vector2(-4, 2)
	return p


static func _paint(p: SpritePainter, fx: SpritePainter, role: StringName, pose: Dictionary, look: Dictionary) -> void:
	p.origin = Vector2.ZERO
	var o: Vector2 = pose.o
	var n: Vector2 = NECK + o
	var legs: Array = pose.legs
	var robe: bool = role == RoleRules.MAGE
	# Arkadan öne: sadak / arka kol / bacaklar / gövde / kafa / ön kol + silah.
	if role == RoleRules.ARCHER:
		quiver(p, look, n)
	if role == RoleRules.WARRIOR and not pose.hurt:
		p.origin = Vector2.ZERO
		round_shield(p, look, n + pose.back_hand + Vector2(-1, -1), true)
	arm(p, look, n + Vector2(-2, 1), n + pose.back_hand, true)
	p.origin = Vector2.ZERO
	if robe:
		robe_body(p, look, n, legs)
	else:
		legs_pair(p, look, n.x - o.x, legs)
		torso(p, look, n, 1 if role == RoleRules.TANK else 0)
	head(p, look, n, ROLE_HELMS.get(role, &"none"))
	match role:
		RoleRules.WARRIOR:
			arm(p, look, n + Vector2(2, 1), n + pose.hand)
			sword(p, look, n + pose.hand, pose.angle)
			if pose.fx == 2:
				smear_arc(fx, n + pose.hand, 9.0, -150.0, -15.0)
			elif pose.fx == 3:
				spark(fx, n + pose.hand + Vector2.from_angle(deg_to_rad(pose.angle)) * 9.0)
		RoleRules.SPEARMAN:
			spear(p, look, n + pose.hand, pose.angle, 5.0, 13.0)
			arm(p, look, n + Vector2(2, 1), n + pose.hand)
			if pose.fx == 3:
				spark(fx, n + pose.hand + Vector2.from_angle(deg_to_rad(pose.angle)) * 16.0)
		RoleRules.TANK:
			arm(p, look, n + Vector2(2, 1), n + pose.hand)
			kite_shield(p, look, n + Vector2(5 + pose.shield, 5))
			if pose.fx == 3:
				spark(fx, n + Vector2(10 + pose.shield, 4))
		RoleRules.ARCHER:
			bow(p, look, n + pose.hand, pose.pull, pose.pull > 0)
			arm(p, look, n + Vector2(2, 1), n + pose.hand)
			if pose.pull > 0:
				arm(p, look, n + Vector2(1, 1), n + pose.hand - Vector2(1 + pose.pull, 0))
		RoleRules.MAGE:
			staff(p, look, fx, n + pose.hand, pose.glow)
			arm(p, look, n + Vector2(2, 1), n + pose.hand)
		_:
			arm(p, look, n + Vector2(2, 1), n + pose.hand)


# --- Parçalar ---

static func legs_pair(p: SpritePainter, look: Dictionary, hip_x: float, legs: Array) -> void:
	var r: Dictionary = look.r
	leg(p, r, Vector2(roundf(hip_x) - 1, HIP_Y), legs[1], legs[3], true)
	leg(p, r, Vector2(roundf(hip_x) + 2, HIP_Y), legs[0], legs[2], false)


static func leg(p: SpritePainter, r: Dictionary, hip: Vector2, dx: float, lift: float, back: bool) -> void:
	var foot := Vector2(hip.x + dx, GROUND - 1.0 - lift)
	p.begin().line(hip, foot, 1.9).fill(r.pants_back if back else r.pants)
	var boots: Array = r.boots
	p.begin().rect(foot.x - 1, foot.y, 3, 2).fill(boots)


static func torso(p: SpritePainter, look: Dictionary, n: Vector2, wide := 0) -> void:
	var r: Dictionary = look.r
	var x := n.x - 3 - wide
	var w := 7 + wide * 2
	p.begin().rect(x, n.y, w, 5).cut(x, n.y, 1, 1).cut(x + w - 1, n.y, 1, 1).fill(r.cloth)
	p.begin().rect(x, n.y + 3, w, 1).fill(r.leather, true, false)
	p.px(n.x + 1 + wide, n.y + 3, GOLD)


## Kafa: ten, saç, başlık, yüz. Kafa merkezi boyun noktasının 1 sağı, 4 üstü.
## Saç ve başlık iç kontur çizmez (yüzü karartmasın); yüz ayrıntıları en son çizilir.
static func head(p: SpritePainter, look: Dictionary, n: Vector2, helm: StringName = &"none") -> void:
	var r: Dictionary = look.r
	var c := n + Vector2(1, look.get("head_dy", -4.0))
	var hr: Vector2 = look.get("head_r", Vector2(3.7, 3.6))
	p.begin().ellipse(c.x, c.y, hr.x, hr.y).fill(r.skin)
	var covered := helm in [&"open", &"full", &"cone", &"hood", &"hat", &"horned"]
	if look.get("hair_on", true) and not covered:
		p.begin().ellipse(c.x - 0.6, c.y - 0.9, hr.x, hr.y - 0.7).cut(c.x, c.y - 1, 5, 6).fill(r.hair, true, false)
	if look.get("long_hair", false) and helm != &"full":  # ense arkasına inen saç
		p.begin().rect(c.x - hr.x, c.y, 2, 4).fill(r.hair, true, false)
	if look.get("beard", false) and helm != &"full":
		p.begin().ellipse(c.x + 1.0, c.y + 2.6, 3.0, 2.4).cut(c.x - 3, c.y, 3, 2).fill(r.hair, true, false)
	if helm != &"none":
		helmet(p, look, n, helm)
	if helm == &"full":
		return
	match look.get("face", &"human"):
		&"skull":  # kafatası: göz çukuru, parlayan göz bebeği, diş sırası
			p.px(c.x + 1, c.y, r.skin[0]).px(c.x + 2, c.y, look.eye)
			p.px(c.x + 2, c.y + 1, r.skin[0])
			p.px(c.x + 1, c.y + 3, r.skin[0]).px(c.x + 3, c.y + 3, r.skin[0])
		&"orc":  # kalın kaş, diş
			p.px(c.x + 2, c.y, look.eye)
			p.px(c.x + 1, c.y - 1, r.skin[0]).px(c.x + 2, c.y - 1, r.skin[0])
			p.px(c.x + 3, c.y + 2, WHITE)
		_:
			p.px(c.x + 2, c.y, look.eye)
			p.px(c.x + 3, c.y + 1, r.skin[1])  # burun gölgesi


## Başlık türleri: open (açık miğfer), full (kapalı miğfer, sorguçlu), cone (konik), hood (kukuleta),
## hat (büyücü şapkası), horned (boynuzlu), band (saç bandı), feathers (tüylü bant).
static func helmet(p: SpritePainter, look: Dictionary, n: Vector2, kind: StringName) -> void:
	var r: Dictionary = look.r
	var c := n + Vector2(1, look.get("head_dy", -4.0))
	var hr: Vector2 = look.get("head_r", Vector2(3.7, 3.6))
	match kind:
		&"open":
			p.begin().ellipse(c.x - 0.3, c.y - 0.6, hr.x + 0.4, hr.y - 0.2).cut(c.x - 5, c.y - 0.5, 10, 6).fill(r.metal, true, false)
			p.begin().rect(c.x - 4, c.y - 1, 9, 1).fill(r.metal, true, false)
			p.begin().rect(c.x - 4, c.y - 1, 2, 3).fill(r.metal, true, false)
			p.begin().rect(c.x - 1, c.y - 6, 2, 2).fill(r.trim, true, false)  # sorguç
		&"full":
			p.begin().ellipse(c.x, c.y - 0.2, hr.x + 0.3, hr.y + 0.4).fill(r.metal, true, false)
			for x in range(int(c.x), int(c.x) + 4):
				p.tint(x, c.y, look.get("visor", r.metal[0]))  # göz yarığı (ölülerde parlar)
			p.px(c.x + 2, c.y + 2, r.metal[0]).px(c.x + 3, c.y + 2, r.metal[0])
			if look.get("plume", true):
				p.begin().ellipse(c.x - 2.0, c.y - 4.3, 2.4, 1.4).fill(r.trim, true, false)
		&"cone":
			p.begin().poly(PackedVector2Array([Vector2(c.x - 4, c.y - 0.5), Vector2(c.x, c.y - 6.5),
					Vector2(c.x + 4, c.y - 0.5)])).fill(r.metal, true, false)
			p.begin().rect(c.x + 2, c.y - 1, 1, 3).fill(r.metal, false, false)  # burun siperi
		&"hood":
			p.begin().ellipse(c.x - 0.5, c.y - 0.3, 4.3, 4.1).cut(c.x + 0.5, c.y - 1.5, 5, 6).fill(r.cloth, true, false)
			p.begin().rect(c.x - 5, c.y + 2, 3, 3).fill(r.cloth, true, false)
		&"hat":
			p.begin().rect(c.x - 5, c.y - 2, 11, 1).fill(r.cloth, true, false)
			p.begin().poly(PackedVector2Array([Vector2(c.x - 3.5, c.y - 1.5), Vector2(c.x - 2, c.y - 9),
					Vector2(c.x - 4.5, c.y - 10), Vector2(c.x + 3.5, c.y - 1.5)])).fill(r.cloth, true, false)
			p.begin().rect(c.x - 3, c.y - 3, 7, 1).fill(r.trim, false, false)
		&"horned":
			p.begin().ellipse(c.x - 0.3, c.y - 0.6, hr.x + 0.4, hr.y - 0.2).cut(c.x - 5, c.y - 0.5, 10, 6).fill(r.metal, true, false)
			# kısa, dışa kıvrık boynuzlar (arka koyu, ön açık)
			var bone := SpritePainter.ramp(Color("ab947a"))
			p.begin().line(Vector2(c.x - 3, c.y - 2), Vector2(c.x - 5, c.y - 3), 1.8).line(Vector2(c.x - 5, c.y - 3), Vector2(c.x - 5.5, c.y - 5), 1.2).fill(bone, true, false)
			p.begin().line(Vector2(c.x + 2, c.y - 3), Vector2(c.x + 4, c.y - 4), 1.8).line(Vector2(c.x + 4, c.y - 4), Vector2(c.x + 4.5, c.y - 6), 1.2).fill(bone, true, false)
		&"band":
			p.begin().rect(c.x - 4, c.y - 2, 8, 1).fill(r.trim, false, false)
		&"feathers":
			p.begin().rect(c.x - 4, c.y - 2, 8, 1).fill(r.trim, false, false)
			var feather := SpritePainter.ramp(Color("f0e8d8"))
			p.begin().line(Vector2(c.x - 3, c.y - 2), Vector2(c.x - 5, c.y - 8), 1.8).fill(feather, true, false)
			p.begin().line(Vector2(c.x - 1, c.y - 3), Vector2(c.x - 2, c.y - 9), 1.8).fill(SpritePainter.ramp(look.trim), true, false)


## Kol: omuzdan ele kalın çizgi (kol yeni) ve ten renginde el.
static func arm(p: SpritePainter, look: Dictionary, shoulder: Vector2, hand: Vector2, back := false) -> void:
	var r: Dictionary = look.r
	p.origin = Vector2.ZERO
	p.begin().line(shoulder, hand, 1.9).fill(r.cloth_back if back else r.cloth)
	p.begin().rect(hand.x - 0.5, hand.y - 0.5, 2, 2).fill(r.skin_back if back else r.skin)


static func sword(p: SpritePainter, look: Dictionary, hand: Vector2, angle: float, length := 9.0) -> void:
	var r: Dictionary = look.r
	var d := Vector2.from_angle(deg_to_rad(angle))
	var side := Vector2(-d.y, d.x)
	var h := hand + Vector2(0.5, 0.5)
	p.begin().line(h - d * 1.5, h + d * 0.5, 1.0).fill(r.leather, false, false)  # kabza
	p.begin().line(h + d - side * 2.0, h + d + side * 2.0, 1.0).fill(r.trim, false)  # balçak
	p.begin().line(h + d * 2.0, h + d * length, 1.8).fill(r.metal)  # namlu
	p.px(h.x + d.x * (length - 1) - 0.5, h.y + d.y * (length - 1) - 0.5, r.metal[3])


## Mızrak / kargı: elden geriye `back`, ileriye `length` piksel sap ve sivri uç.
static func spear(p: SpritePainter, look: Dictionary, hand: Vector2, angle: float, back: float, length: float, pennant := false) -> void:
	var r: Dictionary = look.r
	var d := Vector2.from_angle(deg_to_rad(angle))
	var side := Vector2(-d.y, d.x)
	var h := hand + Vector2(0.5, 0.5)
	p.begin().line(h - d * back, h + d * length, 1.0).fill(r.wood, false)
	var tip := h + d * length
	p.begin().poly(PackedVector2Array([tip - side * 1.6, tip + d * 4.0, tip + side * 1.6])).fill(r.metal)
	if pennant:  # flama: uç altında üçgen bez
		var at := tip - d * 1.5
		p.begin().poly(PackedVector2Array([at, at - d * 3.0, at - d * 1.5 - side * 3.5])).fill(r.trim)


## Yay: elde dikey, öne bükük; pull 0-3 kirişin geri çekilmesi; arrow: ok takılı mı.
static func bow(p: SpritePainter, look: Dictionary, grip: Vector2, pull: int, arrow: bool) -> void:
	var r: Dictionary = look.r
	p.begin()
	for dy in range(-6, 7):
		var bulge := 2.0 * (1.0 - pow(dy / 6.0, 2.0))
		p.rect(grip.x + roundf(bulge), grip.y + dy, 1, 1)
	p.fill(r.wood, true, false)
	var nock := Vector2(grip.x - pull, grip.y)
	p.begin().line(Vector2(grip.x, grip.y - 6), nock, 1.0).line(nock, Vector2(grip.x, grip.y + 6), 1.0)
	p.fill_color(Color("e4e4d8"))
	if arrow:
		p.begin().line(nock, nock + Vector2(8, 0), 1.0).fill(r.wood, false)
		p.px(nock.x + 8, nock.y, r.metal[3]).px(nock.x + 9, nock.y, r.metal[2])
		p.px(nock.x, nock.y - 1, WHITE).px(nock.x + 1, nock.y - 1, WHITE)


static func quiver(p: SpritePainter, look: Dictionary, n: Vector2) -> void:
	var r: Dictionary = look.r
	p.origin = Vector2.ZERO
	p.begin().rect(n.x - 5, n.y - 1, 3, 7).fill(r.leather)
	p.px(n.x - 5, n.y - 2, WHITE).px(n.x - 3, n.y - 3, WHITE).px(n.x - 4, n.y - 2, r.trim[2])


## Asa: elden aşağı-yukarı uzanan sap, tepede parlayan küre. glow 0-3 (3: büyü anı, ışınlar).
static func staff(p: SpritePainter, look: Dictionary, fx: SpritePainter, hand: Vector2, glow: int, orb := Color()) -> void:
	var r: Dictionary = look.r
	if orb == Color():
		orb = look.get("glow", Color("9fe8ff"))
	var top := hand + Vector2(1, -7)
	p.begin().line(hand + Vector2(-1, 8), top, 1.6).fill(r.wood)
	var radius := 1.6 + glow * 0.45
	p.begin().ellipse(top.x + 0.5, top.y - 0.5, radius, radius).fill(SpritePainter.ramp(orb))
	p.px(top.x, top.y - 1, WHITE)
	if glow >= 2:
		halo(fx, top + Vector2(0.5, -0.5), radius + 1.5, orb)
	if glow >= 3:
		for d: Vector2 in [Vector2(-5, 0), Vector2(5, 0), Vector2(0, -5), Vector2(3.5, -3.5), Vector2(-3.5, -3.5), Vector2(3.5, 3.5)]:
			fx.px(top.x + d.x, top.y - 1 + d.y, WHITE)


## Yuvarlak kalkan (arka kolda). back: arkada kalan (koyu) taraf.
static func round_shield(p: SpritePainter, look: Dictionary, at: Vector2, back := false) -> void:
	var r: Dictionary = look.r
	p.begin().ellipse(at.x, at.y, 3.2, 3.8).fill(r.metal)
	p.begin().ellipse(at.x, at.y, 2.2, 2.8).fill(SpritePainter.ramp(look.cloth.darkened(0.15 if back else 0.0)), true, false)
	p.px(at.x - 0.5, at.y - 0.5, r.metal[3])


## Uzun damla kalkan (öne tutulur).
static func kite_shield(p: SpritePainter, look: Dictionary, at: Vector2) -> void:
	var r: Dictionary = look.r
	var pts := PackedVector2Array([at + Vector2(-2.5, -6), at + Vector2(2.5, -6), at + Vector2(2.5, 1),
			at + Vector2(0, 5.5), at + Vector2(-2.5, 1)])
	p.begin().poly(pts).fill(r.metal)
	var inner := PackedVector2Array([at + Vector2(-1.5, -5), at + Vector2(1.5, -5), at + Vector2(1.5, 0.5),
			at + Vector2(0, 3.5), at + Vector2(-1.5, 0.5)])
	p.begin().poly(inner).fill(r.cloth, true, false)
	p.px(at.x - 0.5, at.y - 2, r.trim[3]).px(at.x - 0.5, at.y - 1, r.trim[2])


## Büyücü cübbesi: bacak yerine aşağı genişleyen etek; yürürken etek ucu sallanır.
static func robe_body(p: SpritePainter, look: Dictionary, n: Vector2, legs: Array) -> void:
	var r: Dictionary = look.r
	var sway := clampf(float(legs[0]) * 0.5, -1.0, 1.0)
	var pts := PackedVector2Array([Vector2(n.x - 3, n.y), Vector2(n.x + 4, n.y), Vector2(n.x + 5 + sway, GROUND + 1),
			Vector2(n.x - 4 + sway, GROUND + 1)])
	p.begin().poly(pts).fill(r.cloth)
	p.begin().rect(n.x - 3, n.y + 4, 7, 1).fill(r.trim, false, false)
	p.begin().rect(n.x - 4 + sway, GROUND, 9, 1).fill(r.cloth_back, false, false)


# --- Efekt katmanı (konturdan sonra; sadece görüntü) ---

## Kılıç savurma izi: elden r uzaklıkta, açı aralığında yarı saydam yay.
static func smear_arc(fx: SpritePainter, center: Vector2, radius: float, from_deg: float, to_deg: float) -> void:
	var steps := 14
	for i in steps + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, i / float(steps)))
		for k: float in [radius - 1.0, radius, radius + 0.8]:
			var q := center + Vector2(0.5, 0.5) + Vector2.from_angle(a) * k
			fx.px(floorf(q.x), floorf(q.y), SMEAR)


## Vuruş kıvılcımı (artı biçimli).
static func spark(fx: SpritePainter, at: Vector2) -> void:
	var c := Vector2(floorf(at.x), floorf(at.y))
	fx.px(c.x, c.y, WHITE)
	for d: Vector2 in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		fx.px(c.x + d.x, c.y + d.y, Color("ffe070"))


## Parıltı halesi (yarı saydam halka).
static func halo(fx: SpritePainter, center: Vector2, radius: float, color: Color) -> void:
	var c := color
	c.a = 0.5
	for i in 20:
		var q := center + Vector2.from_angle(TAU * i / 20.0) * radius
		fx.px(floorf(q.x), floorf(q.y), c)
