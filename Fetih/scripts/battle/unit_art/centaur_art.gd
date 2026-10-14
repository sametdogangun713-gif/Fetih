class_name CentaurArt
## Kentaurlar: at gövdesi (MountArt, başsız) + önünden yükselen insan üst gövdesi. Role göre silah:
## okçu yay, mızrakçı/süvari kargı, büyücü (şaman) tüylü asa, savaşçı kılıç ve kalkan.
## UnitSprites'ın yardımcısıdır.
##
## Animasyon: durma 4 (at nefes alır, kuyruk sallanır, gövde hafifçe iner), yürüme 6 (dört nala,
## üst gövde ritmi izler), saldırı 6 (role göre hazırlık, vuruş, takip), ölüm 6 (ön dizler bükülür,
## at yere çöker, üst gövde geriye yığılır).

const SIZE := 32


static func frame(role: StringName, look: Dictionary, anim: int, f: int) -> Image:
	var m := MountArt.pose(anim, f)
	m.headless = true
	var tp := _pose(role, anim, f, m)
	var p := SpritePainter.new(SIZE)
	var fx := SpritePainter.new(SIZE)
	if role == RoleRules.ARCHER:  # sadak at sırtında
		var b: Array = MountArt.SPECS[&"horse"].body
		var at := Vector2(b[0] - 3 + m.x, b[1] - 6 + m.bob + roundf(m.collapse * 4.0))
		p.begin().rect(at.x, at.y, 3, 5).fill(look.r.leather)
		p.px(at.x, at.y - 1, HumanoidArt.WHITE).px(at.x + 2, at.y - 2, HumanoidArt.WHITE)
	var spots := MountArt.draw(p, look, &"horse", m)
	var waist: Vector2 = spots.waist
	if anim == UnitSprites.Anim.DEATH:
		var upper := SpritePainter.new(SIZE)
		_upper(upper, fx, role, look, waist, tp)
		var deg: float = [0.0, 12.0, 35.0, 60.0, 72.0, 72.0][f]
		var fallen := SpritePainter.turned(upper.image, deg, waist + Vector2(0.5, 0.5))
		SpritePainter.stamp(p.image, fallen)
	else:
		_upper(p, fx, role, look, waist, tp)
	SpritePainter.outline(p.image)
	SpritePainter.stamp(p.image, fx.image)
	return p.image


## Üst gövde duruşu (HumanoidArt._pose ile aynı mantık; o: gövde kayması, hand: boyuna göre el).
static func _pose(role: StringName, anim: int, f: int, m: Dictionary) -> Dictionary:
	var tp := {o = Vector2.ZERO, hand = Vector2(3, 4), back_hand = Vector2(-3, 4), angle = -60.0,
			fx = -1, pull = 0, glow = 0, hurt = false}
	match anim:
		UnitSprites.Anim.IDLE:
			tp.o = Vector2(0, [0, 0, 0, 1][f])  # at nefes alırken gövde biraz gecikmeli iner
		UnitSprites.Anim.WALK:
			tp.o = Vector2(0, roundf(0.5 * cos(m.gait)))
			tp.back_hand = Vector2(-3 + roundf(sin(m.gait)), 4)
		UnitSprites.Anim.ATTACK:
			tp.fx = f
			tp.o = Vector2([-1, -1, 1, 1, 1, 0][f], 0)
		UnitSprites.Anim.DEATH:
			tp.hurt = true
			tp.hand = Vector2(2, 0)
			tp.back_hand = Vector2(-4, 1)
	match role:
		RoleRules.WARRIOR:
			if anim == UnitSprites.Anim.ATTACK:
				tp.hand = [Vector2(-1, -3), Vector2(-2, -4), Vector2(4, 0), Vector2(5, 3), Vector2(5, 3), Vector2(3, 3)][f]
				tp.angle = [-135.0, -150.0, -15.0, 35.0, 40.0, -30.0][f]
		RoleRules.CAVALRY, RoleRules.SPEARMAN:
			tp.hand = Vector2(3, 3)
			tp.angle = -70.0 if anim != UnitSprites.Anim.WALK else -62.0 + 4.0 * sin(m.gait)
			if anim == UnitSprites.Anim.ATTACK:
				tp.hand = [Vector2(1, 2), Vector2(2, 3), Vector2(5, 3), Vector2(5, 3), Vector2(5, 3), Vector2(4, 3)][f]
				tp.angle = [-82.0, -40.0, -6.0, -3.0, -3.0, -35.0][f]
		RoleRules.ARCHER:
			tp.hand = Vector2(5, 3)
			if anim == UnitSprites.Anim.ATTACK:
				tp.o.x = [0, 0, -1, 0, 0, 0][f]
				tp.pull = [1, 2, 3, 0, 0, 0][f]
		RoleRules.MAGE:
			tp.hand = Vector2(4, 3)
			if anim == UnitSprites.Anim.ATTACK:
				tp.hand = [Vector2(3, 0), Vector2(3, -1), Vector2(5, 1), Vector2(5, 2), Vector2(5, 2), Vector2(4, 3)][f]
				tp.glow = [1, 2, 3, 2, 1, 0][f]
	if tp.hurt:
		tp.angle = -110.0
	return tp


