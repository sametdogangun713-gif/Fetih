extends Node
## Koşunun (bir oyunun) durumu.
## Autoload olarak yüklenir: sahne değişse de yaşar ve her scriptten `RunState` adıyla erişilir.
## Bütün rastgelelik koşu seed'inden türetilir: aynı seed = aynı rakipler, ordular ve kartlar.
## Denge sayıları Balance'ta. Kalıcı profil (Profile) burada kullanılmaz: kalıcı bonuslar
## start_run'a parametre olarak gelir. Böylece testler oyuncunun kayıt dosyasından etkilenmez.

const RUN_LENGTH := Balance.RUN_LENGTH
const GRID_SIZE := Balance.GRID_SIZE

# Seed'den farklı rastgele akışlar türetmek için amaç numaraları.
enum Purpose { OPPONENTS, ENEMY_ARMY, CARDS, BATTLE }

var active := false
var kingdom: KingdomData
var army: Array[ArmySquad] = []
var passives: Array[PassiveData] = []  ## Alınan fermanlar.
var lives := Balance.START_LIVES
var max_lives := Balance.START_LIVES  ## Başlangıç canı (kalıcı geliştirmeyle artar); boss ödülü buna kadar.
var battle_index := 0  ## Şu anki savaş (0'dan başlar).
var wins := 0
var bosses_beaten := 0
var opponents: Array[KingdomData] = []  ## Her savaşın rakip krallığı, koşu başında belirlenir.
var seed_value := 0
var last_battle_won := false
var last_changed: ArmySquad  ## Son kartla eklenen/yükseltilen bölük (hazırlıkta vurgulanır).
var results: Array[bool] = []  ## Oynanan savaşların sonuçları (koşu haritası için).
var final_won := false  ## Büyük Fetih (son savaş) kazanıldı mı.
var last_life_restored := false  ## Son savaşta boss yenilip can geri geldi mi.
var perks := {}  ## Kalıcı geliştirmeler (Profile.run_perks): extra_cards, extra_lives, veterans, rerolls.
var rerolls_left := 0  ## Kart tekliflerini yeniden çekme hakkı (koşu boyunca).
var reroll_count := 0  ## Bu savaştan sonra kaç kez yeniden çekildi (kart seed'ine karışır).
var locked: Array[StringName] = []  ## Kilitli krallıklar (boss'larını yenmek mühür kazandırır).
var seals: Array[StringName] = []  ## Bu koşuda kazanılan mühürler; fetih tamamlanınca krallık açılır.


func start_run(p_kingdom: KingdomData, p_seed: int = 0, p_perks: Dictionary = {},
		p_locked: Array[StringName] = []) -> void:
	active = true
	kingdom = p_kingdom
	seed_value = p_seed if p_seed != 0 else randi()
	perks = p_perks.duplicate()
	locked = p_locked.duplicate()
	max_lives = Balance.START_LIVES + int(perks.get("extra_lives", 0))
	lives = max_lives
	rerolls_left = int(perks.get("rerolls", 0))
	reroll_count = 0
	battle_index = 0
	wins = 0
	bosses_beaten = 0
	last_battle_won = false
	last_changed = null
	results.clear()
	seals.clear()
	final_won = false
	last_life_restored = false
	passives.clear()
	passives.append_array(kingdom.starting_passives)
	army.clear()
	for unit in kingdom.starting_units:
		var squad := ArmySquad.new(unit, Balance.SQUAD_BUDGET)
		for i in int(perks.get("veterans", 0)):
			squad.upgrade(ArmySquad.Upgrade.REINFORCE)
		army.append(squad)
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
		result.append(SquadBuilder.build(squad, SquadState.Team.PLAYER, passives))
	return result


func build_enemy_squads() -> Array[SquadState]:
	var result: Array[SquadState] = []
	var enemy_fermans := enemy_passives()
	for squad in current_enemy_army():
		result.append(SquadBuilder.build(squad, SquadState.Team.ENEMY, enemy_fermans))
	return result


func battle_seed() -> int:
	return hash([seed_value, battle_index, Purpose.BATTLE])


