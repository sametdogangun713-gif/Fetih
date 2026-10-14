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
const CORPSE_FADE := 0.8  ## Piksel piksel çözülme süresi (corpse_dissolve shader'ı).
const CORPSE_FLASH := 0.1  ## Düştüğü an beyaz parlama süresi.
const CORPSE_SHADER := preload("res://assets/shaders/corpse_dissolve.gdshader")
const MAX_CORPSES := 160
const MAX_PARTICLES := 600
const FIRE := Color("ff8a30")
const MUD := Color("8a7040")
const SPARK := Color("fff2b0")
## Yeni efekt renkleri Resurrect 64 paletinden (gorsel_yon_dokumani.md, karar 3).
const R64_WHITE := Color("ffffff")
const R64_PALE := Color("c7dcd0")  ## soluk gri-yeşil: ok ucu, ruh zerresi
const R64_LEMON := Color("fbff86")  ## açık limon: kıvılcım yıldızı, düşmana hasar
const R64_GOLD := Color("f9c22b")  ## gülle patlaması
const R64_SALMON := Color("f68181")  ## oyuncuya hasar
const R64_LEAF := Color("91db69")  ## iyileşme
const R64_INK := Color("2e222f")  ## en koyu ton: yazı konturu
## Hasar / iyileşme sayıları (değerler gorsel_yon_dokumani.md 5.2).
const NUMBER_INTERVAL := 0.25  ## Bir bölüğün sayıları en sık bu aralıkla çıkar (toplanır).
const NUMBER_LIFE := 0.5
const NUMBER_FADE := 0.15  ## Son bu kadar sürede söner.
const NUMBER_POP := 0.12  ## Büyükten normale "pop" süresi.
const NUMBER_RISE := 10.0  ## Ömrü boyunca yükseldiği mesafe (piksel).
const MAX_NUMBERS := 16
const DAMAGE_TO_ENEMY := R64_LEMON
const DAMAGE_TO_PLAYER := R64_SALMON
const HEAL := R64_LEAF


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


## Vuruş yıldızı: isabet noktasında bir an parlayan artı biçimli piksel kıvılcımı.
## Parçacıklardan büyük ve parlak: tek tek 1 piksellik kıvılcımlar uzaktan seçilmiyordu.
class Impact:
	var pos: Vector2
	var time := 0.0
	var duration := 0.1
	var size := 2  ## Kolların uzunluğu (piksel).
	var color: Color


## Uçuşan sayı: önce büyük çıkar (pop), yükselir, sonunda söner.
class FloatText:
	var pos: Vector2
	var text: String
	var color: Color
	var size := 8  ## Yazı boyu (görüntü pikseli).
	var time := 0.0


## Bir bölüğün can takibi: son görülen can, biriken fark, son sayıdan beri geçen süre.
class HpTrack:
	var hp := 0.0
	var pending := 0.0
	var timer := 0.0


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
var _impacts: Array[Impact] = []
var _texts: Array[FloatText] = []
var _tracks := {}  ## SquadView -> HpTrack
var _corpse_layer := Node2D.new()  ## Cesetler: çözülme shader'ı sadece bu katmanda.
var _corpses_drawn := false
var _air_drawn := false  ## Son çizimde havada efekt var mıydı.
var _ground_drawn := false
var _rng := RandomNumberGenerator.new()
@onready var _ground: Node2D = get_parent().get_node("GroundFx")
## Autoload'lara düğüm yolundan ulaşılır: bu script Battlefield üzerinden simülasyon araçlarına
## (boss_test, upgrade_test) da bağlanıyor; araçlar (-s) "Audio" adını derleme anında tanımaz.
@onready var _audio: Node = get_node(^"/root/Audio")
@onready var _settings: Node = get_node(^"/root/Settings")


func _ready() -> void:
	_rng.randomize()
	_ground.draw.connect(_draw_ground)
	var mat := ShaderMaterial.new()
	mat.shader = CORPSE_SHADER
	_corpse_layer.material = mat
	_corpse_layer.draw.connect(_draw_corpses)
	_ground.add_child(_corpse_layer)  # GroundFx'in çocuğu: halkaların üstünde, bölüklerin altında


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
	for i in _impacts.duplicate():
		i.time += delta
		if i.time >= i.duration:
			_impacts.erase(i)
	for t in _texts.duplicate():
		t.time += delta
		if t.time >= NUMBER_LIFE:
			_texts.erase(t)
	_update_numbers(delta)
	# Boşken yeniden çizme (performans): son efekt bittiği karede bir kez daha çizilir ki silinsin.
	var air := not (_projectiles.is_empty() and _particles.is_empty() and _impacts.is_empty()
			and _texts.is_empty())
	if air or _air_drawn:
		queue_redraw()
	_air_drawn = air
	var ground := not _rings.is_empty()
	if ground or _ground_drawn:
		_ground.queue_redraw()
	_ground_drawn = ground
	var corpses := not _corpses.is_empty()
	if corpses or _corpses_drawn:
		_corpse_layer.queue_redraw()
	_corpses_drawn = corpses


