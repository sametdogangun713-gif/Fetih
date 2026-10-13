class_name Screens
## Ekranlar arası geçiş. Sahne yolları tek yerde durur.

const KINGDOM_SELECT := "res://scenes/ui/kingdom_select.tscn"
const PREP := "res://scenes/run/prep.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"
const CARD_SELECT := "res://scenes/ui/card_select.tscn"
const RUN_END := "res://scenes/ui/run_end.tscn"


static func goto(path: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.change_scene_to_file(path)


## Savaş bittikten sonra: koşu bittiyse sonuç ekranı, bitmediyse kart seçimi.
static func after_battle() -> void:
	if RunState.is_defeated() or RunState.is_last_battle():
		goto(RUN_END)
	else:
		goto(CARD_SELECT)