## İnsan üst gövdesi: arka kol, gövde (bele doğru atın gövdesine kaynaşır), kafa, ön kol + silah.
static func _upper(p: SpritePainter, fx: SpritePainter, role: StringName, look: Dictionary, waist: Vector2, tp: Dictionary) -> void:
	var r: Dictionary = look.r
	p.origin = Vector2.ZERO
	var n: Vector2 = waist + Vector2(0, -5) + tp.o
	if role == RoleRules.WARRIOR and not tp.hurt:  # kalkan arka kolda
		HumanoidArt.round_shield(p, look, n + tp.back_hand + Vector2(-1, -1), true)
	HumanoidArt.arm(p, look, n + Vector2(-2, 1), n + tp.back_hand, true, true)
	# Çıplak gövde (ten) + çapraz kayış; bel at gövdesiyle birleşir.
	p.begin().rect(n.x - 3, n.y, 7, 6).cut(n.x - 3, n.y, 1, 1).cut(n.x + 3, n.y, 1, 1).fill(r.skin)
	p.begin().line(n + Vector2(-2, 0), n + Vector2(3, 4), 1.0).fill(r.leather, false, false)
	p.begin().rect(n.x - 3, n.y + 5, 7, 1).fill(r.cloth, true, false)  # bel kuşağı (birliğin rengi)
	HumanoidArt.head(p, look, n, look.get("helm_" + String(role), &"band"))
	var hand: Vector2 = n + tp.hand
	match role:
		RoleRules.WARRIOR:
			HumanoidArt.arm(p, look, n + Vector2(2, 1), hand, false, true)
			HumanoidArt.sword(p, look, hand, tp.angle)
			if tp.fx == 2:
				HumanoidArt.smear_arc(fx, hand, 9.0, -150.0, -15.0)
			elif tp.fx == 3:
				HumanoidArt.spark(fx, hand + Vector2.from_angle(deg_to_rad(tp.angle)) * 9.0)
		RoleRules.ARCHER:
			HumanoidArt.bow(p, look, hand, tp.pull, tp.pull > 0)
			HumanoidArt.arm(p, look, n + Vector2(2, 1), hand, false, true)
			if tp.pull > 0:
				HumanoidArt.arm(p, look, n + Vector2(1, 1), hand - Vector2(1 + tp.pull, 0), false, true)
		RoleRules.MAGE:
			HumanoidArt.staff(p, look, fx, hand, tp.glow)
			HumanoidArt.arm(p, look, n + Vector2(2, 1), hand, false, true)
			# asadaki tüyler
			var top := hand + Vector2(1, -5)
			p.begin().line(top, top + Vector2(-2, 2), 1.0).fill(SpritePainter.ramp(look.trim), false, false)
		_:  # süvari / mızrakçı: kargı
			var reach := lerpf(9.0, 12.0, absf(sin(deg_to_rad(tp.angle))))
			HumanoidArt.spear(p, look, hand, tp.angle, 5.0, reach, look.get("pennant", false))
			HumanoidArt.arm(p, look, n + Vector2(2, 1), hand, false, true)
			if tp.fx == 2:
				for y: int in [17, 21, 25]:
					for x in range(1, 6):
						fx.px(x + (y % 2), y, HumanoidArt.SMEAR)
			elif tp.fx == 3:
				HumanoidArt.spark(fx, hand + Vector2(0.5, 0.5) + Vector2.from_angle(deg_to_rad(tp.angle)) * (reach + 4.0))
