class_name MetaUpgrades
## Kalıcı geliştirmeler: koşular arasında Şan ile satın alınır, bütün koşuları etkiler.
## Her geliştirmenin seviyeleri ve her seviyenin fiyatı var.

const EXTRA_CARD := "extra_card"
const EXTRA_LIFE := "extra_life"
const VETERANS := "veterans"
const SCOUTING := "scouting"

const ALL := [
	{"id": EXTRA_CARD, "name": "Geniş Ganimet", "costs": [40, 90],
		"desc": "Her savaştan sonra +1 kart seçeneği (seviye başına)."},
	{"id": EXTRA_LIFE, "name": "Sağlam Moral", "costs": [60],
		"desc": "Koşuya +1 canla başla."},
	{"id": VETERANS, "name": "Gaziler", "costs": [30],
		"desc": "Başlangıç bölüklerin bir Takviye seviyesiyle (Sv 2) başlar."},
	{"id": SCOUTING, "name": "Keşif", "costs": [20, 35, 50],
		"desc": "Koşu başına kart tekliflerini yeniden çekme hakkı (seviye başına 1)."},
]

## Şan kazanımı (koşu sonunda).
const GLORY_PER_WIN := 2
const GLORY_PER_BOSS := 5
const GLORY_VICTORY := 25


static func get_def(id: String) -> Dictionary:
	for def in ALL:
		if def["id"] == id:
			return def
	return {}


static func max_level(id: String) -> int:
	return get_def(id).get("costs", []).size()


## Bir sonraki seviyenin fiyatı; en üst seviyedeyse -1.
static func next_cost(id: String, level: int) -> int:
	var costs: Array = get_def(id).get("costs", [])
	return costs[level] if level < costs.size() else -1
