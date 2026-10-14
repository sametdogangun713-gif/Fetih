class_name MountArt
## Dört ayaklı binek gövdeleri: at, geyik, kurt, iskelet at. Atlılar (RiderArt) ve kentaurlar
## (CentaurArt) bunu kullanır. UnitSprites'ın yardımcısıdır.
##
## Gövde sağa bakar, toynaklar 29. satırda. Çizim sırası: uzak bacaklar, kuyruk, gövde, boyun ve
## kafa, yakın bacaklar. Binici / kentaur gövdesi bunun üstüne çizilir (draw() eyer noktasını döner).
## Dört nala koşu 6 karelik döngüdür: her bacak aynı sinüs eğrisini farklı evreyle izler (ön
## bacaklar arka bacakların tersine), ileri savrulan bacak havaya kalkar ve dizden bükülür.

const GROUND := 29.0
const BONE := Color("e8dcc0")

## Tür başına ölçüler. body: gövde elipsi (merkez x, merkez y, yarıçap x, yarıçap y);
## joint_y: bacakların gövdeye bağlandığı satır; front / hind: yakın-uzak bacak x'leri;
## leg: bacak kalınlığı; stride: adım genliği (piksel); neck: boyun dibi; head: kafa merkezi.
## Hedef (gorsel_yon_dokumani.md): atlı figürü ~24x20-22 piksel.
const SPECS := {
	&"horse": {body = [14.5, 22.0, 6.5, 3.0], joint_y = 23.0, front = [19, 17], hind = [10, 8], leg = 1.9,
			stride = 2.5, neck = Vector2(19.0, 21.0), head = Vector2(23.5, 16.5), saddle = Vector2(13, 19)},
	&"undead_horse": {body = [14.5, 22.0, 6.4, 2.9], joint_y = 23.0, front = [19, 17], hind = [10, 8], leg = 1.9,
			stride = 2.5, neck = Vector2(19.0, 21.0), head = Vector2(23.5, 16.5), saddle = Vector2(13, 19)},
	&"stag": {body = [14.5, 21.5, 6.2, 2.8], joint_y = 22.5, front = [19, 17], hind = [10, 8], leg = 1.5,
			stride = 2.5, neck = Vector2(19.0, 20.5), head = Vector2(23.0, 15.5), saddle = Vector2(13, 18.5)},
	&"wolf": {body = [14.5, 23.0, 6.5, 2.6], joint_y = 24.0, front = [19, 17], hind = [10, 8], leg = 1.9,
			stride = 2.0, neck = Vector2(19.0, 22.5), head = Vector2(23.0, 20.0), saddle = Vector2(13, 20.5)},
}


## Görünüm sözlüğüne binek rampalarını ekler (coat, mane, hoof, barding).
static func add_ramps(look: Dictionary) -> void:
	var r: Dictionary = look.r
	r.coat = SpritePainter.ramp(look.coat)
	r.coat_far = SpritePainter.ramp(look.coat.darkened(0.25))
	r.mane = SpritePainter.ramp(look.mane)
	r.hoof = SpritePainter.ramp(look.get("hoof", Color("2e241c")))
	r.barding = SpritePainter.ramp(look.get("barding", look.cloth))
	r.bone = SpritePainter.ramp(BONE)


