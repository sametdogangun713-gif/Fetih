class_name ArmySquad
extends RefCounted
## Ordudaki bir bölük; koşu boyunca kalıcıdır. Savaştaki anlık hali ise SquadState'tir.
## Ordular her savaşa tam güçle girer (9 Kings'teki gibi): savaş kayıpları buraya yansımaz.

var unit: UnitData
var count: int  ## Asker sayısı.
var cell: Vector2i  ## Ordu ızgarasındaki yeri. y = 0 ön cephedir.


func _init(p_unit: UnitData, p_count: int, p_cell: Vector2i) -> void:
	unit = p_unit
	count = p_count
	cell = p_cell
