class_name BattleFx
extends Node2D
## Savaşın görsel efektleri: oklar, büyü mermileri, gülleler, kıvılcım parçacıkları,
## düşen askerler, patlama halkaları; efektle aynı anda çalan sesler.
## Sadece görüntüdür: simülasyonu etkilemez, kendi rastgeleliğini kullanır.
##
## İki katmanda çizer: yerdekiler (cesetler, halkalar) bölüklerin altında kalsın diye
## GroundFx düğümüne, havadakiler (mermiler, parçacıklar) bölüklerin üstüne (bu düğüm).

enum Kind { ARROW, BOLT, BALL }

const GRAVITY := 260.0  ## Parçacıklar için (piksel/sn²).
const ARROW_SPEED := 260.0  ## piksel/sn
const BOLT_SPEED := 170.0
const CORPSE_FALL := 0.36  ## Ölüm animasyonunun süresi (ölüm satırının bütün kareleri).
const CORPSE_STAY := 1.4  ## Yerde kalma süresi (sonra solar).
const CORPSE_FADE := 0.8
const MAX_CORPSES := 160
const MAX_PARTICLES := 600
const FIRE := Color("ff8a30")
const MUD := Color("8a7040")
const SPARK := Color("fff2b0")


class Projectile:
	var kind: Kind
	var from: Vector2
	var to: Vector2
	var time := 0.0  ## Negatifse henüz atılmadı (yaylım ateşinde küçük gecikmeler).
	var duration := 0.5
	var arc := 0.0  ## Yayın tepe yüksekliği (piksel).
	var color: Color
	var target: SquadView
	var splash := 0.0  ## Alan hasarı yarıçapı (piksel); inişte halka çizilir.

	func point(t: float) -> Vector2:
		return from.lerp(to, t) + Vector2(0, -arc * 4.0 * t * (1.0 - t))


class Particle:
	var pos: Vector2
	var vel: Vector2
	var life := 0.0
	var max_life := 0.5
	var color: Color
	var size := 1.0
	var gravity := 1.0  ## Yerçekimi çarpanı (eksi: yükselir).


class Corpse:
	var sheet: UnitSprites.Sheet
	var pos: Vector2
	var flip := false
	var time := 0.0


class Ring:
	var pos: Vector2
	var radius := 10.0
	var time := 0.0
	var duration := 0.35
	var color: Color


var camera: BattleCamera  ## Sarsıntı için; battle_controller atar.

var _projectiles: Array[Projectile] = []
var _particles: Array[Particle] = []
var _corpses: Array[Corpse] = []
var _rings: Array[Ring] = []
var _rng := RandomNumberGenerator.new()
@onready var _ground: Node2D = get_parent().get_node("GroundFx")
## Autoload'lara düğüm yolundan ulaşılır: bu script Battlefield üzerinden simülasyon araçlarına
## (boss_test, upgrade_test) da bağlanıyor; araçlar (-s) "Audio" adını derleme anında tanımaz.
@onready var _audio: Node = get_node(^"/root/Audio")
@onready var _settings: Node = get_node(^"/root/Settings")


func _ready() -> void:
	_rng.randomize()
	_ground.draw.connect(_draw_ground)


## Her karede çağrılır; delta savaş hızıyla çarpılmıştır.
func advance(delta: float) -> void:
	for p in _projectiles.duplicate():
		p.time += delta
		if p.time >= p.duration:
			_projectiles.erase(p)
			_land(p)
	for p in _particles.duplicate():
		p.life += delta
		if p.life >= p.max_life:
			_particles.erase(p)
			continue
		p.vel.y += GRAVITY * p.gravity * delta
		p.pos += p.vel * delta
	for c in _corpses.duplicate():
		c.time += delta
		if c.time >= CORPSE_STAY + CORPSE_FADE:
			_corpses.erase(c)
	for r in _rings.duplicate():
		r.time += delta
		if r.time >= r.duration:
			_rings.erase(r)
	queue_redraw()
	_ground.queue_redraw()


func clear() -> void:
	_projectiles.clear()
	_particles.clear()
	_corpses.clear()
	_rings.clear()


# --- Olaylar (battle_controller çağırır) ---

## Yakın dövüş vuruşu: hedefte kıvılcım, ağır birliklerde (boss, tank, süvari) daha sert ses.
func melee_hit(attacker: SquadView, target: SquadView) -> void:
	target.flash()
	var at := target.random_soldier_position(_rng)
	_burst(at, 3, SPARK, 50.0, 0.18)
	var unit := attacker.squad.unit
	if unit.is_boss:
		_audio.play("hit_heavy", 0.0)
		_shake(2.5)
	elif unit.role == RoleRules.TANK or unit.role == RoleRules.CAVALRY:
		_audio.play("hit_heavy", -6.0)
	else:
		_audio.play("hit", -3.0)


