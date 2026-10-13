class_name BattleSimulation
extends RefCounted
## Savaşın kuralları. Görüntüden bağımsız ve deterministiktir:
## aynı bölükler + aynı seed = her zaman aynı sonuç.
## Ekran olmadan da çalışır; denge testi (Aşama 3) bunu kullanacak.

signal squad_attacked(attacker: SquadState, target: SquadState)
signal squad_destroyed(squad: SquadState)
signal battle_finished(winner: SquadState.Team)

const TICK := 1.0 / 30.0  ## Bir simülasyon adımının süresi (saniye).
const SQUAD_RADIUS := 0.5  ## Bölüklerin birbirine girmemesi için yarıçap (karo).
const MIN_DAMAGE_RATIO := 0.25  ## Zırh ne kadar yüksek olursa olsun hasarın en az bu oranı geçer.
const MAX_DURATION := 120.0  ## Bu süre dolarsa toplam canı fazla olan taraf kazanır.

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
	for squad in squads:
		if squad.is_alive():
			_update_squad(squad, pending_damage)
	for target: SquadState in pending_damage:
		var was_alive := target.is_alive()
		target.take_damage(pending_damage[target])
		if was_alive and not target.is_alive():
			squad_destroyed.emit(target)

	_separate_squads()
	_check_end()


func _update_squad(squad: SquadState, pending_damage: Dictionary) -> void:
	squad.attack_cooldown = maxf(squad.attack_cooldown - TICK, 0.0)
	if squad.target == null or not squad.target.is_alive():
		squad.target = _nearest_enemy(squad)
	if squad.target == null:
		return

	var to_target := squad.target.position - squad.position
	var distance := to_target.length()
	if distance > 0.001:
		squad.facing = to_target / distance

	# Menzil iki bölüğün kenarları arasında ölçülür.
	var gap := distance - 2.0 * SQUAD_RADIUS
	if gap > squad.unit.attack_range:
		var move := minf(squad.unit.move_speed * TICK, gap - squad.unit.attack_range)
		squad.position += squad.facing * move
		return

	if squad.attack_cooldown <= 0.0:
		var per_soldier := maxf(squad.unit.damage - squad.target.unit.armor,
				squad.unit.damage * MIN_DAMAGE_RATIO)
		var total := per_soldier * squad.alive_count() * _rng.randf_range(0.9, 1.1)
		pending_damage[squad.target] = pending_damage.get(squad.target, 0.0) + total
		squad.attack_cooldown = 1.0 / squad.unit.attack_speed
		squad_attacked.emit(squad, squad.target)


func _nearest_enemy(squad: SquadState) -> SquadState:
	var best: SquadState = null
	var best_distance := INF
	for other in squads:
		if other.team == squad.team or not other.is_alive():
			continue
		var d := squad.position.distance_squared_to(other.position)
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
