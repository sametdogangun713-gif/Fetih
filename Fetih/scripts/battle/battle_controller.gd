extends Node2D
## Savaşı yürütür: simülasyonu sabit adımlarla ilerletir, bölük görüntülerini günceller.
## Aşama 2 test savaşı: 2 Ork Savaşçısı bölüğü (oyuncu) vs 2 Elf Okçusu bölüğü (düşman).
## R: aynı seed ile tekrar. N: yeni seed. Hız düğmeleri: x1 / x2 / x4.

const ORC_WARRIOR: UnitData = preload("res://data/units/orc_warrior.tres")
const ELF_ARCHER: UnitData = preload("res://data/units/elf_archer.tres")
const SPEEDS: Array[int] = [1, 2, 4]
const TEAM_NAMES := {
	SquadState.Team.PLAYER: "Oyuncu",
	SquadState.Team.ENEMY: "Düşman",
}

@onready var battlefield: Battlefield = $Battlefield
@onready var speed_buttons: HBoxContainer = $HUD/SpeedButtons
@onready var info_label: Label = $HUD/InfoLabel
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
	info_label.text = "Seed: %d   Süre: %.1f sn" % [_seed, simulation.elapsed]


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

	_add_squad(ORC_WARRIOR, 20, SquadState.Team.PLAYER, Vector2(3, 13))
	_add_squad(ORC_WARRIOR, 20, SquadState.Team.PLAYER, Vector2(6, 13))
	_add_squad(ELF_ARCHER, 20, SquadState.Team.ENEMY, Vector2(3, 2))
	_add_squad(ELF_ARCHER, 20, SquadState.Team.ENEMY, Vector2(6, 2))


func _add_squad(unit: UnitData, count: int, team: SquadState.Team, at: Vector2) -> void:
	var squad := SquadState.new(unit, team, count, at)
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
	result_label.text = "Kazanan: %s (%d asker hayatta)\nR: tekrar   N: yeni seed" % [
			TEAM_NAMES[winner], survivors]