## Uzak saldırı: rolüne göre oklar, büyü mermisi ya da gülle fırlatır. Hasar simülasyonda
## çoktan uygulandı; mermi sadece görüntüdür, inince hedef parlar.
func launch(attacker: SquadView, target: SquadView) -> void:
	var unit := attacker.squad.unit
	var kind := Kind.ARROW
	var count := mini(attacker.squad.alive_count(), 4)
	match unit.role:
		RoleRules.MAGE:
			kind = Kind.BOLT
			count = 1 if attacker.squad.alive_count() < 6 else 2
		RoleRules.SIEGE:
			kind = Kind.BALL
			count = 1
	if unit.is_boss:
		count = 1 if kind == Kind.BALL else 3
	var color := unit.placeholder_color.lightened(0.5)
	if unit.burn_ratio > 0.0:
		color = FIRE
	elif unit.slow_amount > 0.0:
		color = MUD
	for i in count:
		var p := Projectile.new()
		p.kind = kind
		p.from = attacker.random_soldier_position(_rng)
		p.to = target.random_soldier_position(_rng)
		p.target = target
		p.color = color
		p.time = -_rng.randf_range(0.0, 0.12) * i
		var distance := p.from.distance_to(p.to)
		match kind:
			Kind.ARROW:
				p.duration = distance / ARROW_SPEED
				p.arc = distance * 0.18
			Kind.BOLT:
				p.duration = distance / BOLT_SPEED
				p.arc = distance * 0.06
			Kind.BALL:
				p.duration = 0.55 + distance / 450.0
				p.arc = distance * 0.35 + 10.0
		p.duration = maxf(p.duration, 0.08)
		if unit.splash_radius > 0.0:
			p.splash = unit.splash_radius * Battlefield.TILE_HALF.x
		_projectiles.append(p)
	match kind:
		Kind.ARROW:
			_audio.play("arrow", -7.0)
		Kind.BOLT:
			_audio.play("magic", -5.0)
		Kind.BALL:
			_audio.play("cannon", -2.0)
			_burst(attacker.center() + Vector2(6 if not attacker.flip else -6, 0), 5,
					Color("b0aaa0"), 30.0, 0.5, -0.2)


## Bir asker düştü: yere yığılan beden ve birkaç damla.
func soldier_died(view: SquadView, at: Vector2) -> void:
	var c := Corpse.new()
	c.sheet = view.sheet
	c.pos = at
	c.flip = view.flip
	_corpses.append(c)
	if _corpses.size() > MAX_CORPSES:
		_corpses.pop_front()
	_burst(at + Vector2(0, -5), 4, view.squad.unit.placeholder_color.darkened(0.45), 40.0, 0.35)
	_audio.play("death", -9.0, 0.15, 0.09)


## Bölük tamamen yok oldu: toz bulutu ve halka. Boss düşünce büyük sarsıntı.
func squad_down(view: SquadView) -> void:
	var at := view.position
	_ring(at, 26.0, 0.5, Color("d8c8a0"))
	_burst(at + Vector2(0, -4), 14, Color("a89878"), 60.0, 0.6, 0.2)
	if view.squad.unit.is_boss:
		_burst(view.center(), 24, FIRE, 110.0, 0.8)
		_ring(at, 50.0, 0.7, UiKit.COLOR_GOLD)
		_audio.play("explosion")
		_shake(7.0)
	else:
		_audio.play("squad_down", -3.0)


## Ölüler dirildi: yükselen ışık parçacıkları.
func revive(view: SquadView) -> void:
	var glow := view.squad.unit.placeholder_color.lightened(0.6)
	_ring(view.position, 22.0, 0.6, glow)
	for i in 18:
		var p := _particle(view.position + Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-4, 4)),
				Vector2(0, -_rng.randf_range(15, 40)), glow, _rng.randf_range(0.6, 1.0))
		p.gravity = -0.05
	_audio.play("revive", -2.0)


## Slime bölündü: etrafa jöle sıçrar.
func split(view: SquadView) -> void:
	_burst(view.center(), 10, view.squad.unit.placeholder_color, 70.0, 0.45)
	_audio.play("split", -3.0)


# --- İç işler ---

