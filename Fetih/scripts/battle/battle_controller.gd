extends Node2D
## Savaşı yürütür: simülasyonu sabit adımlarla ilerletir, bölük görüntülerini günceller.
##
## İki modda çalışır:
## - Koşu modu (RunState.active): ordular RunState'ten gelir; savaş bitince "Devam" düğmesi çıkar.
## - Test modu (sahne tek başına, F6): seed'e göre rastgele iki birlik, taraf başına 2 bölük.
##   R: aynı savaşı tekrar. N: yeni seed ve yeni eşleşme.

const SPEEDS: Array[int] = [1, 2, 4]
const TEST_SQUAD_BUDGET := 100.0
const TEST_PLAYER_SLOTS: Array[Vector2] = [Vector2(3, 13), Vector2(6, 13)]
const TEST_ENEMY_SLOTS: Array[Vector2] = [Vector2(3, 2), Vector2(6, 2)]

@onready var battlefield: Battlefield = $Battlefield
@onready var speed_buttons: HBoxContainer = $HUD/SpeedButtons
@onready var info_label: Label = $HUD/InfoLabel
@onready var matchup_label: Label = $HUD/MatchupLabel
@onready var result_label: Label = $HUD/ResultLabel
@onready var continue_button: Button = $HUD/ContinueButton

var simulation: BattleSimulation
var _views := {}  ## SquadState -> SquadView
var _accumulator := 0.0
var _speed := 1
var _test_seed := 1
var _pause_menu: PauseMenu


func _ready() -> void:
	for i in SPEEDS.size():
		var button: Button = speed_buttons.get_child(i)
		button.pressed.connect(_set_speed.bind(SPEEDS[i]))
		button.pressed.connect(UiKit.click_sound)
	continue_button.pressed.connect(UiKit.click_sound)
	continue_button.pressed.connect(_on_continue)
	battlefield.set_debug_tools(not RunState.active)
	battlefield.fx.camera = battlefield.camera
	_set_speed(Settings.battle_speed)
	_pause_menu = PauseMenu.new(tr("Koşun kayıtlı. Ana menüye dönersen bu savaş baştan oynanır (sonuç değişmez).")
			if RunState.active else "")
	add_child(_pause_menu)
	var pause_button := Button.new()
	pause_button.text = "II"
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.tooltip_text = tr("Duraklat (Esc)")
	pause_button.pressed.connect(UiKit.click_sound)
	pause_button.pressed.connect(_pause_menu.open)
	speed_buttons.add_child(pause_button)  # en sağa: hız düğmelerinin sırası (get_child(i)) bozulmasın
	speed_buttons.offset_left -= 34
	_start_battle()
	Tips.show_once(self, Tips.BATTLE)


func _process(delta: float) -> void:
	# Simülasyon kare hızından bağımsız: biriken süre kadar sabit adım atılır.
	_accumulator += delta * _speed
	while _accumulator >= BattleSimulation.TICK:
		simulation.step()
		_accumulator -= BattleSimulation.TICK
	var alpha := _accumulator / BattleSimulation.TICK
	for view: SquadView in _views.values():
		view.update_visual(alpha, delta * _speed)
	battlefield.fx.advance(delta * _speed)
	if RunState.active:
		info_label.text = tr("Süre: %.1f sn") % simulation.elapsed
	else:
		info_label.text = "Seed: %d   Süre: %.1f sn   (R: tekrar, N: yeni)" % [_test_seed, simulation.elapsed]


func _exit_tree() -> void:
	if simulation:
		simulation.dispose()


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
	for view: SquadView in _views.values():
		view.queue_free()
	_views.clear()
	battlefield.fx.clear()
	_accumulator = 0.0
	result_label.text = ""
	continue_button.visible = false
	if simulation:
		simulation.dispose()

	var seed_value := RunState.battle_seed() if RunState.active else _test_seed
	simulation = BattleSimulation.new(seed_value, battlefield.field_rect())
	simulation.squad_attacked.connect(_on_squad_attacked)
	simulation.battle_finished.connect(_on_battle_finished)
	simulation.squad_spawned.connect(_on_squad_spawned)  # bölünen slime'ların yeni bölükleri
	simulation.squad_destroyed.connect(func(squad: SquadState) -> void: battlefield.fx.squad_down(_views[squad]))
	simulation.squad_revived.connect(func(squad: SquadState) -> void: battlefield.fx.revive(_views[squad]))

	if RunState.active:
		_setup_run_battle()
	else:
		_setup_test_battle()
	_start_music()


