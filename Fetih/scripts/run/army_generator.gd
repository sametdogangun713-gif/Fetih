class_name ArmyGenerator
## Rakip ordularını ve kart tekliflerini üretir; bölükleri ızgaraya yerleştirir.
## Hepsi dışarıdan verilen RandomNumberGenerator ile çalışır: aynı seed = aynı ordu.

const SQUAD_BUDGET := 100.0  ## Rakip ordusunda bir bölüğün ortalama bütçesi.
const SPECIALTY_CHANCE := 0.4  ## Rakip bölüğünün krallık uzmanı olma olasılığı.
const NO_CELL := Vector2i(-1, -1)

## Yerleştirme sırası: önce cephe birlikleri öne, en son menzilliler arkaya.
const PLACEMENT_ORDER: Array[StringName] = [
	RoleRules.TANK, RoleRules.SPEARMAN, RoleRules.WARRIOR,
	RoleRules.CAVALRY, RoleRules.MAGE, RoleRules.ARCHER,
]


## Verilen krallıktan, bütçeye göre bir ordu kurar ve ızgaraya dizer.
static func enemy_army(kingdom: KingdomData, budget: float, grid_size: Vector2i,
		rng: RandomNumberGenerator) -> Array[ArmySquad]:
	var units := UnitCatalog.units_of(kingdom.id)
	var squad_count := clampi(roundi(budget / SQUAD_BUDGET), 1, grid_size.x * grid_size.y)
	var per_squad := budget / squad_count
	var army: Array[ArmySquad] = []
	for i in squad_count:
		var unit := _pick_unit(units, kingdom, rng)
		army.append(ArmySquad.new(unit, UnitCatalog.count_for_budget(unit, per_squad), NO_CELL))
	auto_arrange(army, grid_size)
	return army


## Krallığın birliklerinden en fazla `count` farklı kart teklifi.
static func card_offers(kingdom: KingdomData, count: int, budget: float,
		rng: RandomNumberGenerator) -> Array[CardOffer]:
	var units := UnitCatalog.units_of(kingdom.id).duplicate()
	# Fisher-Yates karıştırma (seed'li rng ile, deterministik).
	for i in range(units.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp: UnitData = units[i]
		units[i] = units[j]
		units[j] = temp
	var offers: Array[CardOffer] = []
	for i in mini(count, units.size()):
		offers.append(CardOffer.new(units[i], UnitCatalog.count_for_budget(units[i], budget)))
	return offers


## Bölükleri rollerine göre ızgaraya dizer: cephe birlikleri öne, menzilliler arkaya.
static func auto_arrange(army: Array[ArmySquad], grid_size: Vector2i) -> void:
	var sorted: Array[ArmySquad] = army.duplicate()
	sorted.sort_custom(func(a: ArmySquad, b: ArmySquad) -> bool:
			return PLACEMENT_ORDER.find(a.unit.role) < PLACEMENT_ORDER.find(b.unit.role))
	var occupied := {}
	for squad in sorted:
		squad.cell = best_free_cell(occupied, grid_size, squad.unit.role)
		occupied[squad.cell] = true


## Bu rol için en uygun boş kare. occupied: Vector2i -> true. Yer yoksa NO_CELL.
static func best_free_cell(occupied: Dictionary, grid_size: Vector2i, role: StringName) -> Vector2i:
	var rows := range(grid_size.y)
	if role == RoleRules.ARCHER or role == RoleRules.MAGE:
		rows.reverse()  # menzilliler arkadan başlar
	var cols := _center_out(grid_size.x)
	if role == RoleRules.CAVALRY:
		cols.reverse()  # süvari kanatlardan başlar
	for row in rows:
		for col in cols:
			var cell := Vector2i(col, row)
			if not occupied.has(cell):
				return cell
	return NO_CELL


static func _pick_unit(units: Array[UnitData], kingdom: KingdomData,
		rng: RandomNumberGenerator) -> UnitData:
	if rng.randf() < SPECIALTY_CHANCE:
		for unit in units:
			if unit.role == kingdom.specialty_role:
				return unit
	return units[rng.randi_range(0, units.size() - 1)]


## Sütun sırası ortadan dışarı: 3 sütun için [1, 0, 2], 5 için [2, 1, 3, 0, 4].
static func _center_out(n: int) -> Array:
	var center := (n - 1) / 2.0
	var cols := range(n)
	cols.sort_custom(func(a: int, b: int) -> bool:
			var da := absf(a - center)
			var db := absf(b - center)
			return da < db or (is_equal_approx(da, db) and a < b))
	return cols
