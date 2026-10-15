extends Node2D
## Ana meydan: hazırlık, savaş ve kart seçimi aynı savaş alanında (9 Kings gibi).
## Aşama makinesi: PREP -> BATTLE -> CARDS -> PREP. Katmanlar (CanvasLayer) aşamaya göre görünür.
## Aşama değişince koşu kaydedilir; kayıttan dönen oyuncu aynı aşamaya girer.
## BATTLE: BattleHud + BattleRunner. CARDS: CardLayer (alt panel), kart etkisi alanda (apply_card).

enum Phase { PREP, BATTLE, CARDS }
const PHASE_NAMES := {Phase.PREP: "prep", Phase.BATTLE: "battle", Phase.CARDS: "cards"}
## İlk kamera çerçevesine eklenen ekran pikseli: üstte kalpler + aşama göstergesi, altta "Savaşa başla".
const FRAME_PAD_TOP := 26.0
const FRAME_PAD_BOTTOM := 34.0
const FRAME_PAD_LEFT := 30.0  ## Sol bilgi paneli.
const PICK_RADIUS := 0.6  ## Bölük seçme yarıçapı (karo): hazırlıkta sürükleme, kart aşamasında değiştirme.

@onready var battlefield: Battlefield = $Battlefield
var runner: BattleRunner
var prep: PrepLayer
var hud := BattleHud.new()
var cards := CardLayer.new()
var phase := Phase.PREP
var _pause_menu: PauseMenu


## Runner ve katman _init'te çocuk olarak eklenir (sahne ağaca girmeden serbest kalırsa birlikte silinir).
func _init() -> void:
	runner = BattleRunner.new()
	add_child(runner)
	prep = PrepLayer.new()


func _ready() -> void:
	if not RunState.active:  # sahne tek başına (F6) çalıştırılırsa deneme koşusu
		RunState.start_run(KingdomCatalog.all()[0], 1)
	runner.setup(battlefield)
	battlefield.set_debug_tools(false)
	RunField.apply_scenery(battlefield)
	# Duraklatma menüsü katmandan önce eklenir: sonradan eklenen düğüm girdiyi önce alır,
	# böylece ESC önce sürüklemeyi iptal edebilir.
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	add_child(prep)
	prep.setup(self)
	prep.start_pressed.connect(enter.bind(Phase.BATTLE))
	add_child(hud)
	hud.setup(runner, _pause_menu)
	hud.continue_pressed.connect(_after_battle)
	runner.finished.connect(finish_battle)
	add_child(cards)
	cards.setup(self)
	cards.card_taken.connect(apply_card)
	cards.skipped.connect(_next_battle)
	enter(_initial_phase())


## Açılış aşaması Screens.next_phase'ten gelir (kayıttan devam ederken resume_saved_run ayarlar;
## yeni koşuda "prep"). Okunduktan sonra sıfırlanır: eski kayıt yeni koşuyu etkilemez.
func _initial_phase() -> Phase:
	var wanted := Screens.next_phase
	Screens.next_phase = "prep"
	for p in PHASE_NAMES:
		if PHASE_NAMES[p] == wanted:
			return p
	return Phase.PREP


func enter(p: Phase) -> void:
	phase = p
	prep.visible = p == Phase.PREP
	hud.visible = p == Phase.BATTLE
	cards.visible = p == Phase.CARDS
	battlefield.ground_art.show_player_zone(p == Phase.PREP)
	_set_frame_pads(p)
	Profile.store_run(RunState.to_dict(PHASE_NAMES[p]))
	match p:
		Phase.PREP:
			_pause_menu.note = tr("Koşun kayıtlı: ana menüden \"Devam et\" ile buraya dönersin.")
			Audio.play_music("menu")
			_show_armies(true)
			prep.refresh()
			Tips.show_once(self, Tips.PREP)
		Phase.BATTLE:
			_pause_menu.note = tr("Koşun kayıtlı. Ana menüye dönersen bu savaş baştan oynanır (sonuç değişmez).")
			RunState.last_changed = null
			var states := RunState.build_player_squads()
			states.append_array(RunState.build_enemy_squads())
			hud.reset()
			hud.show_run_header()
			battlefield.camera.auto_follow = true
			runner.start(RunState.battle_seed(), states)
			RunField.apply_auras(runner)
			Tips.show_once(self, Tips.BATTLE)
		Phase.CARDS:
			_pause_menu.note = tr("Koşun kayıtlı: ana menüden \"Devam et\" ile buraya dönersin.")
			Audio.play_music("menu")
			_show_armies(false)  # alan temizlenir: ölüler ve efektler gider, ordu tam güçle yerinde
			for view in player_views():
				view.modulate.a = 0.0
				view.create_tween().tween_property(view, "modulate:a", 1.0, 0.3)
			cards.show_offers()
			Tips.show_once(self, Tips.CARDS)


