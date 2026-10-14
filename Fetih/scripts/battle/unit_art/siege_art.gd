class_name SiegeArt
## Kuşatma makineleri (koddan üretilir; UnitSprites'ın yardımcısı). Figür sağa bakar, tekerlek tabanı 29. satırda.
##   cannon   (Cüce Topçusu): kahverengi ahşap şasi, tek büyük tekerlek, kalın PİRİNÇ namlu yatay-yukarı
##            uzanır. Siluet: uzun yatay çubuk.
##   catapult (Golem Kaya Fırlatan): taş kaide, iki taş disk tekerlek, uzun ahşap kol ve kolun ucunda kaya.
##            Siluet: yukarı yükselen çapraz kol + yuvarlak kaya (ametist rün ışıkları).
## Kare sayıları UnitSprites.GEN_FRAMES ile aynı: durma 4, yürüme 6, saldırı 6, ölüm 6.
## Godot: SpritePainter maskeye şekil çizip fill() ile rampa boyar; burada her parça ayrı şekil.

const SIZE := 32
const GROUND := 29.0
const REAR_WHEEL := Vector2(11.5, 29.5)  ## Ölümde makine bu noktadan geriye devrilir.
const DEATH_DEG: Array[float] = [0.0, 10.0, 28.0, 48.0, 60.0, 60.0]
const BARREL_DIR := Vector2(0.951, -0.309)  ## Namlu yönü (yaklaşık 18 derece yukarı).
const SPARK := Color("fbb954")
const FLASH := Color("fbff86")
const SMOKE := Color("9babb2")
const RUNE := Color("a884f3")
const RUNE_DIM := Color("6b3e75")


static func frame(kind: StringName, anim: int, f: int, look: Dictionary) -> Image:
	var p := SpritePainter.new(SIZE)
	var fx := SpritePainter.new(SIZE)
	var pose := _pose(kind, anim, f)
	p.origin = pose.o
	fx.origin = pose.o
	if kind == &"catapult":
		_catapult(p, look, pose)
	else:
		_cannon(p, fx, pose)
	if anim == UnitSprites.Anim.DEATH:
		var img := HumanoidArt.topple(p.image, DEATH_DEG[f], REAR_WHEEL, -4.0 * DEATH_DEG[f] / 90.0,
				1 if f == 4 else 0)
		SpritePainter.outline(img)
		return img
	SpritePainter.outline(p.image)
	SpritePainter.stamp(p.image, fx.image)
	return p.image


## Kare başına duruş. o: gövde kayması; wheel: tekerlek açısı (derece); recoil: namlu geri tepmesi (piksel);
## arm: mancınık kolu açısı (derece, 0 sağ, 90 yukarı, 180 sol); loaded: kol ucunda kaya var;
## spark: fitil kıvılcımı; flash: namlu alevi boyutu (-1 yok); smoke: duman evresi (-1 yok).
static func _pose(kind: StringName, anim: int, f: int) -> Dictionary:
	var pose := {o = Vector2.ZERO, wheel = 0.0, recoil = 0.0, arm = 125.0, loaded = true, spark = f % 2,
			flash = -1, smoke = -1, hurt = false}
	match anim:
		UnitSprites.Anim.IDLE:
			pose.arm = [125.0, 125.0, 123.0, 123.0][f]
		UnitSprites.Anim.WALK:
			pose.o = Vector2(0, [0, -1, 0, 0, -1, 0][f])
			pose.wheel = 15.0 * f
			pose.arm = 125.0 + [0.0, 3.0, 0.0, -3.0, 0.0, 3.0][f]
		UnitSprites.Anim.ATTACK:
			if kind == &"catapult":
				pose.arm = [150.0, 172.0, 95.0, 35.0, 55.0, 100.0][f]
				pose.loaded = f < 3
				pose.o = Vector2([0, -1, 0, 1, 0, 0][f], 0)
			else:
				pose.recoil = [0.0, -1.0, 3.0, 2.0, 1.0, 0.0][f]
				pose.o = Vector2([0, 0, -1, -1, 0, 0][f], 0)
				pose.flash = [-1, -1, 2, 1, -1, -1][f]
				pose.smoke = [-1, -1, -1, 0, 1, 2][f]
				pose.spark = 1 if f < 2 else 0
		UnitSprites.Anim.DEATH:
			pose.hurt = true
			pose.spark = 0
			pose.arm = 178.0 if f >= 2 else 140.0
			pose.loaded = f < 2
	return pose


static func _ramps(look: Dictionary) -> Dictionary:
	return {
		wood = SpritePainter.ramp(Color("4c3e24")),
		brass = SpritePainter.ramp(Color("f9c22b")),
		iron = SpritePainter.ramp(Color("625565")),
		stone = SpritePainter.ramp(look.cloth),
		stone_dark = SpritePainter.ramp(look.cloth.darkened(0.25)),
	}


# --- Top (Cüce Topçusu) ---

