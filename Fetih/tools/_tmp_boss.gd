extends SceneTree
## Boss ayarı: her boss, kendi maliyeti kadar bütçeli normal bir bölüğe karşı (12 birliğin her biri)
## ve iki yarım bölüğe karşı savaşır. Hedef: ortalama ~%50.
## Çalıştırma: godot --headless --path Fetih -s res://tools/boss_test.gd

const SEEDS := 10
const NO_PASSIVES: Array[PassiveData] = []


func fight(boss: UnitData, other: UnitData, squads: int, seed_value: int, boss_is_player: bool) -> bool:
	var sim := BattleSimulation.new(seed_value, Rect2(0, 0, 9, 15))
	var boss_team := SquadState.Team.PLAYER if boss_is_player else SquadState.Team.ENEMY
	var other_team := SquadState.Team.ENEMY if boss_is_player else SquadState.Team.PLAYER
	var boss_army: Array[ArmySquad] = [ArmySquad.new(boss, boss.cost, ArmyGenerator.NO_CELL)]
	ArmyGenerator.auto_arrange(boss_army, Balance.GRID_SIZE)
	var other_army: Array[ArmySquad] = []
	for i in squads:
		other_army.append(ArmySquad.new(other, boss.cost / squads, ArmyGenerator.NO_CELL))
	ArmyGenerator.auto_arrange(other_army, Balance.GRID_SIZE)
	for s in boss_army:
		sim.add_squad(SquadBuilder.build(s, boss_team, NO_PASSIVES, Balance.GRID_SIZE))
	for s in other_army:
		sim.add_squad(SquadBuilder.build(s, other_team, NO_PASSIVES, Balance.GRID_SIZE))
	while not sim.finished:
		sim.step()
	var won := sim.winner == boss_team
	sim.dispose()
	return won


func _init() -> void:
	for kingdom in KingdomCatalog.all():
		if not OS.get_cmdline_user_args().has(String(kingdom.id)):
			continue
		var boss := kingdom.boss
		for squads in [1, 2]:
			var line := "%-18s vs %d bölük:" % [boss.display_name, squads]
			var total := 0
			for unit in UnitCatalog.all():
				var wins := 0
				for seed_value in range(1, SEEDS + 1):
					for side in [true, false]:
						if fight(boss, unit, squads, seed_value, side):
							wins += 1
				total += wins
				line += " %d" % roundi(wins * 100.0 / (SEEDS * 2))
			print(line, "   | ort %%%d" % roundi(total * 100.0 / (SEEDS * 2 * UnitCatalog.all().size())))
	UnitCatalog.clear_cache()
	KingdomCatalog.clear_cache()
	quit()
