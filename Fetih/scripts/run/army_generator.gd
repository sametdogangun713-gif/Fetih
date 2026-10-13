class_name ArmyGenerator
## Rakip ordularını ve kart tekliflerini üretir; bölükleri ızgaraya yerleştirir.
## Hepsi dışarıdan verilen RandomNumberGenerator ile çalışır: aynı seed = aynı sonuç.

const SPECIALTY_CHANCE := 0.4  ## Rakip bölüğünün krallık uzmanı olma olasılığı.
const NO_CELL := Vector2i(-1, -1)

## Yerleştirme sırası: önce cephe birlikleri öne, en son menzilliler arkaya.
## (Boss da rolüne göre yerleşir: tank/savaşçı boss önde, büyücü boss arkada.)
const PLACEMENT_ORDER: Array[StringName] = [
	RoleRules.TANK, RoleRules.SPEARMAN, RoleRules.WARRIOR,
	RoleRules.CAVALRY, RoleRules.MAGE, RoleRules.ARCHER,
]


## Verilen krallıktan, hedef güçte bir ordu kurar: önce bölükler, kalan güç yükseltmelere.
## with_boss: boss savaşı; boss gücü toplamın içindedir ve boss ayrı bir bölük olarak eklenir.
static func enemy_army(kingdom: KingdomData, power: float, squad_count: int, grid_size: Vector2i,
		rng: RandomNumberGenerator, with_boss := false) -> Array[ArmySquad]:
	var units := UnitCatalog.units_of(kingdom.id)
	var squads := clampi(squad_count, 1, Balance.MAX_SQUADS)
	var army: Array[ArmySquad] = []
	var total := 0.0
	if with_boss and kingdom.boss:
		army.append(ArmySquad.new(kingdom.boss, kingdom.boss.cost, NO_CELL))
		total += kingdom.boss.cost
	# Güç azsa bölükler küçük olur; yeterliyse her biri tam (100) bölük.
	var base := minf(Balance.SQUAD_BUDGET, maxf(power - total, 0.0) / squads)
	base = maxf(base, Balance.SQUAD_BUDGET * 0.3)
	for i in squads:
		army.append(ArmySquad.new(_pick_unit(units, kingdom, rng), base, NO_CELL))

	total += base * squads
	var half_step := Balance.SQUAD_BUDGET * Balance.UPGRADE_STEP * 0.5
	while total < power - half_step:
		var upgradable: Array[ArmySquad] = []
		for squad in army:
			# Boss yükseltilmez: tek askerli olduğu için Takviye ona asker eklemez.
			if squad.can_upgrade() and not squad.unit.is_boss:
				upgradable.append(squad)
		if upgradable.is_empty():
			break
		var squad := upgradable[rng.randi_range(0, upgradable.size() - 1)]
		var before := squad.power()
		squad.upgrade(rng.randi_range(0, 2) as ArmySquad.Upgrade)
		total += squad.power() - before

	auto_arrange(army, grid_size)
	return army


## Savaş sonrası kartlar. Kural: birlik kartları ve fermanlar savaşılan krallıktan gelir.
## 1. kart: birlik. 2. kart: yükseltme. 3. kart (sadece zaferde): birlik / yükseltme / ferman.
## boss_reward: boss yenildi; 3. kart (varsa) mutlaka ferman.
static func card_offers(opponent: KingdomData, army: Array[ArmySquad], owned: Array[PassiveData],
		won: bool, rng: RandomNumberGenerator, boss_reward := false) -> Array[CardOffer]:
	var unit_pool: Array = UnitCatalog.units_of(opponent.id).duplicate()
	_shuffle(unit_pool, rng)
	var passive_pool: Array = []
	for passive in PassiveCatalog.of_kingdom(opponent.id):
		if not owned.has(passive):
			passive_pool.append(passive)
	_shuffle(passive_pool, rng)

	var offers: Array[CardOffer] = []
	if not unit_pool.is_empty():
		offers.append(CardOffer.unit_card(unit_pool.pop_back()))
	_add_upgrade_or_fallback(offers, army, unit_pool, passive_pool, rng)
	if won:
		var roll := rng.randf()
		if boss_reward and not passive_pool.is_empty():
			offers.append(CardOffer.passive_card(passive_pool.pop_back()))
		elif roll < Balance.THIRD_CARD_UNIT and not unit_pool.is_empty():
			offers.append(CardOffer.unit_card(unit_pool.pop_back()))
		elif roll < Balance.THIRD_CARD_UNIT + Balance.THIRD_CARD_UPGRADE or passive_pool.is_empty():
			_add_upgrade_or_fallback(offers, army, unit_pool, passive_pool, rng)
		else:
			offers.append(CardOffer.passive_card(passive_pool.pop_back()))
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


## Rastgele bir bölüğe rastgele bir yükseltme; aynı bölük + aynı tür iki kez sunulmaz.
## Yükseltilecek bölük yoksa birlik, o da yoksa ferman kartı.
static func _add_upgrade_or_fallback(offers: Array[CardOffer], army: Array[ArmySquad],
		unit_pool: Array, passive_pool: Array, rng: RandomNumberGenerator) -> void:
	var options: Array = []
	for squad in army:
		if not squad.can_upgrade():
			continue
		for kind in [ArmySquad.Upgrade.ATTACK, ArmySquad.Upgrade.DEFENSE, ArmySquad.Upgrade.REINFORCE]:
			var taken := false
			for offer in offers:
				if offer.kind == CardOffer.Kind.UPGRADE and offer.target == squad and offer.upgrade == kind:
					taken = true
			if not taken:
				options.append([squad, kind])
	if not options.is_empty():
		var pick: Array = options[rng.randi_range(0, options.size() - 1)]
		offers.append(CardOffer.upgrade_card(pick[0], pick[1]))
	elif not unit_pool.is_empty():
		offers.append(CardOffer.unit_card(unit_pool.pop_back()))
	elif not passive_pool.is_empty():
		offers.append(CardOffer.passive_card(passive_pool.pop_back()))


static func _pick_unit(units: Array[UnitData], kingdom: KingdomData,
		rng: RandomNumberGenerator) -> UnitData:
	if rng.randf() < SPECIALTY_CHANCE:
		for unit in units:
			if unit.role == kingdom.specialty_role:
				return unit
	return units[rng.randi_range(0, units.size() - 1)]


## Fisher-Yates karıştırma (seed'li rng ile, deterministik).
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp: Variant = items[i]
		items[i] = items[j]
		items[j] = temp


## Sütun sırası ortadan dışarı: 3 sütun için [1, 0, 2], 5 için [2, 1, 3, 0, 4].
static func _center_out(n: int) -> Array:
	var center := (n - 1) / 2.0
	var cols := range(n)
	cols.sort_custom(func(a: int, b: int) -> bool:
			var da := absf(a - center)
			var db := absf(b - center)
			return da < db or (is_equal_approx(da, db) and a < b))
	return cols
