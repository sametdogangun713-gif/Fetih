extends Node2D
## Savaşı yürütür: simülasyonu sabit adımlarla ilerletir, bölük görüntülerini günceller.
##
## İki modda çalışır:
## - Koşu modu (RunState.active): ordular RunState'ten gelir; savaş bitince "Devam" düğmesi çıkar.
## - Test modu (sahne tek başına, F6): seed'e göre rastgele iki birlik, taraf başına 2 bölük.
##   R: aynı savaşı tekrar. N: yeni seed ve yeni eşleşme.

const TEST_SQUAD_BUDGET := 100.0
const TEST_PLAYER_SLOTS: Array[Vector2] = [Vector2(3, 13), Vector2(6, 13)]
const TEST_ENEMY_SLOTS: Array[Vector2] = [Vector2(3, 2), Vector2(6, 2)]

@onready var battlefield: Battlefield = $Battlefield

## Savaş yürütme (simülasyon adımı, görüntüler, hit-stop, kamera) BattleRunner'da; HUD BattleHud'da
## (Meydan ile ortak); burada sadece koşu/test modu seçimi.
var runner: BattleRunner
var hud := BattleHud.new()
var _test_seed := 1
var _pause_menu: PauseMenu


## Runner _init'te eklenir: sahne ağaca girmeden serbest bırakılırsa (araçlar) çocuk olarak birlikte silinir.
func _init() -> void:
	runner = BattleRunner.new()
	add_child(runner)


func _ready() -> void:
	battlefield.set_debug_tools(not RunState.active)
	runner.setup(battlefield)
	runner.finished.connect(_on_battle_finished)
	_pause_menu = PauseMenu.new(tr("Koşun kayıtlı. Ana menüye dönersen bu savaş baştan oynanır (sonuç değişmez).")
			if RunState.active else "")
	add_child(_pause_menu)
	add_child(hud)
	hud.setup(runner, _pause_menu)
	hud.continue_pressed.connect(_on_continue)
	if not RunState.active:
		hud.info_text = func(elapsed: float) -> String:
			return tr("Seed: %d   Süre: %.1f sn   (R: tekrar, N: yeni)") % [_test_seed, elapsed]
	_start_battle()
	Tips.show_once(self, Tips.BATTLE)


func _unhandled_input(event: InputEvent) -> void:
	if RunState.active:
		return  # koşuda savaş tekrar oynanmaz
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				_start_battle()
			KEY_N:
				_test_seed += 1
				_start_battle()


func _start_battle() -> void:
	hud.reset()
	var states: Array[SquadState]
	if RunState.active:
		states = _setup_run_battle()
	else:
		states = _setup_test_battle()
	var seed_value := RunState.battle_seed() if RunState.active else _test_seed
	runner.start(seed_value, states)
	if RunState.active:
		RunField.apply_auras(runner)


## Koşu savaşı: durumlar RunState'ten (seviyeler ve fermanlar SquadBuilder'da uygulanır).
## Biyom, kamplar ve eşleşme yazısı burada; ferman aurası start'tan sonra (RunField.apply_auras).
func _setup_run_battle() -> Array[SquadState]:
	var states: Array[SquadState] = []
	states.append_array(RunState.build_player_squads())
	states.append_array(RunState.build_enemy_squads())
	RunField.apply_scenery(battlefield)
	hud.show_matchup(RunField.matchup_text())
	return states


func _setup_test_battle() -> Array[SquadState]:
	var matchup := _choose_test_matchup()
	battlefield.set_banners(KingdomCatalog.get_kingdom(&"humans"), KingdomCatalog.get_kingdom(&"orcs"))
	var states: Array[SquadState] = []
	for slot in TEST_PLAYER_SLOTS:
		states.append(SquadState.new(matchup[0], SquadState.Team.PLAYER,
				UnitCatalog.count_for_budget(matchup[0], TEST_SQUAD_BUDGET), slot))
	for slot in TEST_ENEMY_SLOTS:
		states.append(SquadState.new(matchup[1], SquadState.Team.ENEMY,
				UnitCatalog.count_for_budget(matchup[1], TEST_SQUAD_BUDGET), slot))
	hud.show_matchup(tr("%s  vs  %s") % [_describe(matchup[0]), _describe(matchup[1])])
	return states


## Seed'e göre iki farklı birlik seçer; aynı seed hep aynı eşleşmeyi verir.
func _choose_test_matchup() -> Array[UnitData]:
	var units := UnitCatalog.all()
	var rng := RandomNumberGenerator.new()
	rng.seed = _test_seed
	var a := rng.randi_range(0, units.size() - 1)
	var b := rng.randi_range(0, units.size() - 2)
	if b >= a:
		b += 1
	return [units[a], units[b]]


func _describe(unit: UnitData) -> String:
	return "2x%d %s (%s)" % [UnitCatalog.count_for_budget(unit, TEST_SQUAD_BUDGET),
			tr(unit.display_name), UiKit.role_name(unit.role)]


## Runner ses + yavaş çekimi yaptı; burada sonuç paneli ve (koşuda) kayıt.
func _on_battle_finished(won: bool, survivors: int) -> void:
	hud.show_result(won, survivors, RunState.active)
	if RunState.active:
		RunState.finish_battle(won)
		# Sonuç hemen kaydedilir: kart ekranına geçmeden çıkılırsa da savaş sonucu kalıcıdır.
		var over := RunState.is_defeated() or RunState.is_last_battle()
		Profile.store_run(RunState.to_dict("end" if over else "cards"))


## Koşu modunda (araçlar/F6) devam: sonuç ekranı ya da Meydan'ın kart aşaması.
func _on_continue() -> void:
	if RunState.is_defeated() or RunState.is_last_battle():
		Screens.goto(Screens.RUN_END)
	else:
		Screens.next_phase = "cards"
		Screens.goto(Screens.MEYDAN)
