class_name ArmySquad
extends RefCounted
## Ordudaki bir bölük; koşu boyunca kalıcıdır. Savaştaki anlık hali SquadState'tir
## (SquadBuilder seviye ve fermanları uygulayarak üretir).
## Ordular her savaşa tam güçle girer (9 Kings'teki gibi): savaş kayıpları buraya yansımaz.

enum Upgrade { ATTACK, DEFENSE, REINFORCE }
enum Band { FRONT, MIDDLE, BACK }  ## Derinlik bandı: fermanların "ön/arka" şartı bununla ölçülür.

const FRONT_LIMIT := 0.5  ## Derinlik bundan azsa ön cephe.
const BACK_LIMIT := 1.5  ## Derinlik en az buysa arka saf. Izgara sıraları 0/1/2 -> ön/orta/arka.

var unit: UnitData
var base_power: float  ## Taban bütçe (normalde 100). Asker sayısı buradan hesaplanır.
var pos: Vector2  ## Bölge koordinatı (Formation): x cephe boyunca, y derinlik (0 = ön).
var attack_level := 0
var defense_level := 0
var reinforce_level := 0

## Asker sayısı: (taban bütçe x takviye çarpanı) / birlik maliyeti, tek seferde yuvarlanır.
## (Önce yuvarlayıp sonra çarpmak az askerli birliklerde hatayı büyütür: 8 şövalye x1.4 = 11 değil 12.)
var count: int:
	get:
		return UnitCatalog.count_for_budget(unit, base_power * Balance.level_multiplier(reinforce_level))


func _init(p_unit: UnitData, p_base_power: float, p_pos := Vector2.ZERO) -> void:
	unit = p_unit
	base_power = p_base_power
	pos = p_pos


static func band_of(depth: float) -> Band:
	if depth < FRONT_LIMIT:
		return Band.FRONT
	if depth >= BACK_LIMIT:
		return Band.BACK
	return Band.MIDDLE


func band() -> Band:
	return band_of(pos.y)


## 1 (taban) ile Balance.MAX_LEVEL arası.
func level() -> int:
	return 1 + attack_level + defense_level + reinforce_level


func can_upgrade() -> bool:
	return level() < Balance.MAX_LEVEL


func upgrade(kind: Upgrade) -> void:
	match kind:
		Upgrade.ATTACK:
			attack_level += 1
		Upgrade.DEFENSE:
			defense_level += 1
		Upgrade.REINFORCE:
			reinforce_level += 1


func upgrade_level(kind: Upgrade) -> int:
	match kind:
		Upgrade.ATTACK:
			return attack_level
		Upgrade.DEFENSE:
			return defense_level
	return reinforce_level


## Eşdeğer bütçe (bkz. Balance): taban x her türün çarpanı.
func power() -> float:
	return base_power * Balance.level_multiplier(attack_level) \
			* Balance.level_multiplier(defense_level) * Balance.level_multiplier(reinforce_level)
