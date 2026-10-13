class_name BattleSimulation
extends RefCounted
## Savaşın kuralları. Görüntüden bağımsız ve deterministiktir:
## aynı bölükler + aynı seed = her zaman aynı sonuç.
## Ekran olmadan da çalışır; denge testi (tools/balance_test.gd) bunu kullanır.

signal squad_attacked(attacker: SquadState, target: SquadState)
signal squad_destroyed(squad: SquadState)
signal squad_spawned(squad: SquadState)  ## Bölünmeden yeni bölük doğdu (görüntü eklenmeli).
signal squad_revived(squad: SquadState)
signal battle_finished(winner: SquadState.Team)

const TICK := 1.0 / 30.0  ## Bir simülasyon adımının süresi (saniye).
const SQUAD_RADIUS := 0.5  ## Bölüklerin birbirine girmemesi için yarıçap (karo).
## Zırh hasarı armor / (armor + ARMOR_SCALE) oranında azaltır: 5 zırh = %50, 10 zırh = %67.
const ARMOR_SCALE := 5.0
const MAX_DURATION := 120.0  ## Bu süre dolarsa toplam canı fazla olan taraf kazanır.
const MELEE_GAP := 0.6  ## Bu mesafenin altındaki çatışma yakın dövüş sayılır (karo).
const RANGED_MELEE_PENALTY := 0.5  ## Okçu/büyücü yakın dövüşe yakalanırsa hasarı bu oranla çarpılır.
const CHARGE_DISTANCE := 2.0  ## Hücum için son saldırıdan beri koşulması gereken mesafe (karo).
const SPLASH_RATIO := 0.5  ## Alan hasarında yandaki bölüklere giden hasar oranı.
## Menzil karşılaştırmasındaki tolerans. Olmazsa ondalık yuvarlama yüzünden (0.2500001 > 0.25)
## bölük menzil sınırında takılı kalır: ne ilerler ne vurur.
const RANGE_EPSILON := 0.01
const BURN_DURATION := 3.0  ## Yanmanın süresi (saniye).
const SLOW_DURATION := 2.0  ## Yavaşlatmanın süresi (saniye).
const SPLIT_OFFSET := 0.6  ## Bölünen iki yarının ana bölükten yana uzaklığı (karo).

var squads: Array[SquadState] = []
var field_rect: Rect2  ## Bölüklerin çıkamayacağı alan (savaş alanı koordinatı).
var elapsed := 0.0
var finished := false
var winner: SquadState.Team

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int, p_field_rect: Rect2) -> void:
	_rng.seed = seed_value
	field_rect = p_field_rect


func add_squad(squad: SquadState) -> void:
	# Herkes aynı anda vurmasın diye ilk saldırıya küçük bir gecikme.
	squad.attack_cooldown = _rng.randf_range(0.0, 1.0 / squad.unit.attack_speed)
	squads.append(squad)


## Savaş atılmadan önce çağrılmalı. Bölükler birbirini hedef olarak tuttuğu için
## (A -> B -> A) referans döngüsü oluşur ve bellekten silinemezler; bu döngüyü kırar.
func dispose() -> void:
	for squad in squads:
		squad.target = null
	squads.clear()


func step() -> void:
	if finished:
		return
	elapsed += TICK
	for squad in squads:
		squad.previous_position = squad.position

	# Hasarlar önce toplanır, adım sonunda birlikte uygulanır.
	# Böylece listede önce gelen bölük "ilk vuran" avantajı kazanmaz.
	var pending_damage := {}
	_apply_effects(pending_damage)
	for squad in squads.duplicate():  # bölünme listeye bölük ekleyebilir
		if squad.is_alive():
			_update_squad(squad, pending_damage)
	for target: SquadState in pending_damage:
		var was_alive := target.is_alive()
		target.take_damage(pending_damage[target])
		if was_alive and not target.is_alive():
			_on_squad_down(target)

	_separate_squads()
	_check_end()


## Süreli etkiler: yanma hasarı (zırhsız), yavaşlatma süresi, onarım.
func _apply_effects(pending_damage: Dictionary) -> void:
	for squad in squads:
		if not squad.is_alive():
			continue
		if squad.burn_time > 0.0:
			_add_damage(pending_damage, squad, squad.burn_dps * TICK)
			squad.burn_time -= TICK
		if squad.slow_time > 0.0:
			squad.slow_time -= TICK
		if squad.unit.regen_ratio > 0.0:
			squad.hp_pool = minf(squad.hp_pool + squad.max_hp * squad.unit.regen_ratio * TICK, squad.max_hp)


## Bölük yok oldu: diriliş hakkı varsa geri kalkar, bölünebiliyorsa ikiye ayrılır.
func _on_squad_down(squad: SquadState) -> void:
	if squad.unit.revive_ratio > 0.0 and not squad.revived:
		squad.revived = true
		squad.hp_pool = squad.max_hp * squad.unit.revive_ratio
		squad.burn_time = 0.0
		squad_revived.emit(squad)
		return
	squad_destroyed.emit(squad)
	if squad.unit.splits and not squad.is_split_child:
		var half_unit: UnitData = squad.unit.duplicate()
		half_unit.hp *= 0.5
		half_unit.damage *= 0.5
		var side := Vector2(-squad.facing.y, squad.facing.x)
		for dir in [-1.0, 1.0]:
			var child := SquadState.new(half_unit, squad.team, maxi(1, ceili(squad.max_count / 2.0)),
					(squad.position + side * dir * SPLIT_OFFSET).clamp(field_rect.position, field_rect.end))
			child.previous_position = child.position
			child.facing = squad.facing
			child.toughness = squad.toughness
			child.level = squad.level
			child.is_split_child = true
			add_squad(child)
			squad_spawned.emit(child)