func _land(p: Projectile) -> void:
	if p.target and p.target.visible:
		p.target.flash()
	match p.kind:
		Kind.ARROW:
			_burst(p.to, 2, Color("c8b890"), 30.0, 0.2)
			_audio.play("arrow_hit", -9.0)
		Kind.BOLT:
			_burst(p.to, 8, p.color, 60.0, 0.35)
			_audio.play("magic_hit", -5.0)
		Kind.BALL:
			_burst(p.to, 14, FIRE, 90.0, 0.45)
			_burst(p.to, 8, Color("6a6058"), 50.0, 0.7, 0.1)
			_audio.play("explosion", -4.0)
			_shake(1.5)
	if p.splash > 0.0:
		_ring(p.to + Vector2(0, 6), p.splash, 0.35, p.color)


func _burst(at: Vector2, count: int, color: Color, speed: float, life: float, gravity := 1.0) -> void:
	for i in count:
		var angle := _rng.randf_range(-PI, 0.0)  # yukarı yarım daire
		var p := _particle(at, Vector2.from_angle(angle) * _rng.randf_range(speed * 0.4, speed),
				color, life * _rng.randf_range(0.6, 1.0))
		p.gravity = gravity
		p.size = 2.0 if _rng.randf() < 0.3 else 1.0


func _particle(at: Vector2, vel: Vector2, color: Color, life: float) -> Particle:
	var p := Particle.new()
	p.pos = at
	p.vel = vel
	p.color = color
	p.max_life = life
	_particles.append(p)
	if _particles.size() > MAX_PARTICLES:
		_particles.pop_front()
	return p


func _ring(at: Vector2, radius: float, duration: float, color: Color) -> void:
	var r := Ring.new()
	r.pos = at
	r.radius = radius
	r.duration = duration
	r.color = color
	_rings.append(r)


func _shake(strength: float) -> void:
	if camera and _settings.screen_shake:
		camera.shake(strength)


func _draw() -> void:
	for p in _projectiles:
		if p.time < 0.0:
			continue
		var t := p.time / p.duration
		var at := p.point(t).round()
		match p.kind:
			Kind.ARROW:
				var back := p.point(maxf(t - 0.06, 0.0))
				var dir := (at - back).normalized()
				draw_line(at - dir * 5.0, at, Color("8a6a46"), 1.0)
				draw_rect(Rect2(at, Vector2.ONE), Color("e0e0e0"))
			Kind.BOLT:
				for k in 3:  # iz
					var trail := p.point(maxf(t - 0.05 * (k + 1), 0.0)).round()
					var c := p.color
					c.a = 0.5 - k * 0.15
					draw_rect(Rect2(trail - Vector2.ONE, Vector2(2, 2)), c)
				draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), p.color)
				draw_rect(Rect2(at, Vector2.ONE), Color.WHITE)
			Kind.BALL:
				draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), Color("242020"))
				draw_rect(Rect2(at - Vector2(1, 1), Vector2.ONE), Color("6a6460"))
	for p in _particles:
		var c := p.color
		c.a = 1.0 - pow(p.life / p.max_life, 2.0)
		draw_rect(Rect2(p.pos.round(), Vector2(p.size, p.size)), c)


func _draw_ground() -> void:
	for c in _corpses:
		var alpha := 1.0 - clampf((c.time - CORPSE_STAY) / CORPSE_FADE, 0.0, 1.0)
		var size := Vector2(c.sheet.frame_size)
		var dest := Rect2(Vector2(-size.x / 2.0, 1.0 - size.y), size)
		# Sola bakan asker x'te -1 ölçekle çevrilir (bkz. SquadView._draw_soldier).
		# Devrilme ölüm satırının karelerinde.
		_ground.draw_set_transform(c.pos, 0.0, Vector2(-1.0 if c.flip else 1.0, 1.0))
		_ground.draw_texture_rect_region(c.sheet.texture, dest, c.sheet.region(UnitSprites.Anim.DEATH,
				int(c.time / CORPSE_FALL * c.sheet.count(UnitSprites.Anim.DEATH))),
				Color(0.55, 0.5, 0.5, alpha))
	_ground.draw_set_transform(Vector2.ZERO)
	for r in _rings:
		var t := r.time / r.duration
		var c := r.color
		c.a = 1.0 - t
		# İzometrik zemin üstünde daire = yassı elips.
		_ground.draw_set_transform(r.pos, 0.0, Vector2(1.0, 0.5))
		_ground.draw_arc(Vector2.ZERO, r.radius * (0.3 + 0.7 * t), 0.0, TAU, 32, c, 1.5)
	_ground.draw_set_transform(Vector2.ZERO)