func clear() -> void:
	_projectiles.clear()
	_particles.clear()
	_corpses.clear()
	_rings.clear()
	_impacts.clear()
	_texts.clear()
	_tracks.clear()


## Bölüğün canını izlemeye başla (hasar / iyileşme sayıları için). battle_controller çağırır.
func track(view: SquadView) -> void:
	var t := HpTrack.new()
	t.hp = view.squad.hp_pool
	_tracks[view] = t


# --- Olaylar (battle_controller çağırır) ---

## Yakın dövüş vuruşu: hedefte kıvılcım, ağır birliklerde (boss, tank, süvari) daha sert ses.
func melee_hit(attacker: SquadView, target: SquadView) -> void:
	target.flash()
	var at := target.random_soldier_position(_rng)
	var unit := attacker.squad.unit
	var heavy := unit.is_boss or unit.role == RoleRules.TANK or unit.role == RoleRules.CAVALRY
	_impact(at, 3 if heavy else 2, R64_LEMON)
	_burst(at, 6 if heavy else 4, SPARK, 70.0, 0.22, 1.0, 2.0)
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
	_burst(at + Vector2(0, -5), 5, view.squad.unit.placeholder_color.darkened(0.45), 45.0, 0.4)
	# İki soluk ışık zerresi yükselir: düşüş uzaktan da fark edilsin.
	for i in 2:
		var p := _particle(at + Vector2(_rng.randf_range(-3, 3), -4),
				Vector2(_rng.randf_range(-6, 6), -_rng.randf_range(18, 30)), R64_PALE, 0.5)
		p.gravity = -0.05
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
		_shake(1.5)


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
			_impact(p.to, 1, R64_PALE)
			_burst(p.to, 2, Color("c8b890"), 30.0, 0.2)
			_audio.play("arrow_hit", -9.0)
		Kind.BOLT:
			_impact(p.to, 3, p.color.lightened(0.4))
			_burst(p.to, 8, p.color, 60.0, 0.35, 1.0, 2.0)
			_audio.play("magic_hit", -5.0)
		Kind.BALL:
			_impact(p.to, 4, R64_GOLD)
			_burst(p.to, 14, FIRE, 90.0, 0.45, 1.0, 2.0)
			_burst(p.to, 8, Color("6a6058"), 50.0, 0.7, 0.1)
			_audio.play("explosion", -4.0)
			_shake(1.5)
	if p.splash > 0.0:
		_ring(p.to + Vector2(0, 6), p.splash, 0.35, p.color)


## big_size: iri parçacığın boyu (piksel). Parçacıkların %30'u iri, kalanı 1 piksel.
func _burst(at: Vector2, count: int, color: Color, speed: float, life: float, gravity := 1.0,
		big_size := 2.0) -> void:
	for i in count:
		var angle := _rng.randf_range(-PI, 0.0)  # yukarı yarım daire
		var p := _particle(at, Vector2.from_angle(angle) * _rng.randf_range(speed * 0.4, speed),
				color, life * _rng.randf_range(0.6, 1.0))
		p.gravity = gravity
		p.size = big_size if _rng.randf() < 0.3 else 1.0


## Canı değişen bölüklerin üstünde sayı çıkar. Simülasyon hasar miktarını bildirmez; sayı
## SquadState.hp_pool'un karelere göre farkından okunur (sadece okuma: sonuç değişmez).
## Farklar NUMBER_INTERVAL boyunca toplanır: her ok için ayrı sayı ekranı doldururdu.
func _update_numbers(delta: float) -> void:
	for view: SquadView in _tracks:
		if not is_instance_valid(view):
			continue
		var t: HpTrack = _tracks[view]
		var hp := view.squad.hp_pool
		t.pending += t.hp - hp  # artı: hasar, eksi: iyileşme
		t.hp = hp
		t.timer += delta
		if absf(t.pending) < 1.0 or (t.timer < NUMBER_INTERVAL and hp > 0.0):
			continue
		if _settings.damage_numbers:
			_spawn_number(view, t.pending)
		t.pending = 0.0
		t.timer = 0.0


