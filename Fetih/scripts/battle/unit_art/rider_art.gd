class_name RiderArt
## Atlılar: binek (MountArt) + kargılı binici (HumanoidArt parçaları). UnitSprites'ın yardımcısıdır.
## Krallığa göre binek: insan şövalyesi at, elf geyik, ork kurt, ölü şövalye iskelet at
## (UnitSprites.KINGDOM_LOOKS -> mount).
##
## Animasyon: durma 4 (binek nefes alır, başını indirir, kuyruk sallanır), yürüme 6 (dört nala,
## binici bineğin inip kalkmasını izler, kargı hafifçe sallanır), saldırı 6 (kargı geri kalkar,
## indirilir, binek ileri atılır, vuruş kıvılcımı, hız çizgileri), ölüm 6 (binek dizleri bükülüp
## çöker, binici geriye düşüp yere serilir).

const SIZE := 32


static func frame(look: Dictionary, anim: int, f: int) -> Image:
	var kind: StringName = look.mount
	var m := MountArt.pose(anim, f)
	var rp := _pose(anim, f, m)
	var p := SpritePainter.new(SIZE)
	var fx := SpritePainter.new(SIZE)
	var at := MountArt.draw(p, look, kind, m)
	if anim == UnitSprites.Anim.DEATH:
		# Binici ayrı katmanda çizilir, eyer noktası etrafında geriye devrilir.
		var rider := SpritePainter.new(SIZE)
		var seat: Vector2 = MountArt.SPECS[kind].saddle + Vector2(m.x, 0)
		_rider(rider, fx, look, seat, null, rp)
		var deg: float = [0.0, 20.0, 55.0, 85.0, 90.0, 90.0][f]
		var shift := Vector2([0.0, -1.0, -3.0, -5.0, -6.0, -6.0][f], [0.0, 1.0, 3.0, 0.0, 0.0, 0.0][f])
		var ground := -1
		if f >= 3:
			ground = 29 - (1 if f == 4 else 0)  # yere çarpıp bir piksel seker
		var fallen := SpritePainter.turned(rider.image, deg, seat + Vector2(0.5, 0.5), shift, ground)
		SpritePainter.stamp(p.image, fallen)
	else:
		_rider(p, fx, look, at.saddle, at.mouth, rp)
	SpritePainter.outline(p.image)
	SpritePainter.stamp(p.image, fx.image)
	return p.image


## Binici duruşu: o (gövde kayması), hand (boyuna göre ön el), angle (kargı açısı), fx (saldırı evresi).
static func _pose(anim: int, f: int, m: Dictionary) -> Dictionary:
	var rp := {o = Vector2.ZERO, hand = Vector2(3, 3), angle = -72.0, fx = -1, hurt = false}
	match anim:
		UnitSprites.Anim.IDLE:
			rp.angle = [-72.0, -72.0, -70.0, -70.0][f]
		UnitSprites.Anim.WALK:
			rp.angle = -64.0 + 4.0 * sin(m.gait)
			rp.o = Vector2(0, roundf(0.5 * cos(m.gait)))  # binici bineğin hareketini yumuşak izler
		UnitSprites.Anim.ATTACK:
			rp.fx = f
			rp.o = Vector2([-1, -1, 1, 1, 1, 0][f], 0)
			rp.hand = [Vector2(1, 2), Vector2(2, 3), Vector2(5, 3), Vector2(5, 3), Vector2(5, 3), Vector2(4, 3)][f]
			rp.angle = [-82.0, -40.0, -6.0, -3.0, -3.0, -35.0][f]
		UnitSprites.Anim.DEATH:
			rp.hurt = true
			rp.o = Vector2(-1, 0)
			rp.hand = Vector2(1, -1)
			rp.angle = -110.0
	return rp


## Binici: eyer, bacak, arka kol + dizgin, gövde, kafa, ön kol ve kargı.
static func _rider(p: SpritePainter, fx: SpritePainter, look: Dictionary, saddle: Vector2, mouth: Variant, rp: Dictionary) -> void:
	var r: Dictionary = look.r
	p.origin = Vector2.ZERO
	var n: Vector2 = saddle + Vector2(0, -5) + rp.o
	# Eyer.
	p.begin().rect(saddle.x - 3, saddle.y - 1, 7, 2).fill(r.leather)
	p.begin().rect(saddle.x - 2, saddle.y + 1, 5, 1).fill(r.trim, false)
	# Arka kol dizgini tutar.
	var rein_hand: Vector2 = n + Vector2(3, 4)
	HumanoidArt.arm(p, look, n + Vector2(-2, 1), rein_hand, true)
	if mouth != null and not rp.hurt:
		p.begin().line(rein_hand + Vector2(1, 0), mouth, 1.0).fill(r.leather, false, false)
	# Gövde ve yakın bacak (diz önde, ayak üzengide).
	HumanoidArt.torso(p, look, n)
	var hip := n + Vector2(0, 4)
	var knee := hip + Vector2(3, 1)
	var foot := knee + Vector2(-1, 3)
	p.begin().line(hip, knee, 2.2).line(knee, foot, 1.9).fill(r.pants)
	p.begin().rect(foot.x - 1, foot.y, 3, 1).fill(r.boots)
	HumanoidArt.head(p, look, n, look.get("rider_helm", &"open"))
	# Kargı ve ön kol.
	var hand: Vector2 = n + rp.hand
	var reach := lerpf(9.0, 12.0, absf(sin(deg_to_rad(rp.angle))))  # dik tutulunca daha uzun görünür
	HumanoidArt.spear(p, look, hand, rp.angle, 5.0, reach, look.get("pennant", false))
	HumanoidArt.arm(p, look, n + Vector2(2, 1), hand)
	match int(rp.fx):
		2:  # hız çizgileri: binek ileri atılır
			for y: int in [17, 21, 25]:
				for x in range(1, 6):
					fx.px(x + (y % 2), y, HumanoidArt.SMEAR)
		3:  # kargı ucunda vuruş
			HumanoidArt.spark(fx, hand + Vector2(0.5, 0.5) + Vector2.from_angle(deg_to_rad(rp.angle)) * (reach + 4.0))