func finish_battle(won: bool) -> void:
	last_battle_won = won
	results.append(won)
	last_life_restored = false
	if won:
		wins += 1
		if is_boss_battle():
			bosses_beaten += 1
			var opponent_id := current_opponent().id
			if locked.has(opponent_id) and not seals.has(opponent_id):
				seals.append(opponent_id)
			if lives < max_lives:
				lives = mini(lives + Balance.BOSS_LIFE_REWARD, max_lives)
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
	reroll_count = 0


## Koşu sonunda kazanılan Şan.
func glory_earned() -> int:
	var glory := wins * MetaUpgrades.GLORY_PER_WIN + bosses_beaten * MetaUpgrades.GLORY_PER_BOSS
	if is_victory():
		glory += MetaUpgrades.GLORY_VICTORY
	return glory


static func army_power(squads: Array[ArmySquad]) -> float:
	var total := 0.0
	for squad in squads:
		total += squad.power()
	return total


# --- Kartlar ---

## Son savaşın kartları: kazanınca 3, kaybedince 2 (+ kalıcı geliştirme).
func card_offers() -> Array[CardOffer]:
	var count := (Balance.CARDS_ON_WIN if last_battle_won else Balance.CARDS_ON_LOSS) \
			+ int(perks.get("extra_cards", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, battle_index, Purpose.CARDS, reroll_count])
	return ArmyGenerator.card_offers(current_opponent(), army, passives, count, rng,
			is_boss_battle() and last_battle_won)


## Kart tekliflerini yeniden çek (Keşif hakkı harcanır).
func reroll_cards() -> bool:
	if rerolls_left <= 0:
		return false
	rerolls_left -= 1
	reroll_count += 1
	return true


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
			var pos := free_pos_for(offer.unit)
			if replaced:
				pos = replaced.pos
				army.erase(replaced)
			last_changed = ArmySquad.new(offer.unit, Balance.SQUAD_BUDGET, pos)
			army.append(last_changed)
		CardOffer.Kind.UPGRADE:
			offer.target.upgrade(offer.upgrade)
			last_changed = offer.target
		CardOffer.Kind.PASSIVE:
			passives.append(offer.passive)


# --- Ordu yerleşimi ---

## GEÇİCİ (eski hazırlık ekranı için, Task 12'de silinir): ızgara karesindeki bölük.
func squad_at(cell: Vector2i) -> ArmySquad:
	var pos := Formation.cell_to_deploy(cell, GRID_SIZE)
	for squad in army:
		if squad.pos.is_equal_approx(pos):
			return squad
	return null


func find_squad(unit: UnitData) -> ArmySquad:
	for squad in army:
		if squad.unit == unit:
			return squad
	return null


## except dışındaki bölüklerin konumları (taşınan bölük kendi yerini "dolu" saymasın diye).
func other_positions(except: ArmySquad = null) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for squad in army:
		if squad != except:
			out.append(squad.pos)
	return out


## Yeni birlik için en uygun boş nokta (ızgara sırasını izler).
func free_pos_for(unit: UnitData) -> Vector2:
	return ArmyGenerator.best_free_pos(other_positions(), GRID_SIZE, unit.role)


## Bölüğü bölgede pos'a taşır; dolu ya da bölge dışıysa en yakın boş noktaya oturur.
func move_squad_to(squad: ArmySquad, pos: Vector2) -> Vector2:
	squad.pos = Formation.nearest_free(pos, other_positions(squad))
	return squad.pos


## GEÇİCİ (eski hazırlık ekranı için, Task 12'de silinir): iki karenin içeriğini değiştirir.
func move_squad(from: Vector2i, to: Vector2i) -> void:
	var a := squad_at(from)
	var b := squad_at(to)
	if a:
		a.pos = Formation.cell_to_deploy(to, GRID_SIZE)
	if b:
		b.pos = Formation.cell_to_deploy(from, GRID_SIZE)


# --- Kaydet / yükle ---

