class_name SquadState
extends RefCounted
## Savaştaki bir bölüğün anlık durumu. Sadece veri; çizim yapmaz.
## Konumlar savaş alanı koordinatındadır: 1 birim = 1 karo, ondalıklı olabilir.

enum Team { PLAYER, ENEMY }

var unit: UnitData
var team: Team
var max_count: int  ## Savaş başındaki asker sayısı.
var hp_pool: float  ## Bölüğün toplam canı. Asker sayısı buradan hesaplanır.
var position: Vector2
var previous_position: Vector2  ## Bir önceki adımdaki konum (akıcı çizim için).
var facing := Vector2.UP  ## Bölüğün baktığı yön.
var target: SquadState
var attack_cooldown := 0.0
var distance_since_attack := 0.0  ## Son saldırıdan beri yürünen mesafe (hücum için).


func _init(p_unit: UnitData, p_team: Team, p_count: int, p_position: Vector2) -> void:
	unit = p_unit
	team = p_team
	max_count = p_count
	hp_pool = p_unit.hp * p_count
	position = p_position
	previous_position = p_position
	facing = Vector2.UP if p_team == Team.PLAYER else Vector2.DOWN


func is_alive() -> bool:
	return hp_pool > 0.0


## Hayattaki asker sayısı. Yaralı son asker de sayılır.
func alive_count() -> int:
	if hp_pool <= 0.0:
		return 0
	return ceili(hp_pool / unit.hp)


func take_damage(amount: float) -> void:
	hp_pool = maxf(hp_pool - amount, 0.0)