## Kare başına binek duruşu. anim/f: UnitSprites.Anim ve kare; death: ölüm karesinde çöküş (0-1).
static func pose(anim: int, f: int) -> Dictionary:
	var m := {bob = 0, legs = [], head_dy = 0.0, tail = 0.0, collapse = 0.0, x = 0.0, gait = -1.0}
	match anim:
		UnitSprites.Anim.IDLE:  # nefes alır, başını hafifçe indirir, kuyruğunu sallar
			m.bob = [0, 0, 1, 1][f]
			m.head_dy = [0.0, 0.0, 1.0, 1.0][f]
			m.tail = [0.0, 1.0, 1.0, 0.0][f]
		UnitSprites.Anim.WALK:  # dört nala
			m.gait = f / 6.0 * TAU
			m.bob = roundi(-sin(m.gait))
			m.head_dy = -m.bob * 0.6
			m.tail = cos(m.gait) * 1.2
		UnitSprites.Anim.ATTACK:  # hücum: geri toplanır, ileri atılır
			m.gait = [4.0, 4.5, 1.5, 1.6, 1.6, 0.5][f]
			m.bob = [0, -1, -1, 0, 0, 0][f]
			m.x = [-1.0, -1.0, 0.0, 1.0, 1.0, 0.0][f]
			m.head_dy = [-1.0, -1.0, 1.0, 1.0, 0.0, 0.0][f]
			m.tail = [1.0, 1.0, -1.0, -1.0, 0.0, 0.0][f]
		UnitSprites.Anim.DEATH:  # sarsılır, ön dizleri bükülür, yere çöker
			m.collapse = [0.0, 0.2, 0.5, 0.8, 1.0, 1.0][f]
			m.head_dy = [-1.0, 0.0, 0.0, 0.0, 0.0, 0.0][f]
			m.x = [-1.0, -1.0, 0.0, 0.0, 0.0, 0.0][f]
	return m


## Bineği çizer. Döner: {saddle = binicinin oturacağı nokta, mouth = dizgin ucu}.
static func draw(p: SpritePainter, look: Dictionary, kind: StringName, m: Dictionary) -> Dictionary:
	var s: Dictionary = SPECS[kind]
	var r: Dictionary = look.r
	var k: float = m.collapse
	var off := Vector2(m.x, m.bob + roundf(k * 4.0))
	var b: Array = s.body
	var joint_y: float = s.joint_y + off.y
	var feet := _feet(s, m)
	# Uzak bacaklar (koyu), kuyruk.
	p.origin = Vector2.ZERO
	_leg(p, r, Vector2(s.front[1] + off.x, joint_y), feet[1], true, k, s.leg, true)
	_leg(p, r, Vector2(s.hind[1] + off.x, joint_y), feet[3], false, k, s.leg, true)
	_tail(p, look, kind, Vector2(b[0] - b[2] + 0.5, b[1] - 1.5) + off, m.tail)
	# Gövde.
	p.begin().ellipse(b[0] + off.x, b[1] + off.y, b[2], b[3]).fill(r.coat)
	p.begin().ellipse(b[0] + off.x + 0.5, b[1] + off.y + b[3] - 0.8, b[2] - 2.0, 1.0).fill(r.coat, false, false)
	match kind:
		&"undead_horse":  # kaburgalar
			for x in [12, 14, 16]:
				p.begin().line(Vector2(x + off.x, b[1] - 1 + off.y), Vector2(x - 0.5 + off.x, b[1] + 2 + off.y), 1.0).fill(r.bone, false, false)
		&"stag":  # beyaz sağrı lekesi
			p.begin().ellipse(b[0] - b[2] + 2.0 + off.x, b[1] - 0.5 + off.y, 1.6, 1.8).fill(SpritePainter.ramp(look.coat.lightened(0.45)), true, false)
		&"wolf":  # açık renk karın tüyü
			p.begin().ellipse(b[0] + 2.0 + off.x, b[1] + 2.0 + off.y, 4.0, 1.0).fill(SpritePainter.ramp(look.coat.lightened(0.3)), false, false)
	if look.get("barding_on", false):
		_barding(p, look, s, off)
	# Boyun ve kafa.
	var neck: Vector2 = s.neck + off
	var head: Vector2 = s.head + Vector2(off.x, off.y + m.head_dy)
	if k > 0.0:  # çökerken baş yere iner
		head = head.lerp(Vector2(s.head.x + 2.5 + off.x, GROUND - 2.0), k)
	if not m.get("headless", false):  # kentaurda boyun yerine insan gövdesi gelir
		_head(p, look, kind, neck, head)
	# Yakın bacaklar.
	_leg(p, r, Vector2(s.front[0] + off.x, joint_y), feet[0], true, k, s.leg, false)
	_leg(p, r, Vector2(s.hind[0] + off.x, joint_y), feet[2], false, k, s.leg, false)
	return {saddle = s.saddle + off, mouth = head + Vector2(2.0, 1.0),
			waist = Vector2(b[0] + b[2] - 3.0, b[1] - b[3] + 2.0) + off}