func _setup_run_battle() -> void:
	# Seviyeler ve fermanlar SquadBuilder'da uygulanır.
	for squad in RunState.build_player_squads():
		_add_state(squad)
	for squad in RunState.build_enemy_squads():
		_add_state(squad)
	var opponent := RunState.current_opponent()
	matchup_label.text = tr("Savaş %d / %d  -  Rakip: %s") % [RunState.battle_index + 1,
			Balance.RUN_LENGTH, tr(opponent.display_name)]
	if RunState.is_final_battle():
		matchup_label.text += tr("  -  BÜYÜK FETİH")
	elif RunState.is_boss_battle():
		matchup_label.text += tr("  -  BOSS: %s") % tr(opponent.boss.display_name)


func _setup_test_battle() -> void:
	var matchup := _choose_test_matchup()
	for slot in TEST_PLAYER_SLOTS:
		_add_squad(matchup[0], UnitCatalog.count_for_budget(matchup[0], TEST_SQUAD_BUDGET),
				SquadState.Team.PLAYER, slot)
	for slot in TEST_ENEMY_SLOTS:
		_add_squad(matchup[1], UnitCatalog.count_for_budget(matchup[1], TEST_SQUAD_BUDGET),
				SquadState.Team.ENEMY, slot)
	matchup_label.text = "%s  vs  %s" % [_describe(matchup[0]), _describe(matchup[1])]


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


func _add_squad(unit: UnitData, count: int, team: SquadState.Team, at: Vector2) -> void:
	_add_state(SquadState.new(unit, team, count, at))


func _add_state(squad: SquadState) -> void:
	simulation.add_squad(squad)
	_add_view(squad)


func _add_view(squad: SquadState) -> void:
	var view := SquadView.new()
	view.setup(squad)
	view.soldier_died.connect(battlefield.fx.soldier_died)
	battlefield.units.add_child(view)
	_views[squad] = view


## Boss savaşında boss müziği ve kükreme; diğerlerinde savaş müziği ve boru sesi.
func _start_music() -> void:
	var boss := false
	for squad: SquadState in _views:
		boss = boss or squad.unit.is_boss
	Audio.play_music("boss" if boss else "battle")
	Audio.play("boss_roar" if boss else "horn", -3.0, 0.0)


func _set_speed(value: int) -> void:
	_speed = value
	for i in SPEEDS.size():
		var button: Button = speed_buttons.get_child(i)
		button.disabled = SPEEDS[i] == value


## Uzak birlik yakına yakalanmadıysa mermi fırlatır; yoksa yakın dövüş vuruşu.
func _on_squad_attacked(attacker: SquadState, target: SquadState) -> void:
	var attacker_view: SquadView = _views[attacker]
	attacker_view.play_attack()
	var gap := attacker.position.distance_to(target.position) - 2.0 * BattleSimulation.SQUAD_RADIUS
	if attacker.unit.is_ranged() and gap > BattleSimulation.MELEE_GAP:
		battlefield.fx.launch(attacker_view, _views[target])
	else:
		battlefield.fx.melee_hit(attacker_view, _views[target])


func _on_squad_spawned(squad: SquadState) -> void:
	_add_view(squad)
	battlefield.fx.split(_views[squad])


func _on_battle_finished(winner: SquadState.Team) -> void:
	var won := winner == SquadState.Team.PLAYER
	var survivors := 0
	for squad: SquadState in _views:
		if squad.team == winner:
			survivors += squad.alive_count()
	Audio.play("victory" if won else "defeat", 0.0, 0.0, 0.0)
	if won:
		result_label.text = tr("ZAFER! (%d asker hayatta)") % survivors
		result_label.add_theme_color_override("font_color", UiKit.COLOR_GOOD)
	else:
		result_label.text = tr("YENİLGİ (rakipte %d asker kaldı)") % survivors
		result_label.add_theme_color_override("font_color", UiKit.COLOR_BAD)
	if RunState.active:
		RunState.finish_battle(won)
		# Sonuç hemen kaydedilir: kart ekranına geçmeden çıkılırsa da savaş sonucu kalıcıdır.
		var over := RunState.is_defeated() or RunState.is_last_battle()
		Profile.store_run(RunState.to_dict("end" if over else "cards"))
		continue_button.visible = true


func _on_continue() -> void:
	Screens.after_battle()
