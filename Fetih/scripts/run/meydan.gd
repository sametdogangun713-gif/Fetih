extends Node2D
## Ana meydan: hazırlık, savaş ve kart seçimi aynı savaş alanında (9 Kings gibi).
## Aşama makinesi: PREP -> BATTLE -> CARDS -> PREP. Katmanlar (CanvasLayer) aşamaya göre görünür.
## Aşama değişince koşu kaydedilir; kayıttan dönen oyuncu aynı aşamaya girer.
## Şimdilik sadece PREP aşaması var; BATTLE ve CARDS sonraki adımlarda eklenir.

enum Phase { PREP, BATTLE, CARDS }
const PHASE_NAMES := {Phase.PREP: "prep", Phase.BATTLE: "battle", Phase.CARDS: "cards"}
## İlk kamera çerçevesine eklenen ekran pikseli: üstte şerit + harita, altta "Savaşa başla".
const FRAME_PAD_TOP := 56.0
const FRAME_PAD_BOTTOM := 34.0
const FRAME_PAD_LEFT := 30.0  ## Sol bilgi paneli.

@onready var battlefield: Battlefield = $Battlefield
var runner: BattleRunner
var prep: PrepLayer
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
	runner.frame_pad_top = FRAME_PAD_TOP
	runner.frame_pad_bottom = FRAME_PAD_BOTTOM
	runner.frame_pad_left = FRAME_PAD_LEFT
	battlefield.set_debug_tools(false)
	var opponent := RunState.current_opponent()
	battlefield.set_biome(opponent.id)
	battlefield.set_camps(RunState.kingdom, opponent)
	# Duraklatma menüsü katmandan önce eklenir: sonradan eklenen düğüm girdiyi önce alır,
	# böylece ESC önce sürüklemeyi iptal edebilir.
	_pause_menu = PauseMenu.new(tr("Koşun kayıtlı: ana menüden \"Devam et\" ile buraya dönersin."))
	add_child(_pause_menu)
	add_child(prep)
	prep.setup(self)
	prep.start_pressed.connect(enter.bind(Phase.BATTLE))
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
	battlefield.ground_art.show_player_zone(p == Phase.PREP)
	Profile.store_run(RunState.to_dict(PHASE_NAMES[p]))
	match p:
		Phase.PREP:
			Audio.play_music("menu")
			_show_armies(true)
			prep.refresh()
			Tips.show_once(self, Tips.PREP)


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