func _spawn_number(view: SquadView, amount: float) -> void:
	var f := FloatText.new()
	var value := roundi(absf(amount))
	# Sancağın sağına ya da soluna: ortadaki asker sayısının üstüne binmesin.
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	f.pos = (view.center() + Vector2(side * _rng.randf_range(14.0, 22.0), -6.0)).round()
	if amount < 0.0:
		f.text = "+%d" % value
		f.color = HEAL
	else:
		f.text = "-%d" % value
		f.color = DAMAGE_TO_PLAYER if view.squad.team == SquadState.Team.PLAYER else DAMAGE_TO_ENEMY
	# İki askerden fazlasını bir anda götüren darbe iri yazılır.
	f.size = 10 if absf(amount) >= view.squad.unit.hp * 2.0 else 8
	_texts.append(f)
	if _texts.size() > MAX_NUMBERS:
		_texts.pop_front()


func _impact(at: Vector2, size: int, color: Color) -> void:
	var i := Impact.new()
	i.pos = at.round()
	i.size = size
	i.color = color
	i.duration = 0.06 + size * 0.02
	_impacts.append(i)


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
	for i in _impacts:
		# İlk yarıda beyaz çekirdek + renkli kollar; ikinci yarıda kollar kısalır ve söner.
		var t := i.time / i.duration
		var arm := maxi(roundi(i.size * (1.0 - t * 0.5)), 1)
		var c := i.color
		c.a = 1.0 - t * t
		draw_rect(Rect2(i.pos + Vector2(-arm, 0), Vector2(arm * 2 + 1, 1)), c)
		draw_rect(Rect2(i.pos + Vector2(0, -arm), Vector2(1, arm * 2 + 1)), c)
		if t < 0.5:
			draw_rect(Rect2(i.pos, Vector2.ONE), R64_WHITE)
	_draw_numbers()


## Tween.interpolate_value: Tween düğümü oluşturmadan aynı yumuşatma eğrilerini (TRANS_BACK,
## TRANS_QUAD...) elle hesaplar. Onlarca sayı için onlarca Tween yaratmak yerine tek döngü.
func _draw_numbers() -> void:
	var font := ThemeDB.fallback_font
	for f in _texts:
		var scale: float = Tween.interpolate_value(1.8, -0.8, minf(f.time, NUMBER_POP), NUMBER_POP,
				Tween.TRANS_BACK, Tween.EASE_OUT)
		var rise: float = Tween.interpolate_value(0.0, -NUMBER_RISE, f.time, NUMBER_LIFE,
				Tween.TRANS_QUAD, Tween.EASE_OUT)
		var fade := clampf((NUMBER_LIFE - f.time) / NUMBER_FADE, 0.0, 1.0)
		var width := font.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, f.size).x
		draw_set_transform(f.pos + Vector2(0, roundf(rise)), 0.0, Vector2(scale, scale))
		var at := Vector2(-width / 2.0, 0.0)
		draw_string_outline(font, at, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, f.size, 3,
				Color(R64_INK, 0.9 * fade))
		var c := f.color
		c.a = fade
		draw_string(font, at, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, f.size, c)
	draw_set_transform(Vector2.ZERO)


## Cesetler (çözülme shader'lı katman). Çizim rengi veri taşır: r = beyazlık, a = kalan
## miktar (bkz. corpse_dissolve.gdshader). Soluk ton shader'ın tint parametresinde.
func _draw_corpses() -> void:
	for c in _corpses:
		var keep := 1.0 - clampf((c.time - CORPSE_STAY) / CORPSE_FADE, 0.0, 1.0)
		var white := clampf(1.0 - c.time / CORPSE_FLASH, 0.0, 1.0)
		var size := Vector2(c.sheet.frame_size)
		var dest := Rect2(Vector2(-size.x / 2.0, 1.0 - size.y), size)
		# Sola bakan asker x'te -1 ölçekle çevrilir (bkz. SquadView._draw_soldier).
		# Devrilme ölüm satırının karelerinde.
		_corpse_layer.draw_set_transform(c.pos, 0.0, Vector2(-1.0 if c.flip else 1.0, 1.0))
		_corpse_layer.draw_texture_rect_region(c.sheet.texture, dest,
				c.sheet.region(UnitSprites.Anim.DEATH,
				int(c.time / CORPSE_FALL * c.sheet.count(UnitSprites.Anim.DEATH))),
				Color(white, 0.0, 0.0, keep))
	_corpse_layer.draw_set_transform(Vector2.ZERO)


func _draw_ground() -> void:
	for r in _rings:
		var t := r.time / r.duration
		var c := r.color
		c.a = 1.0 - t
		# İzometrik zemin üstünde daire = yassı elips.
		_ground.draw_set_transform(r.pos, 0.0, Vector2(1.0, 0.5))
		_ground.draw_arc(Vector2.ZERO, r.radius * (0.3 + 0.7 * t), 0.0, TAU, 32, c, 1.5)
	_ground.draw_set_transform(Vector2.ZERO)
