class_name RunField
## Koşu savaş alanı hazırlığı: biyom, krallık kampları ve ferman aurası.
## Meydan ve battle.tscn (koşu modu) aynı kodu kullanır; hepsi sadece görüntüdür.


## Zemin biyomu rakip krallığa göre, kamplar iki krallığa göre kurulur.
static func apply_scenery(battlefield: Battlefield) -> void:
	var opponent := RunState.current_opponent()
	battlefield.set_biome(opponent.id)
	battlefield.set_camps(RunState.kingdom, opponent)


## Ferman aurası: build_*_squads sırası ordu sırasıyla aynıdır, görüntüler ekleme sırasındadır.
## Savaş başladıktan (runner.start) sonra çağrılır.
static func apply_auras(runner: BattleRunner) -> void:
	var views := runner.views().values()
	var player_count := RunState.army.size()
	var enemy_army := RunState.current_enemy_army()
	var enemy_fermans := RunState.enemy_passives()
	for i in player_count:
		views[i].aura_color = SquadView.aura_color_for(RunState.army[i], RunState.passives)
	for i in enemy_army.size():
		views[player_count + i].aura_color = SquadView.aura_color_for(enemy_army[i], enemy_fermans)


## Sol üst kutu: "Savaş n / 20 · Rakip: X" (+ büyük fetih / boss).
static func matchup_text() -> String:
	var opponent := RunState.current_opponent()
	var text := UiKit.t("Savaş %d / %d  ·  Rakip: %s") % [RunState.battle_index + 1, Balance.RUN_LENGTH,
			UiKit.t(opponent.display_name)]
	if RunState.is_final_battle():
		text += UiKit.t("  ·  BÜYÜK FETİH")
	elif RunState.is_boss_battle():
		text += UiKit.t("  ·  BOSS: %s") % UiKit.t(opponent.boss.display_name)
	return text
