class_name UnitCatalog
## data/units/ altındaki tüm birlikleri yükler ve sorgular.
## ResourceLoader.list_directory() export edilmiş oyunda da doğru dosya adlarını verir.

const UNITS_DIR := "res://data/units/"
const KINGDOM_ORDER: Array[StringName] = [&"humans", &"elves", &"orcs"]

static var _units: Array[UnitData] = []


## Tüm birlikler; krallık, sonra rol sırasına göre.
static func all() -> Array[UnitData]:
	if _units.is_empty():
		for file in ResourceLoader.list_directory(UNITS_DIR):
			if file.ends_with(".tres") or file.ends_with(".res"):
				_units.append(load(UNITS_DIR + file))
		_units.sort_custom(_compare)
	return _units


## Önbelleği boşaltır. Ekransız scriptler çıkmadan önce çağırır; yoksa Godot
## "resources still in use at exit" uyarısı verir.
static func clear_cache() -> void:
	_units.clear()


static func get_unit(id: StringName) -> UnitData:
	for unit in all():
		if unit.id == id:
			return unit
	return null


## Verilen bütçeyle bu birlikten kaç asker alınır (en az 1).
static func count_for_budget(unit: UnitData, budget: float) -> int:
	return maxi(1, roundi(budget / unit.cost))


static func _compare(a: UnitData, b: UnitData) -> bool:
	var ka := KINGDOM_ORDER.find(a.kingdom)
	var kb := KINGDOM_ORDER.find(b.kingdom)
	if ka != kb:
		return ka < kb
	return RoleRules.ROLE_ORDER.find(a.role) < RoleRules.ROLE_ORDER.find(b.role)