func _update_squad(squad: SquadState, pending_damage: Dictionary) -> void:
	var speed := squad.speed_multiplier()
	squad.attack_cooldown = maxf(squad.attack_cooldown - TICK * speed, 0.0)
	if squad.target == null or not squad.target.is_alive():
		squad.target = _pick_target(squad)
	if squad.target == null:
		return

	# Kararlar adımın başındaki konumlara göre verilir (previous_position); böylece
	# listede önce güncellenen bölüğün hareketi diğerlerinin kararını etkilemez.
	var to_target := squad.target.previous_position - squad.position
	var distance := to_target.length()
	if distance > 0.001:
		squad.facing = to_target / distance

	# Menzil iki bölüğün kenarları arasında ölçülür.
	var gap := distance - 2.0 * SQUAD_RADIUS
	if gap > squad.unit.attack_range + RANGE_EPSILON:
		var move := minf(squad.unit.move_speed * speed * TICK, gap - squad.unit.attack_range)
		squad.position += squad.facing * move
		squad.distance_since_attack += move
		return

	if squad.attack_cooldown <= 0.0:
		_attack(squad, gap, pending_damage)


func _attack(squad: SquadState, gap: float, pending_damage: Dictionary) -> void:
	var unit := squad.unit
	var target := squad.target
	var multiplier := _rng.randf_range(0.9, 1.1)
	if unit.is_ranged() and gap <= MELEE_GAP:
		multiplier *= RANGED_MELEE_PENALTY
	# Hücum: koşarak gelen ilk vuruş güçlüdür. Mızrakçılar hücumu karşılar.
	if unit.charge_multiplier > 1.0 and squad.distance_since_attack >= CHARGE_DISTANCE \
			and target.unit.role != RoleRules.SPEARMAN:
		multiplier *= unit.charge_multiplier
	squad.distance_since_attack = 0.0

	var soldiers := squad.alive_count()
	var hit := damage_per_soldier(unit, target.unit) * soldiers * multiplier
	_add_damage(pending_damage, target, hit)
	if unit.burn_ratio > 0.0:
		target.burn_dps = maxf(target.burn_dps if target.burn_time > 0.0 else 0.0,
				hit * unit.burn_ratio / BURN_DURATION)
		target.burn_time = BURN_DURATION
	if unit.slow_amount > 0.0:
		target.slow = maxf(target.slow if target.slow_time > 0.0 else 0.0, minf(unit.slow_amount, 0.8))
		target.slow_time = SLOW_DURATION

	if unit.splash_radius > 0.0:
		for other in squads:
			if other == target or other.team == squad.team or not other.is_alive():
				continue
			if other.previous_position.distance_to(target.previous_position) <= unit.splash_radius:
				var splash := damage_per_soldier(unit, other.unit) * soldiers * multiplier * SPLASH_RATIO
				_add_damage(pending_damage, other, splash)

	squad.attack_cooldown = 1.0 / unit.attack_speed
	squad_attacked.emit(squad, target)


## Bir askerin bu hedefe bir vuruşta verdiği hasar: karşılık bonusu, sonra zırh.
static func damage_per_soldier(attacker: UnitData, target: UnitData) -> float:
	var damage := attacker.damage
	if RoleRules.has_advantage(attacker.role, target.role):
		damage *= RoleRules.COUNTER_BONUS
	if attacker.ignores_armor:
		return damage
	return damage * (1.0 - target.armor / (target.armor + ARMOR_SCALE))


func _add_damage(pending_damage: Dictionary, target: SquadState, amount: float) -> void:
	pending_damage[target] = pending_damage.get(target, 0.0) + amount


func _pick_target(squad: SquadState) -> SquadState:
	if squad.unit.prefers_ranged_targets:
		var ranged := _nearest_enemy(squad, true)
		if ranged:
			return ranged
	return _nearest_enemy(squad, false)


func _nearest_enemy(squad: SquadState, ranged_only: bool) -> SquadState:
	var best: SquadState = null
	var best_distance := INF
	for other in squads:
		if other.team == squad.team or not other.is_alive():
			continue
		if ranged_only and not other.unit.is_ranged():
			continue
		var d := squad.position.distance_squared_to(other.previous_position)
		if d < best_distance:
			best_distance = d
			best = other
	return best


## Birbirine fazla yaklaşan bölükleri iter; sonra alanın içinde tutar.
func _separate_squads() -> void:
	var min_distance := 2.0 * SQUAD_RADIUS
	for i in squads.size():
		var a := squads[i]
		if not a.is_alive():
			continue
		for j in range(i + 1, squads.size()):
			var b := squads[j]
			if not b.is_alive():
				continue
			var offset := b.position - a.position
			var distance := offset.length()
			if distance >= min_distance:
				continue
			var push_dir := offset / distance if distance > 0.001 else Vector2.RIGHT
			var push := push_dir * (min_distance - distance) * 0.5
			a.position -= push
			b.position += push
	for squad in squads:
		squad.position = squad.position.clamp(field_rect.position, field_rect.end)


func _check_end() -> void:
	var hp_by_team := {SquadState.Team.PLAYER: 0.0, SquadState.Team.ENEMY: 0.0}
	for squad in squads:
		hp_by_team[squad.team] += squad.hp_pool
	var player_hp: float = hp_by_team[SquadState.Team.PLAYER]
	var enemy_hp: float = hp_by_team[SquadState.Team.ENEMY]

	if player_hp > 0.0 and enemy_hp > 0.0 and elapsed < MAX_DURATION:
		return
	finished = true
	winner = SquadState.Team.PLAYER if player_hp > enemy_hp else SquadState.Team.ENEMY
	battle_finished.emit(winner)
