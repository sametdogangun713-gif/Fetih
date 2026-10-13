extends SceneTree
## Otomatik koşu testi: RunState mantığını ekransız oynatır, zorluğu ölçer.
## Üç bot: greedy (kartın güç katkısını hesaplar), random, first (hep ilk kart).
## Çalıştırma: godot --headless --path Fetih -s res://tools/run_test.gd
## Hedef: greedy ortalama %50-60 fetih (fetih = 20. savaş kazanıldı).

const RunStateScript = preload("res://scripts/run/run_state.gd")
const RUNS := 40


func play_battle(run: Node) -> bool:
	var sim := BattleSimulation.new(run.battle_seed(), Rect2(0, 0, 9, 15))
	for s in run.build_player_squads():
		sim.add_squad(s)
	for s in run.build_enemy_squads():
		sim.add_squad(s)
	while not sim.finished:
		sim.step()
	var won := sim.winner == SquadState.Team.PLAYER
	sim.dispose()
	return won


func weakest(run: Node) -> ArmySquad:
	var best: ArmySquad = run.army[0]
	for s in run.army:
		if s.power() < best.power():
			best = s
	return best


## Kartın formüle göre güç katkısı (akıllı bot bunu en büyükleyen kartı seçer).
func gain(run: Node, offer: CardOffer) -> float:
	match offer.kind:
		CardOffer.Kind.UNIT:
			var existing: ArmySquad = run.find_squad(offer.unit)
			if existing:
				return upgrade_gain(existing, ArmySquad.Upgrade.REINFORCE)
			if run.needs_replace(offer):
				return Balance.SQUAD_BUDGET - weakest(run).power()
			return Balance.SQUAD_BUDGET
		CardOffer.Kind.UPGRADE:
			return upgrade_gain(offer.target, offer.upgrade)
	return 0.07 * run.army_power(run.army)


func upgrade_gain(s: ArmySquad, kind: ArmySquad.Upgrade) -> float:
	var k := s.upgrade_level(kind)
	return s.power() * (Balance.level_multiplier(k + 1) / Balance.level_multiplier(k) - 1.0)


## policy: "first" = alınabilen ilk kart; "random" = rastgele alınabilen kart
func play_run(kingdom: KingdomData, seed_value: int, policy: String, verbose: bool) -> Array:
	var run: Node = RunStateScript.new()
	run.start_run(kingdom, seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919
	var log := ""
	var kinds := ""
	while true:
		var won := play_battle(run)
		run.finish_battle(won)
		log += "W" if won else "L"
		if run.is_defeated() or run.is_last_battle():
			break
		var takeable: Array[CardOffer] = []
		for offer in run.card_offers():
			if run.can_take(offer):
				takeable.append(offer)
		var offer: CardOffer = null
		if policy == "greedy":
			var best_gain := 0.0
			for o in takeable:
				var g := gain(run, o)
				if g > best_gain:
					best_gain = g
					offer = o
		elif not takeable.is_empty():
			offer = takeable[0] if policy == "first" else takeable[rng.randi_range(0, takeable.size() - 1)]
		if offer:
			kinds += ["B", "Y", "F"][offer.kind]
			run.take_card(offer, weakest(run) if run.needs_replace(offer) else null)
		run.advance()
	if verbose:
		var army := ""
		for s in run.army:
			army += "%s Sv%d(%d), " % [s.unit.id, s.level(), roundi(s.power())]
		print("  %s %s seed %d: %s  kartlar=%s  ferman=%d  güç=%d  ordu: %s" % [kingdom.id, policy, seed_value, log, kinds,
				run.passives.size(), roundi(run.army_power(run.army)), army])
	var result := [run.is_victory(), run.wins, run.battle_index + 1]
	run.free()
	return result


func _init() -> void:
	var run: Node = RunStateScript.new()
	run.start_run(KingdomCatalog.all()[1], 42)
	var a: Array[ArmySquad] = run.current_enemy_army()
	var b: Array[ArmySquad] = run.current_enemy_army()
	var same := a.size() == b.size()
	for i in a.size():
		same = same and a[i].unit == b[i].unit and a[i].count == b[i].count and a[i].level() == b[i].level()
	print("Rakip ordu deterministik: ", same)
	print("Rakip gücü eğrisi: ", range(Balance.RUN_LENGTH).map(func(i): return roundi(Balance.enemy_power(i))))
	print("Beklenen oyuncu gücü: ", range(Balance.RUN_LENGTH).map(func(i): return roundi(Balance.expected_player_power(i))))
	run.free()

	for policy in ["greedy", "random", "first"]:
		print("=== politika: %s ===" % policy)
		for kingdom in KingdomCatalog.all():
			var victories := 0
			var total_wins := 0
			var total_battles := 0
			for seed_value in range(1, RUNS + 1):
				var r := play_run(kingdom, seed_value, policy, seed_value == 1)
				if r[0]:
					victories += 1
				total_wins += r[1]
				total_battles += r[2]
			print("%s: %d koşuda %d fetih (%%%d), savaş kazanma %%%d" % [kingdom.id, RUNS, victories,
					roundi(victories * 100.0 / RUNS), roundi(total_wins * 100.0 / total_battles)])
	UnitCatalog.clear_cache()
	KingdomCatalog.clear_cache()
	PassiveCatalog.clear_cache()
	quit()
