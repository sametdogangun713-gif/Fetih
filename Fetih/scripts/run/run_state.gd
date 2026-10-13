extends Node
## Koşunun (bir oyunun) durumu.
## Autoload olarak yüklenir: sahne değişse de yaşar ve her scriptten `RunState` adıyla erişilir.
## Bütün rastgelelik koşu seed'inden türetilir: aynı seed = aynı rakipler, ordular ve kartlar.
## Denge sayıları Balance'ta.

const RUN_LENGTH := Balance.RUN_LENGTH
const START_LIVES := Balance.START_LIVES
const GRID_SIZE := Balance.GRID_SIZE

# Seed'den farklı rastgele akışlar türetmek için amaç numaraları.
enum Purpose { OPPONENTS, ENEMY_ARMY, CARDS, BATTLE }

var active := false
var kingdom: KingdomData
var army: Array[ArmySquad] = []
var passives: Array[PassiveData] = []  ## Alınan fermanlar.
var lives := START_LIVES
var battle_index := 0  ## Şu anki savaş (0'dan başlar).
var wins := 0
var opponents: Array[KingdomData] = []  ## Her savaşın rakip krallığı, koşu başında belirlenir.
var seed_value := 0
var last_battle_won := false
var last_changed: ArmySquad  ## Son kartla eklenen/yükseltilen bölük (hazırlıkta vurgulanır).
var results: Array[bool] = []  ## Oynanan savaşların sonuçları (koşu haritası için).
var final_won := false  ## Büyük Fetih (son savaş) kazanıldı mı.
var last_life_restored := false  ## Son savaşta boss yenilip can geri geldi mi.


func start_run(p_kingdom: KingdomData, p_seed: int = 0) -> void:
	active = true
	kingdom = p_kingdom
	seed_value = p_seed if p_seed != 0 else randi()
	lives = START_LIVES
	battle_index = 0
	wins = 0
	last_battle_won = false
	last_changed = null
	results.clear()
	final_won = false
	last_life_restored = false
	passives.clear()
	passives.append_array(kingdom.starting_passives)
	army.clear()
	for unit in kingdom.starting_units:
		army.append(ArmySquad.new(unit, Balance.SQUAD_BUDGET, ArmyGenerator.NO_CELL))
	ArmyGenerator.auto_arrange(army, GRID_SIZE)
	opponents = _roll_opponents()


func end_run() -> void:
	active = false


# --- Savaş ---

func current_opponent() -> KingdomData:
	return opponents[battle_index]


## Şu anki savaşın rakip ordusu. Her çağrıda aynı orduyu verir (hazırlık ekranı ve savaş aynı orduyu görür).
func current_enemy_army() -> Array[ArmySquad]:
	return ArmyGenerator.enemy_army(current_opponent(), Balance.enemy_power(battle_index),
			Balance.enemy_squad_count(battle_index), GRID_SIZE, rng_for(Purpose.ENEMY_ARMY),
			is_boss_battle())


func is_boss_battle() -> bool:
	return Balance.is_boss_battle(battle_index)


func is_final_battle() -> bool:
	return Balance.is_final_battle(battle_index)


## Boss savaşında rakip ordusu krallığının bütün fermanlarını kullanır.
func enemy_passives() -> Array[PassiveData]:
	if is_boss_battle():
		return PassiveCatalog.of_kingdom(current_opponent().id)
	var none: Array[PassiveData] = []
	return none


## Oyuncu ordusunun savaşa girecek hali (seviyeler ve fermanlar uygulanmış).
func build_player_squads() -> Array[SquadState]:
	var result: Array[SquadState] = []
	for squad in army:
		result.append(SquadBuilder.build(squad, SquadState.Team.PLAYER, passives, GRID_SIZE))
	return result


func build_enemy_squads() -> Array[SquadState]:
	var result: Array[SquadState] = []
	var enemy_fermans := enemy_passives()
	for squad in current_enemy_army():
		result.append(SquadBuilder.build(squad, SquadState.Team.ENEMY, enemy_fermans, GRID_SIZE))
	return result


func battle_seed() -> int:
	return hash([seed_value, battle_index, Purpose.BATTLE])


func finish_battle(won: bool) -> void:
	last_battle_won = won
	results.append(won)
	last_life_restored = false
	if won:
		wins += 1
		if is_boss_battle() and lives < START_LIVES:
			lives = mini(lives + Balance.BOSS_LIFE_REWARD, START_LIVES)
			last_life_restored = true
	else:
		lives -= 1
	if is_final_battle():
		final_won = won


## Fetih tamamlandı mı: Büyük Fetih kazanılmış olmalı.
func is_victory() -> bool:
	return final_won and not is_defeated()


func is_defeated() -> bool:
	return lives <= 0


func is_last_battle() -> bool:
	return battle_index >= RUN_LENGTH - 1


## Kart seçiminden sonra sıradaki savaşa geç.
func advance() -> void:
	battle_index += 1


static func army_power(squads: Array[ArmySquad]) -> float:
	var total := 0.0
	for squad in squads:
		total += squad.power()
	return total


# --- Kartlar ---

## Son savaşın kartları: kazanınca 3, kaybedince 2.
func card_offers() -> Array[CardOffer]:
	return ArmyGenerator.card_offers(current_opponent(), army, passives, last_battle_won,
			rng_for(Purpose.CARDS), is_boss_battle() and last_battle_won)


func can_take(offer: CardOffer) -> bool:
	match offer.kind:
		CardOffer.Kind.UNIT:
			var existing := find_squad(offer.unit)
			return existing.can_upgrade() if existing else true
		CardOffer.Kind.UPGRADE:
			return offer.target.can_upgrade()
		CardOffer.Kind.PASSIVE:
			return not passives.has(offer.passive)
	return false


## Yeni birlik kartı ama ordu dolu: bir bölüğün yerine geçmesi gerekir.
func needs_replace(offer: CardOffer) -> bool:
	return offer.kind == CardOffer.Kind.UNIT and find_squad(offer.unit) == null \
			and army.size() >= Balance.MAX_SQUADS


## Kartı uygular. Birlik kartı orduda varsa takviye olur; ordu doluysa `replaced` bölüğün yerine geçer.
func take_card(offer: CardOffer, replaced: ArmySquad = null) -> void:
	match offer.kind:
		CardOffer.Kind.UNIT:
			var existing := find_squad(offer.unit)
			if existing:
				existing.upgrade(ArmySquad.Upgrade.REINFORCE)
				last_changed = existing
				return
			var cell := free_cell_for(offer.unit)
			if replaced:
				cell = replaced.cell
				army.erase(replaced)
			last_changed = ArmySquad.new(offer.unit, Balance.SQUAD_BUDGET, cell)
			army.append(last_changed)
		CardOffer.Kind.UPGRADE:
			offer.target.upgrade(offer.upgrade)
			last_changed = offer.target
		CardOffer.Kind.PASSIVE:
			passives.append(offer.passive)


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
	if army.size() >= Balance.MAX_SQUADS:
		return ArmyGenerator.NO_CELL
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
