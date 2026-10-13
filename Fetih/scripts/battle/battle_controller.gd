extends Node2D
## Savaşı yürütür: simülasyonu sabit adımlarla ilerletir, bölük görüntülerini günceller.
## Aşama 3 test savaşı: katalogdan seed'e göre seçilen iki birlik, taraf başına 2 bölük, eşit bütçe.
## R: aynı savaşı tekrar. N: yeni seed ve yeni eşleşme. Hız düğmeleri: x1 / x2 / x4.

const SPEEDS: Array[int] = [1, 2, 4]
const SQUAD_BUDGET := 100.0
const PLAYER_SLOTS: Array[Vector2] = [Vector2(3, 13), Vector2(6, 13)]
const ENEMY_SLOTS: Array[Vector2] = [Vector2(3, 2), Vector2(6, 2)]
const TEAM_NAMES := {
	SquadState.Team.PLAYER: "Oyuncu",
	SquadState.Team.ENEMY: "Düşman",
}

@onready var battlefield: Battlefield = $Battlefield
@onready var speed_buttons: HBoxContainer = $HUD/SpeedButtons
@onready var info_label: Label = $HUD/InfoLabel
@onready var matchup_label: Label = $HUD/MatchupLabel
@onready var result_label: Label = $HUD/ResultLabel

var simulation: BattleSimulation
var _views := {}  ## SquadState -> SquadView
var _accumulator := 0.0
var _speed := 1
var _seed := 1


func _ready() -> void:
	for i in SPEEDS.size():
		var button: Button = speed_buttons.get_child(i)
		button.pressed.connect(_set_speed.bind(SPEEDS[i]))
	_set_speed(1)
	_start_battle()


func _process(delta: float) -> void:
	# Simülasyon kare hızından bağımsız: biriken süre kadar sabit adım atılır.
	_accumulator += delta * _speed
	while _accumulator >= BattleSimulation.TICK:
		simulation.step()
		_accumulator -= BattleSimulation.TICK
	var alpha := _accumulator / BattleSimulation.TICK
	for view: SquadView in _views.values():
		view.update_visual(alpha, delta)
	info_label.text = "Seed: %d   Süre: %.1f sn   (R: tekrar, N: yeni)" % [_seed, simulation.elapsed]


func _exit_tree() -> void:
	if simulation:
		simulation.dispose()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				_start_battle()
			KEY_N:
				_seed += 1
				_start_battle()


func _start_battle() -> void:
	for view: SquadView in _views.values():
		view.queue_free()
	_views.clear()
	_accumulator = 0.0
	result_label.text = ""
	if simulation:
		simulation.dispose()

	simulation = BattleSimulation.new(_seed, battlefield.field_rect())
	simulation.squad_attacked.connect(_on_squad_attacked)
	simulation.battle_finished.connect(_on_battle_finished)

	var matchup := _choose_matchup()
	var player_unit: UnitData = matchup[0]
	var enemy_unit: UnitData = matchup[1]
	for slot in PLAYER_SLOTS:
		_add_squad(player_unit, SquadState.Team.PLAYER, slot)
	for slot in ENEMY_SLOTS:
		_add_squad(enemy_unit, SquadState.Team.ENEMY, slot)
	matchup_label.text = "%s  vs  %s" % [_describe(player_unit), _describe(enemy_unit)]


## Seed'e göre iki farklı birlik seçer; aynı seed hep aynı eşleşmeyi verir.
func _choose_matchup() -> Array[UnitData]:
	var units := UnitCatalog.all()
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var a := rng.randi_range(0, units.size() - 1)
	var b := rng.randi_range(0, units.size() - 2)
	if b >= a:
		b += 1
	return [units[a], units[b]]


func _describe(unit: UnitData) -> String:
	return "2x%d %s (%s)" % [UnitCatalog.count_for_budget(unit, SQUAD_BUDGET), unit.display_name,
			RoleRules.ROLE_NAMES[unit.role]]


func _add_squad(unit: UnitData, team: SquadState.Team, at: Vector2) -> void:
	var squad := SquadState.new(unit, team, UnitCatalog.count_for_budget(unit, SQUAD_BUDGET), at)
	simulation.add_squad(squad)
	var view := SquadView.new()
	view.setup(squad)
	battlefield.units.add_child(view)
	_views[squad] = view


func _set_speed(value: int) -> void:
	_speed = value
	for i in SPEEDS.size():
		var button: Button = speed_buttons.get_child(i)
		button.disabled = SPEEDS[i] == value


func _on_squad_attacked(_attacker: SquadState, target: SquadState) -> void:
	_views[target].flash()


func _on_battle_finished(winner: SquadState.Team) -> void:
	var survivors := 0
	for squad: SquadState in _views:
		if squad.team == winner:
			survivors += squad.alive_count()
	result_label.text = "Kazanan: %s (%d asker hayatta)" % [TEAM_NAMES[winner], survivors]
