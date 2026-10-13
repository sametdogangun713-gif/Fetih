class_name Screens
## Ekranlar arası geçiş. Sahne yolları tek yerde durur.

const KINGDOM_SELECT := "res://scenes/ui/kingdom_select.tscn"
const TREASURY := "res://scenes/ui/treasury.tscn"
const PREP := "res://scenes/run/prep.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"
const CARD_SELECT := "res://scenes/ui/card_select.tscn"
const RUN_END := "res://scenes/ui/run_end.tscn"

const PHASE_SCENES := {"prep": PREP, "battle": BATTLE, "cards": CARD_SELECT, "end": RUN_END}


static func goto(path: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.change_scene_to_file(path)


## Savaş bittikten sonra: koşu bittiyse sonuç ekranı, bitmediyse kart seçimi.
static func after_battle() -> void:
	if RunState.is_defeated() or RunState.is_last_battle():
		goto(RUN_END)
	else:
		goto(CARD_SELECT)


## Kayıtlı yarım koşuyu yükler ve kaldığı ekrana döner. Kayıt bozuksa siler, ana ekranda kalır.
static func resume_saved_run() -> void:
	if not RunState.from_dict(Profile.saved_run):
		push_warning("Kayıtlı koşu yüklenemedi; siliniyor.")
		Profile.clear_run()
		goto(KINGDOM_SELECT)
		return
	goto(PHASE_SCENES.get(String(Profile.saved_run.get("phase", "prep")), PREP))
