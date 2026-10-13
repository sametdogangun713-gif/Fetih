class_name SquadView
extends Node2D
## Bir bölüğü ekrana çizer. Simülasyondaki SquadState'i sadece okur, hiçbir şeyi değiştirmez.
## Gerçek sprite'lar gelene kadar her asker küçük bir dikdörtgendir.

const COLUMNS := 5  ## Formasyonun genişliği (asker).
const SOLDIER_SPACING := 0.2  ## Askerler arası mesafe (karo).
## Geçici asker boyutu (piksel), role göre: rolü ekranda ayırt etmek için.
const ROLE_SIZES := {
	RoleRules.WARRIOR: Vector2(4, 9),
	RoleRules.SPEARMAN: Vector2(3, 10),
	RoleRules.TANK: Vector2(6, 10),
	RoleRules.ARCHER: Vector2(3, 8),
	RoleRules.MAGE: Vector2(3, 9),
	RoleRules.CAVALRY: Vector2(8, 8),
	RoleRules.SIEGE: Vector2(8, 5),
}
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
	var alive := mini(squad.alive_count(), _slots.size())
	while _alive_slots.size() > alive:
		_remove_front_soldier()
	# Onarım ve diriliş asker sayısını artırabilir: boş yerleri arkadan doldur.
	var i := _slots.size() - 1
	while _alive_slots.size() < alive and i >= 0:
		if not _alive_slots.has(i):
			_alive_slots.append(i)
		i -= 1
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
	if squad.unit.is_boss:
		_draw_boss(body, head)
		return
	var role := squad.unit.role
	var size: Vector2 = ROLE_SIZES.get(role, Vector2(4, 9))
	for o in offsets:
		var rect := Rect2(o - Vector2(size.x / 2.0, size.y), size)
		draw_rect(rect, body)
		draw_rect(Rect2(rect.position, Vector2(size.x, 2)), head)
		match role:
			RoleRules.SPEARMAN:  # mızrak ucu
				draw_line(rect.position + Vector2(size.x, 2), rect.position + Vector2(size.x, -4), Color("d0d0d0"))
			RoleRules.MAGE:  # parlayan asa ucu
				draw_rect(Rect2(rect.position + Vector2(size.x, -3), Vector2(2, 2)), Color("8ff0ff"))
			RoleRules.CAVALRY:  # binek gövdesi (alt yarı koyu)
				draw_rect(Rect2(rect.position + Vector2(0, size.y - 4), Vector2(size.x, 4)), body.darkened(0.4))
			RoleRules.SIEGE:  # top namlusu ve tekerlekler
				draw_rect(Rect2(rect.position + Vector2(size.x - 2, -2), Vector2(3, 2)), Color("404040"))
				draw_rect(Rect2(rect.position + Vector2(0, size.y - 1), Vector2(2, 2)), Color("3a2a1a"))
				draw_rect(Rect2(rect.position + Vector2(size.x - 2, size.y - 1), Vector2(2, 2)), Color("3a2a1a"))
		if squad.burn_time > 0.0:  # yanan bölüğün askerlerinin başında kıvılcım
			draw_rect(Rect2(rect.position + Vector2(0, -2), Vector2(2, 2)), Color("ff9a30"))
		elif squad.slow_time > 0.0:  # yavaşlatılmış bölük: ayakta çamur
			draw_rect(Rect2(rect.position + Vector2(0, size.y - 1), Vector2(size.x, 1)), Color("6a5a2a"))

	_draw_banner()


## Boss: tek dev figür, taç ve can çubuğu (tek asker olduğu için sayı yerine can gösterilir).
func _draw_boss(body: Color, head: Color) -> void:
	var size := Vector2(12, 22)
	var rect := Rect2(Vector2(-size.x / 2.0, -size.y), size)
	draw_rect(rect, body)
	draw_rect(Rect2(rect.position, Vector2(size.x, 4)), head)
	# taç
	var crown_y := rect.position.y - 3
	for x in [-6, -2, 3]:
		draw_rect(Rect2(Vector2(x, crown_y), Vector2(3, 3)), UiKit.COLOR_GOLD)
	# can çubuğu
	var max_hp := squad.unit.hp * squad.max_count
	var ratio := clampf(squad.hp_pool / max_hp, 0.0, 1.0)
	var bar := Rect2(Vector2(-14, crown_y - 6), Vector2(28, 3))
	draw_rect(bar, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), TEAM_COLORS[squad.team])
	draw_string(ThemeDB.fallback_font, Vector2(-30, crown_y - 9), squad.unit.display_name,
			HORIZONTAL_ALIGNMENT_CENTER, 60, 8, UiKit.COLOR_GOLD)


## Bölüğün üstünde takım renginde sancak ve asker sayısı.
func _draw_banner() -> void:
	var pole_top := Vector2(0, -26)
	draw_line(Vector2(0, -12), pole_top, Color("3a2a1a"), 1.0)
	draw_rect(Rect2(pole_top, Vector2(7, 5)), TEAM_COLORS[squad.team])
	var font := ThemeDB.fallback_font
	draw_string(font, pole_top + Vector2(-12, -2), str(squad.alive_count()),
			HORIZONTAL_ALIGNMENT_CENTER, 24, 10)
	# Seviye: sancak direğinin yanında küçük altın noktalar (Sv 2 = 1 nokta ... Sv 5 = 4 nokta).
	for i in squad.level - 1:
		draw_rect(Rect2(Vector2(-4, -24 + i * 3), Vector2(2, 2)), UiKit.COLOR_GOLD)