## Yarım kalan koşuyu JSON'a çevrilebilir sözlük olarak verir.
## phase: koşuya dönülünce açılacak ekran ("prep", "battle", "cards").
func to_dict(phase: String) -> Dictionary:
	var squads := []
	for squad in army:
		squads.append({
			"unit": String(squad.unit.id), "base_power": squad.base_power,
			"pos": [squad.pos.x, squad.pos.y],
			"attack": squad.attack_level, "defense": squad.defense_level, "reinforce": squad.reinforce_level,
		})
	return {
		"phase": phase,
		"kingdom": String(kingdom.id),
		"seed": seed_value,
		"battle_index": battle_index,
		"lives": lives, "max_lives": max_lives,
		"wins": wins, "bosses_beaten": bosses_beaten,
		"results": results.duplicate(),
		"last_battle_won": last_battle_won, "final_won": final_won,
		"last_life_restored": last_life_restored,
		"opponents": opponents.map(func(k: KingdomData) -> String: return String(k.id)),
		"army": squads,
		"passives": passives.map(func(p: PassiveData) -> String: return String(p.id)),
		"perks": perks,
		"rerolls_left": rerolls_left, "reroll_count": reroll_count,
		"locked": locked.map(func(id: StringName) -> String: return String(id)),
		"seals": seals.map(func(id: StringName) -> String: return String(id)),
	}


## to_dict ile kaydedilen koşuyu geri yükler. Veri bozuksa false döner.
## (JSON'dan gelen bütün sayılar ondalıklıdır; int() ile çevrilir.)
func from_dict(data: Dictionary) -> bool:
	var loaded_kingdom := KingdomCatalog.get_kingdom(StringName(data.get("kingdom", "")))
	if loaded_kingdom == null:
		return false
	kingdom = loaded_kingdom
	seed_value = int(data.get("seed", 0))
	battle_index = int(data.get("battle_index", 0))
	lives = int(data.get("lives", Balance.START_LIVES))
	max_lives = int(data.get("max_lives", Balance.START_LIVES))
	wins = int(data.get("wins", 0))
	bosses_beaten = int(data.get("bosses_beaten", 0))
	results.clear()
	for r in data.get("results", []):
		results.append(bool(r))
	last_battle_won = bool(data.get("last_battle_won", false))
	final_won = bool(data.get("final_won", false))
	last_life_restored = bool(data.get("last_life_restored", false))
	opponents.clear()
	for id in data.get("opponents", []):
		var opponent := KingdomCatalog.get_kingdom(StringName(id))
		if opponent == null:
			return false
		opponents.append(opponent)
	army.clear()
	for s in data.get("army", []):
		var unit := UnitCatalog.get_unit(StringName(s.get("unit", "")))
		if unit == null:
			return false
		var pos := Vector2.ZERO
		if s.has("pos"):
			var p: Array = s["pos"]
			pos = Formation.clamp_deploy(Vector2(float(p[0]), float(p[1])))
		else:  # eski kayıt: ızgara karesi
			var cell: Array = s.get("cell", [1, 0])
			pos = Formation.cell_to_deploy(Vector2i(int(cell[0]), int(cell[1])), GRID_SIZE)
		var squad := ArmySquad.new(unit, float(s.get("base_power", Balance.SQUAD_BUDGET)), pos)
		squad.attack_level = int(s.get("attack", 0))
		squad.defense_level = int(s.get("defense", 0))
		squad.reinforce_level = int(s.get("reinforce", 0))
		army.append(squad)
	passives.clear()
	for id in data.get("passives", []):
		var passive := PassiveCatalog.get_passive(StringName(id))
		if passive:
			passives.append(passive)
	perks = {}
	var saved_perks: Dictionary = data.get("perks", {})
	for key in saved_perks:
		perks[key] = int(saved_perks[key])
	rerolls_left = int(data.get("rerolls_left", 0))
	reroll_count = int(data.get("reroll_count", 0))
	locked.clear()
	for id in data.get("locked", []):
		locked.append(StringName(id))
	seals.clear()
	for id in data.get("seals", []):
		seals.append(StringName(id))
	last_changed = null
	active = true
	return true


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
