class_name KingdomCatalog
## data/kingdoms/ altındaki tüm krallıkları yükler.

const KINGDOMS_DIR := "res://data/kingdoms/"

static var _kingdoms: Array[KingdomData] = []


## Tüm krallıklar, UnitCatalog.KINGDOM_ORDER sırasında.
static func all() -> Array[KingdomData]:
	if _kingdoms.is_empty():
		for file in ResourceLoader.list_directory(KINGDOMS_DIR):
			if file.ends_with(".tres") or file.ends_with(".res"):
				_kingdoms.append(load(KINGDOMS_DIR + file))
		_kingdoms.sort_custom(func(a: KingdomData, b: KingdomData) -> bool:
				return UnitCatalog.KINGDOM_ORDER.find(a.id) < UnitCatalog.KINGDOM_ORDER.find(b.id))
	return _kingdoms


static func get_kingdom(id: StringName) -> KingdomData:
	for kingdom in all():
		if kingdom.id == id:
			return kingdom
	return null


static func clear_cache() -> void:
	_kingdoms.clear()
