class_name SquadView
extends Node2D
## Bir bölüğü ekrana çizer. Simülasyondaki SquadState'i sadece okur, hiçbir şeyi değiştirmez.
## Gerçek sprite'lar gelene kadar her asker küçük bir dikdörtgendir.

const COLUMNS := 5  ## Formasyonun genişliği (asker).
const SOLDIER_SPACING := 0.2  ## Askerler arası mesafe (karo).
const SOLDIER_SIZE := Vector2(4, 9)  ## Geçici asker boyutu (piksel).
const HIT_FLASH_TIME := 0.12
const TEAM_COLORS := {
	SquadState.Team.PLAYER: Color("3d6fd1"),
	SquadState.Team.ENEMY: Color("c8443a"),
}

var squad: SquadState

var _slots: Array[Vector2] = []  ## Her askerin formasyondaki yeri: x = yana, y = geriye (karo).
var _alive_slots: Array[int] = []
var _flash := 0.0
## Sadece görsel rastgelelik (hangi askerin düşeceği). Simülasyonun sonucunu etkilemez.
var _visual_rng := RandomNumberGenerator.new()


func setup(p_squad: SquadState) -> void:
	squad = p_squad
	var rows := ceili(float(squad.max_count) / COLUMNS)
	for i in squad.max_count:
		var col := i % COLUMNS
		var row := i / COLUMNS
		_slots.append(Vector2(
				(col - (COLUMNS - 1) / 2.0) * SOLDIER_SPACING,
				(row - (rows - 1) / 2.0) * SOLDIER_SPACING))
		_alive_slots.append(i)
	update_visual(1.0, 0.0)


## Her karede çağrılır. alpha: iki simülasyon adımı arasında nerede olduğumuz (0-1).
func update_visual(alpha: float, delta: float) -> void:
	position = Battlefield.field_to_world(squad.previous_position.lerp(squad.position, alpha))
	while _alive_slots.size() > squad.alive_count():
		_remove_front_soldier()
	_flash = maxf(_flash - delta, 0.0)
	visible = squad.is_alive()
	queue_redraw()


func flash() -> void:
	_flash = HIT_FLASH_TIME


## Ölen asker, en öndeki sıradan rastgele seçilir.
func _remove_front_soldier() -> void:
	var front_row := INF
	for slot in _alive_slots:
		front_row = minf(front_row, _slots[slot].y)
	var candidates: Array[int] = []
	for slot in _alive_slots:
		if is_equal_approx(_slots[slot].y, front_row):
			candidates.append(slot)
	_alive_slots.erase(candidates[_visual_rng.randi_range(0, candidates.size() - 1)])


func _draw() -> void:
	# Formasyonu bölüğün baktığı yöne çevir: ileri = facing, yan = ona dik.
	var forward := squad.facing
	var side := Vector2(-forward.y, forward.x)
	var offsets: Array[Vector2] = []
	for slot in _alive_slots:
		var s := _slots[slot]
		offsets.append(Battlefield.field_offset_to_world(side * s.x - forward * s.y))
	# Ekranda yukarıda olan asker önce çizilir (bölük içi derinlik sıralaması).
	offsets.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)

	var body := squad.unit.placeholder_color
	if _flash > 0.0:
		body = body.lerp(Color.WHITE, 0.7)
	var head := body.lightened(0.35)
	for o in offsets:
		var rect := Rect2(o - Vector2(SOLDIER_SIZE.x / 2.0, SOLDIER_SIZE.y), SOLDIER_SIZE)
		draw_rect(rect, body)
		draw_rect(Rect2(rect.position, Vector2(SOLDIER_SIZE.x, 2)), head)

	_draw_banner()


## Bölüğün üstünde takım renginde sancak ve asker sayısı.
func _draw_banner() -> void:
	var pole_top := Vector2(0, -26)
	draw_line(Vector2(0, -12), pole_top, Color("3a2a1a"), 1.0)
	draw_rect(Rect2(pole_top, Vector2(7, 5)), TEAM_COLORS[squad.team])
	var font := ThemeDB.fallback_font
	draw_string(font, pole_top + Vector2(-12, -2), str(squad.alive_count()),
			HORIZONTAL_ALIGNMENT_CENTER, 24, 10)