## İlk kamera çerçevesindeki ekran payları aşamaya göre: arayüz sahneyi örtmesin.
func _set_frame_pads(p: Phase) -> void:
	match p:
		Phase.PREP:
			runner.frame_pad_top = FRAME_PAD_TOP
			runner.frame_pad_bottom = FRAME_PAD_BOTTOM
			runner.frame_pad_left = FRAME_PAD_LEFT
		Phase.CARDS:  # alt %40 kart paneli: alan üstte, panelin altına inmesin
			runner.frame_pad_top = 8.0
			runner.frame_pad_bottom = CardLayer.PANEL_HEIGHT
			runner.frame_pad_left = 0.0
		_:  # savaş: üstte kalpler + aşama göstergesi (alt şerit koşuda yok)
			runner.frame_pad_top = FRAME_PAD_TOP
			runner.frame_pad_bottom = 0.0
			runner.frame_pad_left = 0.0


## Savaşsız görüntü: oyuncu ordusu (+ istenirse rakip). Ordu sırası korunur (player_views).
func _show_armies(with_enemy: bool) -> void:
	var states := RunState.build_player_squads()
	if with_enemy:
		states.append_array(RunState.build_enemy_squads())
	runner.show_static(states)
	battlefield.camera.auto_follow = true
	runner.frame_all()


## Oyuncu bölüklerinin görüntüleri, ordu sırasıyla.
func player_views() -> Array[SquadView]:
	var out: Array[SquadView] = []
	for view: SquadView in runner.views().values():
		if view.squad.team == SquadState.Team.PLAYER:
			out.append(view)
	return out


## Savaş bitti (normalde runner.finished'ten; test kancası olarak da çağrılır): sonuç hemen kaydedilir,
## kart aşamasına geçmeden çıkılırsa da savaş sonucu kalıcıdır.
func finish_battle(won: bool, survivors := 0) -> void:
	if phase != Phase.BATTLE:
		return
	RunState.finish_battle(won)
	hud.update_run_header()  # kaybedilen savaşta kalp kırılır, aşama göstergesi ilerler
	var over := RunState.is_defeated() or RunState.is_last_battle()
	Profile.store_run(RunState.to_dict("end" if over else "cards"))
	hud.show_result(won, survivors, true)


func _after_battle() -> void:
	if RunState.is_defeated() or RunState.is_last_battle():
		Screens.goto(Screens.RUN_END)
	else:
		enter(Phase.CARDS)


## Fare altındaki oyuncu bölüğü (ordu sırası), yoksa -1. Bölük ~1 karo yarıçaplı daire sayılır.
func player_index_at(field_pos: Vector2) -> int:
	var best := -1
	var best_d := PICK_RADIUS
	for i in RunState.army.size():
		var d := Formation.deploy_to_field(RunState.army[i].pos, SquadState.Team.PLAYER).distance_to(field_pos)
		if d < best_d:
			best = i
			best_d = d
	return best


## Kart alanda uygulanır: yeni bölük arka kenardan yürür, yükseltilen/fermanlı bölükler parlar.
## Sonra sıradaki savaşın hazırlığına geçilir.
func apply_card(offer: CardOffer, replaced: ArmySquad = null) -> void:
	cards.visible = false
	var army_before := RunState.army.duplicate()
	var passives_before := RunState.passives.size()
	RunState.take_card(offer, replaced)
	_show_armies(false)
	var views := player_views()
	for i in RunState.army.size():
		var squad: ArmySquad = RunState.army[i]
		var view: SquadView = views[i]
		if not army_before.has(squad):
			_march_in(view)
		elif squad == RunState.last_changed:
			view.flash()
		elif RunState.passives.size() > passives_before:
			for passive in RunState.passives.slice(passives_before):
				if passive.applies_to(squad):
					view.flash()
	await get_tree().create_timer(0.9).timeout
	_next_battle()


## Yeni bölük arka kenarın dışından yerine yürür. SquadView her karede squad.position'dan konum aldığı için
## (_process'te update_visual) tween görüntüyü değil bölüğün alan konumunu sürer; yürüme animasyonu da buradan gelir.
func _march_in(view: SquadView) -> void:
	var state := view.squad
	var end := state.position
	var start := end + Vector2(0, 4)  # arka kenarın dışından
	state.position = start
	state.previous_position = start
	view.update_visual(1.0, 0.0)  # ilk karede bile başlangıç noktasında görünsün
	view.create_tween().tween_method(func(t: float) -> void:
		state.previous_position = end if t >= 1.0 else state.position
		state.position = start.lerp(end, t), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE)


func _next_battle() -> void:
	RunState.advance()
	RunField.apply_scenery(battlefield)
	enter(Phase.PREP)


## Savaşsız aşamalarda görüntüleri her karede günceller: boşta animasyonu, parlama ve yürüme tween'i çalışsın.
## Savaşta bunu BattleRunner yapar.
func _process(delta: float) -> void:
	if phase == Phase.CARDS and not runner.running:
		for view: SquadView in runner.views().values():
			view.update_visual(1.0, delta)
