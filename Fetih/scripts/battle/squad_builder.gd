class_name SquadBuilder
## Kalıcı bölük (ArmySquad) + seviyeler + fermanlar -> savaşa girecek SquadState.
## Birlik verisinin bir kopyası değiştirilir; asıl .tres dosyasına dokunulmaz.


static func build(squad: ArmySquad, team: SquadState.Team, passives: Array[PassiveData],
		grid_size: Vector2i) -> SquadState:
	var unit: UnitData = squad.unit.duplicate()
	var attack := Balance.level_multiplier(squad.attack_level)
	var defense := Balance.level_multiplier(squad.defense_level)
	# Saldırı sadece hasarı, Savunma sadece dayanıklılığı artırır: bkz. Balance.UPGRADE_STEP açıklaması.
	unit.damage *= attack * attack
	var toughness := defense * defense

	for passive in passives:
		if not passive.applies_to(squad, grid_size):
			continue
		if passive.stat == PassiveData.TOUGHNESS:
			toughness *= passive.amount
		else:
			var value: float = unit.get(passive.stat)
			unit.set(passive.stat, value * passive.amount if passive.is_multiplier else value + passive.amount)

	var state := SquadState.new(unit, team, squad.count,
			Formation.grid_to_field(squad.cell, grid_size, team))
	state.toughness = toughness
	state.level = squad.level()
	return state
