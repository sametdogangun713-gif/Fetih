class_name CardOffer
extends RefCounted
## Savaştan sonra sunulan bir birlik kartı: "20 Elf Okçusu" gibi.
## Aşama 5'te güçlendirme ve ferman kartları da eklenecek.

var unit: UnitData
var count: int


func _init(p_unit: UnitData, p_count: int) -> void:
	unit = p_unit
	count = p_count
