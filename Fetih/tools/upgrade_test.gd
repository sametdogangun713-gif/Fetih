extends SceneTree
## Yükseltme türleri gerçekten eşit değerde mi? Simülasyonla ölçer.
## A: 2 bölük, her biri taban 100 + verilen yükseltmeler.
## B: 2 bölük, aynı birlik, yükseltmesiz ama taban bütçesi A'nın formül gücüne eşit.
## Formül doğruysa A ~ %50 kazanmalı. Ölçüm gürültüsü ~ ±%10.
## Çalıştırma: godot --headless --path Fetih -s res://tools/upgrade_test.gd

const SEEDS := 20
const UNITS := [&"human_swordsman", &"elf_archer", &"orc_shieldbearer", &"human_knight", &"elf_mage", &"orc_warrior"]
const NO_PASSIVES: Array[PassiveData] = []


func fight(a: Array[ArmySquad], b: Array[ArmySquad], seed_value: int, a_is_player: bool) -> bool:
	var sim := BattleSimulation.new(seed_value, Rect2(0, 0, 9, 15))
	var team_a := SquadState.Team.PLAYER if a_is_player else SquadState.Team.ENEMY
	var team_b := SquadState.Team.ENEMY if a_is_player else SquadState.Team.PLAYER
	for s in a:
		sim.add_squad(SquadBuilder.build(s, team_a, NO_PASSIVES, Balance.GRID_SIZE))
	for s in b:
		sim.add_squad(SquadBuilder.build(s, team_b, NO_PASSIVES, Balance.GRID_SIZE))
	while not sim.finished:
		sim.step()
	var won := sim.winner == team_a
	sim.dispose()
	return won


func make(unit: UnitData, base: float, levels: Array) -> Array[ArmySquad]:
	var army: Array[ArmySquad] = []
	for i in 2:
		var s := ArmySquad.new(unit, base, ArmyGenerator.NO_CELL)
		for kind in levels:
			s.upgrade(kind)
		army.append(s)
	ArmyGenerator.auto_arrange(army, Balance.GRID_SIZE)
	return army


func _init() -> void:
	var A := ArmySquad.Upgrade.ATTACK
	var D := ArmySquad.Upgrade.DEFENSE
	var R := ArmySquad.Upgrade.REINFORCE
	var cases := {
		"Saldırı x1": [A], "Savunma x1": [D], "Takviye x1": [R],
		"Saldırı x4 (Sv5)": [A, A, A, A], "Savunma x4 (Sv5)": [D, D, D, D], "Takviye x4 (Sv5)": [R, R, R, R],
		"Karışık 2+1+1 (Sv5)": [A, A, D, R],
	}
	print("Satır: yükseltilmiş bölük vs formül gücünde yükseltmesiz bölük. Hedef ~%50.")
	for name in cases:
		var line := "%-20s" % name
		var total_wins := 0
		var total := 0
		for unit_id in UNITS:
			var unit := UnitCatalog.get_unit(unit_id)
			var upgraded := make(unit, 100.0, cases[name])
			var equivalent := make(unit, upgraded[0].power(), [])
			var wins := 0
			for seed_value in range(1, SEEDS + 1):
				for side in [true, false]:
					if fight(upgraded, equivalent, seed_value, side):
						wins += 1
			total_wins += wins
			total += SEEDS * 2
			line += "  %s %3d%%" % [String(unit_id).get_slice("_", 1).substr(0, 6), roundi(wins * 100.0 / (SEEDS * 2))]
		print(line, "   | ort %d%%  (güç %.0f)" % [roundi(total_wins * 100.0 / total), make(UnitCatalog.all()[0], 100.0, cases[name])[0].power()])
	UnitCatalog.clear_cache()
	quit()