## Dört toynağın yeri: [yakın ön, uzak ön, yakın arka, uzak arka]; z = kalkış.
static func _feet(s: Dictionary, m: Dictionary) -> Array:
	var out := []
	var phases := [0.0, 0.7, PI, PI + 0.7]
	var xs := [s.front[0], s.front[1], s.hind[0], s.hind[1]]
	for i in 4:
		var dx := 0.0
		var lift := 0.0
		if m.gait >= 0.0:
			var t: float = m.gait + phases[i]
			dx = roundf(s.stride * sin(t))
			lift = roundf(maxf(0.0, 2.2 * cos(t)))
		out.append(Vector3(xs[i] + m.x + dx, GROUND - lift, lift))
	return out


## Bacak: üst kısım kalın, diz, alt kısım, toynak. Ön bacak kalkınca dizi öne, arka bacağın
## topuğu hep geriye bakar. collapse: çökerken bacak katlanıp gövdenin altına yatar.
static func _leg(p: SpritePainter, r: Dictionary, joint: Vector2, foot3: Vector3, front: bool, collapse: float,
		width: float, far: bool) -> void:
	var foot := Vector2(foot3.x, foot3.y - 1.0)
	var lift := foot3.z
	if collapse > 0.0:  # katlanmış bacak yerde öne (ön) ya da geriye (arka) uzanır
		foot = foot.lerp(Vector2(joint.x + (5.0 if front else -4.0), GROUND - 1.0), collapse)
	var knee := joint.lerp(foot, 0.5)
	if front:
		knee.x += 0.8 * lift + 1.5 * collapse
		foot.x -= 0.6 * lift
	else:
		knee.x -= 1.0 + 0.3 * lift + 1.0 * collapse
	var ramp: Array = r.coat_far if far else r.coat
	p.begin().line(joint, knee, width + 0.5).line(knee, foot, width).fill(ramp)
	p.begin().rect(roundf(foot.x) - 1, foot.y + 1, 2 if width >= 1.8 else 1, 1).fill(r.hoof, false)


static func _tail(p: SpritePainter, look: Dictionary, kind: StringName, base: Vector2, swish: float) -> void:
	var r: Dictionary = look.r
	match kind:
		&"wolf":  # gür, yukarı-geri kalkık
			p.begin().line(base, base + Vector2(-4.0, -3.0 + swish), 2.8).fill(r.coat)
			p.begin().line(base + Vector2(-3.0, -2.5 + swish), base + Vector2(-4.5, -3.5 + swish), 1.6).fill(SpritePainter.ramp(look.coat.lightened(0.35)), true, false)
		&"stag":  # kısa beyaz kuyruk
			p.begin().ellipse(base.x - 0.5, base.y + 0.5, 1.2, 1.5).fill(SpritePainter.ramp(Color("f0ece0")))
		_:  # at: uzun, aşağı sarkan kıl
			p.begin().line(base, base + Vector2(-2.0 + swish, 3.0), 2.4).line(base + Vector2(-2.0 + swish, 3.0),
					base + Vector2(-2.5 + swish * 1.5, 7.0), 2.0).fill(r.mane)


