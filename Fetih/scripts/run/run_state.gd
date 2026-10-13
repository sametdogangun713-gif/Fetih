extends Node
## Koşunun (bir oyunun) durumu.
## Autoload olarak yüklenir: sahne değişse de yaşar ve her scriptten `RunState` adıyla erişilir.
## Bütün rastgelelik koşu seed'inden türetilir: aynı seed = aynı rakipler, ordular ve kartlar.

const RUN_LENGTH := 5  ## Aşama 4: kısa koşu. Tam oyunda 20 olacak.
const START_LIVES := 3
const GRID_SIZE := Vector2i(3, 3)
const CARD_BUDGET := 100.0  ## Bir kartın verdiği bölüğün bütçesi (100 = 20 savaşçı).
const ENEMY_BASE_BUDGET := 180.0  ## İlk rakibin ordu bütçesi.
const ENEMY_BUDGET_PER_BATTLE := 100.0  ## Her savaşta rakibe eklenen bütçe.
const CARDS_ON_WIN := 3
const CARDS_ON_LOSS := 2

# Seed'den farklı rastgele akışlar türetmek için amaç numaraları.
enum Purpose { OPPONENTS, ENEMY_ARMY, CARDS, BATTLE }

var active := false
var kingdom: KingdomData
var army: Array[ArmySquad] = []
var lives := START_LIVES
var battle_index := 0  ## Şu anki savaş (0'dan başlar).
var wins := 0
var opponents: Array[KingdomData] = []  ## Her savaşın rakip krallığı, koşu başında belirlenir.
var seed_value := 0
var last_battle_won := false


func start_run(p_kingdom: KingdomData, p_seed: int = 0) -> void:
	active = true
	kingdom = p_kingdom
	seed_value = p_seed if p_seed != 0 else randi()
	lives = START_LIVES
	battle_index = 0
	wins = 0
	last_battle_won = false
	army.clear()
	for unit in kingdom.starting_units:
		army.append(ArmySquad.new(unit, UnitCatalog.count_for_budget(unit, CARD_BUDGET),
				ArmyGenerator.NO_CELL))
	ArmyGenerator.auto_arrange(army, GRID_SIZE)
	opponents = _roll_opponents()


func end_run() -> void:
	active = false


# --- Savaş ---

func current_opponent() -> KingdomData:
	return opponents[battle_index]


func enemy_budget() -> float:
	return ENEMY_BASE_BUDGET + ENEMY_BUDGET_PER_BATTLE * battle_index


## Şu anki savaşın rakip ordusu. Her çağrıda aynı orduyu verir (hazırlık ekranı ve savaş aynı orduyu görür).
func current_enemy_army() -> Array[ArmySquad]:
	return ArmyGenerator.enemy_army(current_opponent(), enemy_budget(), GRID_SIZE,
			rng_for(Purpose.ENEMY_ARMY))


func battle_seed() -> int:
	return hash([seed_value, battle_index, Purpose.BATTLE])


func finish_battle(won: bool) -> void:
	last_battle_won = won
	if won:
		wins += 1
	else:
		lives -= 1


func is_defeated() -> bool:
	return lives <= 0


func is_last_battle() -> bool:
	return battle_index >= RUN_LENGTH - 1


## Kart seçiminden sonra sıradaki savaşa geç.
func advance() -> void:
	battle_index += 1


# --- Kartlar ---

## Son savaşta karşılaşılan krallığın kartları. Kazanınca 3, kaybedince 2 kart.
func card_offers() -> Array[CardOffer]:
	var count := CARDS_ON_WIN if last_battle_won else CARDS_ON_LOSS
	return ArmyGenerator.card_offers(current_opponent(), count, CARD_BUDGET, rng_for(Purpose.CARDS))


func can_take(offer: CardOffer) -> bool:
	return find_squad(offer.unit) != null or free_cell_for(offer.unit) != ArmyGenerator.NO_CELL


## Aynı birlik orduda varsa o bölüğe eklenir; yoksa uygun boş kareye yeni bölük olarak girer.
func take_card(offer: CardOffer) -> void:
	var existing := find_squad(offer.unit)
	if existing:
		existing.count += offer.count
	else:
		army.append(ArmySquad.new(offer.unit, offer.count, free_cell_for(offer.unit)))


# --- Ordu ızgarası ---

func squad_at(cell: Vector2i) -> ArmySquad:
	for squad in army:
		if squad.cell == cell:
			return squad
	return null


func find_squad(unit: UnitData) -> ArmySquad:
	for squad in army:
		if squad.unit == unit:
			return squad
	return null


func free_cell_for(unit: UnitData) -> Vector2i:
	var occupied := {}
	for squad in army:
		occupied[squad.cell] = true
	return ArmyGenerator.best_free_cell(occupied, GRID_SIZE, unit.role)


## İki karenin içeriğini değiştirir (biri boş olabilir).
func move_squad(from: Vector2i, to: Vector2i) -> void:
	var a := squad_at(from)
	var b := squad_at(to)
	if a:
		a.cell = to
	if b:
		b.cell = from


# --- Rastgelelik ---

## Bu savaş ve amaç için seed'li bir rastgele sayı üreteci.
func rng_for(purpose: Purpose) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, battle_index, purpose])
	return rng


func _roll_opponents() -> Array[KingdomData]:
	var pool: Array[KingdomData] = []
	for other in KingdomCatalog.all():
		if other != kingdom:
			pool.append(other)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, Purpose.OPPONENTS])
	var result: Array[KingdomData] = []
	for i in RUN_LENGTH:
		var pick := pool[rng.randi_range(0, pool.size() - 1)]
		# Aynı krallık art arda gelmesin (havuzda birden fazla krallık varsa).
		while pool.size() > 1 and not result.is_empty() and pick == result.back():
			pick = pool[rng.randi_range(0, pool.size() - 1)]
		result.append(pick)
	return result