static func _cannon(p: SpritePainter, fx: SpritePainter, pose: Dictionary) -> void:
	var r := _ramps({cloth = Color("7a6e5e")})
	var d := BARREL_DIR
	# Şasi kuyruğu ve gövdesi.
	p.begin().line(Vector2(8, 25), Vector2(3, 28), 2.0).fill(r.wood)
	p.begin().poly(PackedVector2Array([Vector2(7, 26), Vector2(8, 21), Vector2(19, 20), Vector2(22, 22),
			Vector2(20, 26)])).fill(r.wood)
	p.begin().rect(7, 25, 14, 1).fill(r.iron, false, false)  # alt şerit
	# Namlu: pirinç, arka toparlak, ağız bandı (geri tepme namluyu geriye kaydırır).
	var pivot: Vector2 = Vector2(13, 20) - d * pose.recoil
	var rear: Vector2 = pivot - d * 4.0
	var tip: Vector2 = pivot + d * 10.5
	p.begin().line(rear, tip, 4.4).fill(r.brass)
	p.begin().ellipse(rear.x, rear.y, 2.3, 2.3).fill(r.brass)
	p.begin().line(tip - d * 1.4, tip, 5.2).fill(r.iron)
	p.begin().px(tip.x + 1.0, tip.y, Color("2e222f"))  # namlu ağzı
	if pose.spark >= 1:
		p.begin().px(rear.x - 1.0, rear.y - 3.0, SPARK)  # fitil kıvılcımı
		p.begin().px(rear.x - 1.0, rear.y - 2.0, Color("625565"))
	# Tekerlek: demir çember, ahşap iç, dönen paraları.
	var c := Vector2(12, 25)
	p.begin().ellipse(c.x, c.y, 4.2, 4.2).fill(r.iron)
	p.begin().ellipse(c.x, c.y, 3.0, 3.0).fill(r.wood, false, false)
	for k in 2:
		var a := deg_to_rad(pose.wheel + 90.0 * k)
		var v := Vector2(cos(a), sin(a)) * 3.0
		p.begin().line(c - v, c + v, 1.0).fill_color(r.wood[0])
	p.begin().px(c.x, c.y, r.brass[3])
	# Alev ve duman.
	if pose.flash >= 0:
		var s: float = 2.0 + pose.flash
		var at: Vector2 = tip + d * 2.0
		fx.begin().ellipse(at.x, at.y, s, s * 0.8).fill_color(FLASH)
		fx.begin().ellipse(at.x - 1.0, at.y, s * 0.55, s * 0.45).fill_color(Color("fb6b1d"))
	if pose.smoke >= 0:
		var up: float = pose.smoke
		fx.begin().ellipse(tip.x + 3.0 + up, tip.y - 2.0 - up, 2.0 + up * 0.6, 1.6 + up * 0.5).fill_color(
				Color(SMOKE.r, SMOKE.g, SMOKE.b, 0.85))


# --- Mancınık (Golem Kaya Fırlatan) ---

static func _catapult(p: SpritePainter, look: Dictionary, pose: Dictionary) -> void:
	var r := _ramps(look)
	# Kaide: taş blok ve A çatı.
	p.begin().rect(8, 21, 16, 4).fill(r.stone)
	p.begin().poly(PackedVector2Array([Vector2(11, 21), Vector2(14, 15), Vector2(18, 15), Vector2(20, 21)])).fill(
			r.stone_dark)
	# Rün ışıkları (ametist): kaide üzerinde, hasar alınca sönük.
	var glow: Color = RUNE_DIM if pose.hurt else (RUNE if pose.spark == 1 or pose.arm < 100.0 else RUNE_DIM)
	p.begin().px(12, 23, glow)
	p.begin().px(19, 23, glow)
	p.begin().px(16, 18, glow)
	# Kol: eksen noktasından arka (karşı ağırlık) ve ön (kova) uçlar.
	var pivot := Vector2(16, 16.5)
	var a := deg_to_rad(pose.arm)
	var u := Vector2(cos(a), -sin(a))
	var tip := pivot + u * 8.5
	var rear := pivot - u * 3.0
	p.begin().line(rear, tip, 2.2).fill(r.wood)
	p.begin().ellipse(rear.x, rear.y, 2.2, 2.2).fill(r.stone_dark)  # karşı ağırlık
	p.begin().ellipse(tip.x, tip.y, 2.2, 1.7).fill(r.wood)  # kova
	if pose.loaded:
		var rock := tip + Vector2(0, -1.8)
		p.begin().ellipse(rock.x, rock.y, 2.7, 2.7).fill(r.stone)
		p.begin().px(rock.x + 1.0, rock.y, r.stone[0])  # çatlak
		p.begin().px(rock.x, rock.y + 1.0, r.stone[0])
	p.begin().px(pivot.x, pivot.y, r.brass[3])
	# Tekerlekler: taş diskler, kenarda dönen rün noktası.
	for cx in [10.0, 21.0]:
		var c := Vector2(cx, 26.0)
		p.begin().ellipse(c.x, c.y, 3.4, 3.4).fill(r.stone_dark)
		p.begin().ellipse(c.x, c.y, 2.0, 2.0).fill(r.stone, false, false)
		var w := deg_to_rad(pose.wheel + (0.0 if cx < 15.0 else 40.0))
		p.begin().px(c.x + cos(w) * 1.6, c.y + sin(w) * 1.6, glow)
