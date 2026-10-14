class_name PassiveData
extends Resource
## Ferman: krallığa ait, koşu boyunca kalıcı bir ordu bonusu. data/passives/ altında .tres dosyaları.
## Bir ferman tek bir değeri değiştirir; hangi bölüklere uygulanacağı rol ve derinlik bandıyla seçilir.

enum Row { ANY = -1, FRONT = 0, BACK = 1 }

const TOUGHNESS := &"toughness"  ## Özel değer: alınan hasarı bu çarpana böler.

@export var id: StringName
@export var kingdom: StringName
@export var display_name: String
@export_multiline var description: String
## Değişen UnitData alanı (damage, attack_speed, hp, move_speed, attack_range, armor,
## charge_multiplier) ya da "toughness".
@export var stat: StringName
@export var amount: float = 1.0
@export var is_multiplier := true  ## true: değer x amount; false: değer + amount.
@export var roles: Array[StringName] = []  ## Boşsa bütün roller.
@export var row: Row = Row.ANY  ## Sadece ön cephe / arka saf bölüklerine (konumlandırma).


func applies_to(squad: ArmySquad) -> bool:
	if not roles.is_empty() and not roles.has(squad.unit.role):
		return false
	match row:
		Row.FRONT:
			return squad.band() == ArmySquad.Band.FRONT
		Row.BACK:
			return squad.band() == ArmySquad.Band.BACK
	return true
