class_name PassiveCatalog
## data/passives/ altındaki fermanları yükler.

const PASSIVES_DIR := "res://data/passives/"

static var _passives: Array[PassiveData] = []


static func all() -> Array[PassiveData]:
	if _passives.is_empty():
		for file in ResourceLoader.list_directory(PASSIVES_DIR):
			if file.ends_with(".tres") or file.ends_with(".res"):
				_passives.append(load(PASSIVES_DIR + file))
		_passives.sort_custom(func(a: PassiveData, b: PassiveData) -> bool:
				return String(a.id) < String(b.id))
	return _passives


static func get_passive(id: StringName) -> PassiveData:
	for passive in all():
		if passive.id == id:
			return passive
	return null


static func of_kingdom(kingdom: StringName) -> Array[PassiveData]:
	var result: Array[PassiveData] = []
	for passive in all():
		if passive.kingdom == kingdom:
			result.append(passive)
	return result


static func clear_cache() -> void:
	_passives.clear()