## Boyun, kafa, kulak, göz; türün ayrıntıları (yele, boynuz, kafatası).
static func _head(p: SpritePainter, look: Dictionary, kind: StringName, neck: Vector2, hc: Vector2) -> void:
	var r: Dictionary = look.r
	var eye: Color = look.get("mount_eye", Color("1c1612"))
	match kind:
		&"wolf":
			p.begin().line(neck, hc + Vector2(-1, 0.5), 4.4).fill(r.coat)
			p.begin().ellipse(hc.x, hc.y, 2.7, 2.3).fill(r.coat)
			p.begin().ellipse(hc.x + 2.6, hc.y + 0.9, 2.1, 1.2).fill(r.coat)
			p.begin().poly(PackedVector2Array([hc + Vector2(-2.2, -1.2), hc + Vector2(-1.4, -4.6), hc + Vector2(0.2, -1.6)])).fill(r.coat, true, false)
			p.px(hc.x + 4.4, hc.y + 0.4, Color("1c1612"))  # burun
			p.px(hc.x + 0.6, hc.y - 0.6, eye)
			p.px(hc.x + 2.5, hc.y + 2.0, Color("fffbe8"))  # diş
		&"stag":
			p.begin().line(neck, hc + Vector2(-1, 1.5), 3.4).fill(r.coat)
			p.begin().ellipse(hc.x, hc.y, 2.3, 1.9).fill(r.coat)
			p.begin().ellipse(hc.x + 2.3, hc.y + 1.0, 1.6, 1.2).fill(r.coat)
			p.px(hc.x + 3.6, hc.y + 0.8, Color("1c1612"))
			p.px(hc.x + 0.4, hc.y - 0.5, eye)
			p.begin().poly(PackedVector2Array([hc + Vector2(-1.8, -1.0), hc + Vector2(-4.2, -2.4), hc + Vector2(-1.0, -0.2)])).fill(r.coat, true, false)
			# boynuzlar: uzak olan koyu, yakın olan açık
			for side: int in [1, 0]:
				var a := hc + Vector2(-0.8 + side * 1.5, -1.6)
				var ramp: Array = SpritePainter.ramp(BONE.darkened(0.25 * side))
				p.begin().line(a, a + Vector2(-2.0, -6.0), 1.0).line(a + Vector2(-0.7, -2.2), a + Vector2(1.3, -4.4), 1.0)
				p.line(a + Vector2(-1.5, -4.5), a + Vector2(0.3, -7.2), 1.0).line(a + Vector2(-1.4, -4.3), a + Vector2(-3.6, -5.6), 1.0)
				p.fill(ramp, false, false)
		_:  # at, iskelet at
			var skull := kind == &"undead_horse"
			p.begin().line(neck, hc + Vector2(-1.5, 1.0), 4.2).fill(r.coat)
			p.begin().ellipse(hc.x, hc.y, 2.7, 2.1).fill(r.bone if skull else r.coat)
			p.begin().line(hc + Vector2(1.0, 0.6), hc + Vector2(3.4, 2.2), 2.6).fill(r.bone if skull else r.coat)
			p.begin().poly(PackedVector2Array([hc + Vector2(-2.0, -1.0), hc + Vector2(-1.4, -4.0), hc + Vector2(-0.2, -1.6)])).fill(r.coat, true, false)
			p.begin().line(neck + Vector2(-2.0, -1.5), hc + Vector2(-2.2, -1.2), 1.7).fill(r.mane, true, false)  # yele
			p.px(hc.x + 0.3, hc.y - 0.4, eye)
			p.px(hc.x + 3.8, hc.y + 1.8, r.coat[0] if not skull else r.bone[0])  # burun deliği
			if skull:
				p.px(hc.x + 1.5, hc.y + 2.2, r.bone[0]).px(hc.x + 2.5, hc.y + 2.6, r.bone[0])


## Zırh örtüsü: gövdenin üst yarısını örter, alt kenarı süslü.
static func _barding(p: SpritePainter, look: Dictionary, s: Dictionary, off: Vector2) -> void:
	var r: Dictionary = look.r
	var b: Array = s.body
	var x0: float = b[0] - b[2] + 1.5 + off.x
	var x1: float = b[0] + b[2] - 1.0 + off.x
	var y0: float = b[1] - b[3] + 0.5 + off.y
	var y1: float = b[1] + 2.5 + off.y
	var pts := PackedVector2Array([Vector2(x0, y0 + 1), Vector2(x0 + 2, y0), Vector2(x1 - 1, y0),
			Vector2(x1, y0 + 2), Vector2(x1, y1), Vector2(x0, y1)])
	p.begin().poly(pts).fill(r.barding)
	p.begin().rect(x0, y1 - 1, x1 - x0, 1).fill(r.trim, false, false)
	if look.get("tattered", false):  # yırtık alt kenar
		for x in range(int(x0) + 1, int(x1), 3):
			p.px(x, y1 - 1, Color(0, 0, 0, 0)).px(x + 1, y1, r.barding[1])
