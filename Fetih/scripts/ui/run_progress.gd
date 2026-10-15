class_name RunProgress
extends Control
## Koşu aşama göstergesi: 20 savaşlık ince yol, her savaş bir nokta. Geçilen yol altın, kazanılan nokta
## altın, kaybedilen kırmızı; şu anki nokta büyük ve nabız atar. Boss savaşlarının üstünde küçük taç.
## Rakip adı yazmaz: üstüne gelince ipucunda (savaş no, rakip, boss, mühür fırsatı, sonuç) görünür.
## Godot: _draw ile çizilir; tooltip_text boş değilse Godot ipucu için _get_tooltip(konum) çağırır.

const GAP := 10.0  ## Noktalar arası (düzen pikseli).
const DOT := 2.0  ## Nokta yarıçapı.
const CURRENT_DOT := 3.5
const PULSE_TIME := 1.0
const COLOR_ROAD := Color(1, 1, 1, 0.18)
const COLOR_FUTURE := Color("625565")

var _time := 0.0


func _init() -> void:
	tooltip_text = " "  # ipucu sisteminin _get_tooltip'i çağırması için boş olmayan bir değer
	custom_minimum_size = Vector2((Balance.RUN_LENGTH - 1) * GAP + CURRENT_DOT * 2 + 4, 16)


func current_index() -> int:
	return RunState.battle_index


func refresh() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()  # şu anki noktanın nabzı


func _dot_pos(i: int) -> Vector2:
	return Vector2(CURRENT_DOT + 2 + i * GAP, size.y - 6)


func _draw() -> void:
	var current := RunState.battle_index
	var last := Balance.RUN_LENGTH - 1
	draw_line(_dot_pos(0), _dot_pos(last), COLOR_ROAD, 1.0)
	if current > 0:
		draw_line(_dot_pos(0), _dot_pos(mini(current, last)), Color(UiKit.COLOR_GOLD, 0.8), 1.0)
	for i in Balance.RUN_LENGTH:
		var p := _dot_pos(i)
		if Balance.is_boss_battle(i):
			_draw_crown(p + Vector2(0, -6), Balance.is_final_battle(i), i <= current)
		if i < RunState.results.size():
			draw_circle(p, DOT, UiKit.COLOR_GOLD if RunState.results[i] else UiKit.COLOR_BAD)
		elif i == current:
			var pulse := sin(_time * TAU / PULSE_TIME) * 0.5 + 0.5
			draw_circle(p, CURRENT_DOT + 1.5 * pulse, Color(UiKit.COLOR_GOLD, 0.25 * (1.0 - pulse)))
			draw_circle(p, CURRENT_DOT, UiKit.COLOR_GOLD)
			draw_circle(p, CURRENT_DOT - 1.5, Color.WHITE)
		else:
			draw_circle(p, DOT, Color("2e222f"))
			draw_arc(p, DOT, 0, TAU, 12, COLOR_FUTURE, 1.0)


## Küçük taç (3 diş). Büyük fetih (son savaş) tacı biraz büyük.
func _draw_crown(at: Vector2, big: bool, reached: bool) -> void:
	var s := 1.4 if big else 1.0
	var c := UiKit.COLOR_GOLD if reached else Color(UiKit.COLOR_GOLD, 0.55)
	var pts := PackedVector2Array([
		at + Vector2(-3, 1) * s, at + Vector2(-3, -2) * s, at + Vector2(-1.5, 0) * s, at + Vector2(0, -3) * s,
		at + Vector2(1.5, 0) * s, at + Vector2(3, -2) * s, at + Vector2(3, 1) * s,
	])
	draw_colored_polygon(pts, c)


func _get_tooltip(at_position: Vector2) -> String:
	for i in Balance.RUN_LENGTH:
		if absf(at_position.x - _dot_pos(i).x) <= GAP / 2.0:
			var opponent: KingdomData = RunState.opponents[i]
			var text := tr("Savaş %d: %s") % [i + 1, tr(opponent.display_name)]
			if Balance.is_final_battle(i):
				text += tr(" - BÜYÜK FETİH (boss)")
			elif Balance.is_boss_battle(i):
				text += tr(" - BOSS")
			if Balance.is_boss_battle(i) and RunState.locked.has(opponent.id):
				text += tr(" - kilitli krallık: yenersen mühür")
			if i < RunState.results.size():
				text += tr(" - kazanıldı") if RunState.results[i] else tr(" - kaybedildi")
			return text
	return ""
