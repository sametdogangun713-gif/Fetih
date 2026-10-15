class_name KingdomBanner
extends Control
## Krallık seçimindeki dalgalanan sancak: direk + krallık renginde bez + ortada amblem, altında ad.
## Seçilince yukarı kalkar ve arkasında altın ışık belirir; fare üstündeyken dalga büyür.
## Kilitli krallık: gri bez, çapraz zincir ve küçük kilit. Tıklanınca picked sinyali.
## Godot: _draw her karede (dalga) yeniden çizilir; seçim kalkışı Tween ile _lift'i canlandırır.

signal picked(kingdom: KingdomData)

const SIZE := Vector2(54, 86)
const CLOTH := Rect2(12, 12, 36, 40)  ## Bezin dalgasız kutusu.
const LIFT := 8.0
const COLUMN := 2.0  ## Dalga sütun genişliği.

var kingdom: KingdomData
var unlocked := true
var name_label: Label
var selected := false:
	set(value):
		if selected == value:
			return
		selected = value
		var tw := create_tween()
		tw.tween_property(self, "_lift", LIFT if value else 0.0, 0.22 * UiKit.anim_scale()) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

var _lift := 0.0
var _time := 0.0
var _hover := false
var _emblem: Texture2D


func _init(p_kingdom: KingdomData, p_unlocked: bool) -> void:
	kingdom = p_kingdom
	unlocked = p_unlocked
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tooltip_text = UiKit.t(kingdom.display_name) + ("" if unlocked else "  (%s)" % UiKit.t("kilitli"))
	var emblem_color := kingdom.accent_color if unlocked else Color("9babb2")
	_emblem = BannerArt.emblem_texture(kingdom.id, emblem_color, 3)
	name_label = UiKit.label(UiKit.t(kingdom.display_name), 9, UiKit.COLOR_PARCHMENT if unlocked else UiKit.COLOR_MUTED)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_color_override("font_outline_color", Color("2e222f"))
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.position = Vector2(0, SIZE.y - 16)
	name_label.size = Vector2(SIZE.x, 14)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void: _hover = false)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		UiKit.click_sound()
		picked.emit(kingdom)
		accept_event()


func _draw() -> void:
	var up := Vector2(0, -_lift)
	if selected:  # arkada altın ışık
		var center := CLOTH.get_center() + up
		for i in 3:
			draw_circle(center, 22.0 + i * 5.0, Color(UiKit.COLOR_GOLD, 0.10 - i * 0.025))
	# Direk ve topuz
	draw_rect(Rect2(Vector2(CLOTH.position.x - 3, CLOTH.position.y - 4) + up, Vector2(2, 62)), Color("694f62"))
	draw_circle(Vector2(CLOTH.position.x - 2, CLOTH.position.y - 5) + up, 2.0, UiKit.COLOR_GOLD)
	# Bez: sütun sütun dalga (direğe yakın sabit, uca doğru büyür)
	var main := kingdom.color if unlocked else Color("625565")
	var dark := main.darkened(0.3)
	var amp := 2.6 if _hover else 1.6
	var x := 0.0
	while x < CLOTH.size.x:
		var k := x / CLOTH.size.x
		var dy := sin(x * 0.2 - _time * 4.0) * amp * k
		var tail := maxf(0.0, 8.0 - absf(x + COLUMN / 2.0 - CLOTH.size.x / 2.0)) * 0.9  # kırlangıç kuyruğu
		var top := CLOTH.position + Vector2(x, dy) + up
		draw_rect(Rect2(top, Vector2(COLUMN, CLOTH.size.y - tail)), dark if x < COLUMN else main)
		draw_rect(Rect2(top + Vector2(0, CLOTH.size.y - tail - 7), Vector2(COLUMN, 2)), Color(kingdom.accent_color if unlocked else Color("3e3546"), 0.9))
		x += COLUMN
	var mid_dy := sin(CLOTH.size.x * 0.5 * 0.2 - _time * 4.0) * amp * 0.5
	var emblem_at := CLOTH.position + Vector2((CLOTH.size.x - _emblem.get_width()) / 2.0, 7 + mid_dy) + up
	draw_texture(_emblem, emblem_at.round())
	if not unlocked:
		var a := CLOTH.position + up
		var chain := Color("9babb2")
		draw_line(a + Vector2(-2, 4), a + CLOTH.size + Vector2(2, -8), chain, 2.0)
		draw_line(a + Vector2(CLOTH.size.x + 2, 4), a + Vector2(-2, CLOTH.size.y - 8), chain, 2.0)
		var lock_at := a + Vector2(CLOTH.size.x / 2.0 - 5, CLOTH.size.y - 16)
		draw_arc(lock_at + Vector2(5, 2), 3.5, PI, TAU, 8, Color("c7dcd0"), 1.5)
		draw_rect(Rect2(lock_at + Vector2(0, 2), Vector2(10, 8)), UiKit.COLOR_GOLD)
		draw_rect(Rect2(lock_at + Vector2(4, 4), Vector2(2, 3)), Color("2e222f"))
