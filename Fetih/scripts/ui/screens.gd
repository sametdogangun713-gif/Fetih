class_name Screens
## Ekranlar arası geçiş. Sahne yolları tek yerde durur.

const KINGDOM_SELECT := "res://scenes/ui/kingdom_select.tscn"
const TREASURY := "res://scenes/ui/treasury.tscn"
const PREP := "res://scenes/run/prep.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"
const CARD_SELECT := "res://scenes/ui/card_select.tscn"
const RUN_END := "res://scenes/ui/run_end.tscn"

const PHASE_SCENES := {"prep": PREP, "battle": BATTLE, "cards": CARD_SELECT, "end": RUN_END}
const FADE_OUT := 0.15  ## Ekran kararma süresi (sn).
const FADE_IN := 0.2  ## Yeni ekranın açılma süresi.

static var _fading := false


## Ekran değiştirir: önce kararır, sahne değişir, sonra yeni ekran açılır.
## Perde bir CanvasLayer: sahne ağacının köküne (root) eklenir, sahne değişince silinmez.
## Tween perdenin rengini (alfa) canlandırır; tween_callback sahneyi tam karanlıkta değiştirir.
## Perde fareyi tutar: geçiş sırasında düğmelere ikinci kez basılamaz.
static func goto(path: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if _fading or DisplayServer.get_name() == "headless":  # testler beklemeden geçsin
		tree.change_scene_to_file(path)
		return
	_fading = true
	var layer := CanvasLayer.new()
	layer.layer = 100  # her şeyin (HUD, pencereler) üstünde
	layer.process_mode = Node.PROCESS_MODE_ALWAYS  # oyun duraklatılmışken de çalışsın
	var curtain := ColorRect.new()
	curtain.color = Color(UiKit.COLOR_BG, 0.0)
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(curtain)
	tree.root.add_child(layer)
	var tween := layer.create_tween()
	tween.tween_property(curtain, "color:a", 1.0, FADE_OUT)
	tween.tween_callback(tree.change_scene_to_file.bind(path))
	tween.tween_interval(0.03)  # yeni sahnenin ilk karesi kurulsun
	tween.tween_property(curtain, "color:a", 0.0, FADE_IN).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_fade_done.bind(layer))


static func _fade_done(layer: CanvasLayer) -> void:
	_fading = false
	layer.queue_free()


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
