extends Control
## Ana menü (oyunun açılış ekranı): canlı manzara (MenuBackdrop), solda FETİH logosu ve düğmeler
## (Devam et / Yeni oyun / Hazine / İstatistikler / Ayarlar / Çık), sağ altta Şan ve sürüm.
## Oyun açılışında bir kez logo açılışı oynar: harfler sırayla düşer, kılıç parıltısı geçer, perde açılır.
## Herhangi bir tık/tuş açılışı geçer. Yarım koşu varken "Yeni oyun" onay sorar; kayıt, yeni koşu
## gerçekten başlayınca (krallık seçiminde) değişir, onay ekranında silinmez.
## Godot: Tween zinciri (tween_property / tween_interval / tween_callback) açılışı sırayla oynatır;
## kill() ile yarıda kesilir.

const LOGO := "FETİH"  ## Harfler tek tek düşer (Türkçe büyük İ: to_upper kullanılmaz).
const BUTTON_WIDTH := 160.0

static var intro_done := false  ## Açılış oyun başına bir kez (menüye dönüşte oynamaz).

var force_intro := false  ## Test/gösterim: açılış yine oynasın.

var _buttons: Array[Button] = []
var _menu_column: VBoxContainer
var _logo: Label
var _intro_root: Control
var _intro_tween: Tween
var _reveal_tweens: Array[Tween] = []
var _reveal_gen := 0  ## Her ortaya çıkışta artar: bekleyen eski animasyon yarıda kalırsa devam etmez.
var _confirm: Overlay
var _subtitle: Label
var _extras: Array[CanvasItem] = []  ## Logo dışında açılışta gizlenen yazılar (alt başlık, devam bilgisi).
var _sparkles: Control


func _ready() -> void:
	Audio.play_music("menu")
	RunState.end_run()
	theme = UiKit.theme_menu()
	add_child(MenuBackdrop.new())
	_build_menu()
	_build_corner()
	if force_intro or not intro_done:
		_play_intro()
	else:
		_reveal(false)


func buttons() -> Array[Button]:
	return _buttons


func intro_playing() -> bool:
	return _intro_root != null


func is_confirming() -> bool:
	return _confirm != null


func logo() -> Label:
	return _logo


func subtitle() -> Label:
	return _subtitle


func _build_menu() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	_menu_column = UiKit.vbox(4)
	margin.add_child(_menu_column)
	_logo = UiKit.label(LOGO, 44, UiKit.COLOR_GOLD, true)
	_logo.add_theme_font_override("font", UiKit.heading_font(900))
	_logo.add_theme_color_override("font_outline_color", Color("2e222f"))
	_logo.add_theme_constant_override("outline_size", 6)
	_logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	_logo.add_theme_constant_override("shadow_offset_y", 3)
	_menu_column.add_child(_logo)
	_sparkles = _LogoSparkles.new()
	_logo.add_child(_sparkles)
	_subtitle = UiKit.label(tr("Krallıkları fethet"), 12, UiKit.COLOR_PARCHMENT)
	_subtitle.add_theme_color_override("font_outline_color", Color("2e222f"))
	_subtitle.add_theme_constant_override("outline_size", 4)
	_menu_column.add_child(_subtitle)
	_extras.append(_subtitle)
	_menu_column.add_child(_gap(14))
	var has_run := Profile.has_saved_run()
	if has_run:
		var cont := UiKit.button_primary(tr("Devam et"), _on_continue)
		_add_button(cont)
		var info := UiKit.label(_continue_info(), 9, UiKit.COLOR_PARCHMENT)
		info.add_theme_color_override("font_outline_color", Color("2e222f"))
		info.add_theme_constant_override("outline_size", 3)
		_menu_column.add_child(info)
		_extras.append(info)
	var new_game := UiKit.button_primary(tr("Yeni oyun"), _on_new_game) if not has_run \
			else UiKit.button(tr("Yeni oyun"), _on_new_game)
	_add_button(new_game)
	_add_button(UiKit.button(tr("Hazine"), func() -> void: Screens.goto(Screens.TREASURY)))
	_add_button(UiKit.button(tr("İstatistikler"), func() -> void: StatsPanel.open(self)))
	_add_button(UiKit.button(tr("Ayarlar"), func() -> void: SettingsPanel.open(self, true)))
	var quit := UiKit.button_ghost(tr("Çık"), func() -> void: get_tree().quit())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		quit.add_theme_color_override(key, UiKit.COLOR_PARCHMENT)  # koyu manzarada okunsun
	quit.add_theme_color_override("font_outline_color", Color("2e222f"))
	quit.add_theme_constant_override("outline_size", 3)
	_add_button(quit)


func _add_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, 24)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UiKit.set_font_size(button, 13)
	if button.text == tr("Devam et") or (button.text == tr("Yeni oyun") and not Profile.has_saved_run()):
		button.add_theme_font_override("font", UiKit.ui_font(800))
	_menu_column.add_child(button)
	_buttons.append(button)
	# Fare üstünde düğme hafifçe sağa kayar (kapsayıcı konumu yeniden dizince sıfırlanır; dizim ancak
	# boyut değişince olur). Taban konum ortaya çıkış animasyonundan sonra kaydedilir.
	button.mouse_entered.connect(_nudge.bind(button, true))
	button.mouse_exited.connect(_nudge.bind(button, false))


func _nudge(button: Button, on: bool) -> void:
	if not button.has_meta("base_x") or button.disabled:
		return
	var tw := button.create_tween()
	tw.tween_property(button, "position:x", float(button.get_meta("base_x")) + (8.0 if on else 0.0), 0.12) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	return c


## Sağ alt köşe: Şan ve sürüm.
func _build_corner() -> void:
	var corner := UiKit.vbox(0)
	corner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.offset_right = -10
	corner.offset_bottom = -8
	add_child(corner)
	for line: Array in [[tr("Şan: %d") % Profile.glory, 12, UiKit.COLOR_GOLD],
			["v%s" % ProjectSettings.get_setting("application/config/version"), 9, UiKit.COLOR_PARCHMENT]]:
		var l := UiKit.label(line[0], line[1], line[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.add_theme_color_override("font_outline_color", Color("2e222f"))
		l.add_theme_constant_override("outline_size", 3)
		corner.add_child(l)


func _continue_info() -> String:
	var data := Profile.saved_run
	var kingdom := KingdomCatalog.get_kingdom(StringName(data.get("kingdom", "")))
	var name := tr(kingdom.display_name) if kingdom else "?"
	return tr("%s · savaş %d") % [name, int(data.get("battle_index", 0)) + 1]


# --- Açılış ---

## Siyah perde üstünde FETİH harfleri sırayla düşer, kılıç parıltısı geçer; sonra logo küçülerek menüdeki
## yerine uçar ve perde aynı anda açılır (logo hiç kaybolmaz). Ardından alt başlık ve düğmeler gelir.
func _play_intro() -> void:
	intro_done = true
	for item: CanvasItem in _hidden_items():
		item.modulate.a = 0.0
	_intro_root = Control.new()
	_intro_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_intro_root)
	var curtain := ColorRect.new()
	curtain.color = Color("0c0a10")
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro_root.add_child(curtain)
	var row := UiKit.hbox(0)  # harfler doğal genişlikte: aralık eşit
	_intro_root.add_child(row)
	var letters: Array[Label] = []
	for ch in LOGO:
		var l := _logo_label(ch)
		var holder := Control.new()  # boyutu _center_row'da (etiket ağaçtayken ölçülebilir)
		row.add_child(holder)
		l.position.y = -60
		l.modulate.a = 0.0
		holder.add_child(l)
		letters.append(l)
	var flash := ColorRect.new()  # kılıç parıltısı: perdenin çocuğu (kapsayıcı dizmez)
	flash.color = Color(1, 1, 0.9, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_root.add_child(flash)
	var k := UiKit.anim_scale()
	_intro_tween = create_tween()
	_intro_tween.tween_callback(_center_row.bind(row))  # yerleşim bitince ortala
	for i in letters.size():
		_intro_tween.parallel().tween_property(letters[i], "position:y", 0.0, 0.45 * k) \
				.set_delay(i * 0.12 * k).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_intro_tween.parallel().tween_property(letters[i], "modulate:a", 1.0, 0.2 * k).set_delay(i * 0.12 * k)
	_intro_tween.tween_callback(_sword_flash.bind(row, flash, 0.35 * k))
	_intro_tween.tween_interval(0.55 * k)
	_intro_tween.tween_callback(_fly_logo.bind(row, curtain, 0.6 * k))
	_intro_tween.tween_interval(0.62 * k)
	_intro_tween.tween_callback(_end_intro)


## Menü logosuyla aynı biçimde büyük harf etiketi (açılış harfleri).
func _logo_label(text: String) -> Label:
	var l := UiKit.label(text, 56, UiKit.COLOR_GOLD, true)
	l.add_theme_font_override("font", UiKit.heading_font(900))
	l.add_theme_color_override("font_outline_color", Color("2e222f"))
	l.add_theme_constant_override("outline_size", 7)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_y", 4)
	return l


## Harf kutuları etiketlerin gerçek genişliğine göre (ağaca girmeden önce ölçü 0 döner), sonra satır ortalanır.
func _center_row(row: Control) -> void:
	for holder in row.get_children():
		var l := holder.get_child(0) as Label
		holder.custom_minimum_size = l.get_minimum_size()
		l.size = holder.custom_minimum_size
	row.reset_size()
	row.position = ((size - row.size) / 2.0).round()


## Logonun üstünden soldan sağa geçen ince parlak şerit; sona varmadan tamamen söner (iz kalmaz).
func _sword_flash(row: Control, flash: ColorRect, time: float) -> void:
	var r := row.get_global_rect()
	flash.position = Vector2(r.position.x - 10, r.position.y + 4)
	flash.size = Vector2(4, r.size.y - 8)
	flash.color.a = 0.9
	Audio.play("hit", -6.0)
	var tw := flash.create_tween().set_parallel()
	tw.tween_property(flash, "position:x", r.end.x - 6, time).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(flash, "color:a", 0.0, time * 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(flash.hide)


## Açılış harfleri menü logosunun yerine uçar (konum + ölçek), perde aynı anda solar.
func _fly_logo(row: Control, curtain: ColorRect, time: float) -> void:
	var target := _logo.get_global_rect()
	var scale := target.size.y / maxf(row.size.y, 1.0)
	var tw := row.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(row, "scale", Vector2.ONE * scale, time)
	tw.tween_property(row, "position", target.position, time)
	tw.tween_property(curtain, "color:a", 0.0, time * 0.9)


func _end_intro() -> void:
	_logo.modulate.a = 1.0  # uçan harfler tam logonun yerinde: değiş tokuş görünmez
	if _intro_root:
		_intro_root.queue_free()
		_intro_root = null
	_reveal(false, true)


## Açılışı hemen bitirir (tık/tuş ya da test): tween'ler kesilir, menü son hâline gelir.
func skip_intro() -> void:
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	if _intro_root:
		_intro_root.queue_free()
		_intro_root = null
	_reveal(true)


func _hidden_items() -> Array[CanvasItem]:
	var items: Array[CanvasItem] = [_logo]
	items.append_array(_extras)
	items.append_array(_buttons)
	return items


## Logo, alt başlık ve düğmeler görünür olur. instant değilse: logo (açılıştan geliyorsa zaten yerinde),
## alt başlık solar, düğmeler soldan sırayla kayarak gelir. Logo yavaşça parlar, çevresinde ışıltılar.
func _reveal(instant: bool, logo_ready := false) -> void:
	for tw in _reveal_tweens:
		if tw.is_valid():
			tw.kill()
	_reveal_tweens.clear()
	_reveal_gen += 1
	var gen := _reveal_gen
	if instant:
		for item in _hidden_items():
			item.modulate.a = 1.0
		_store_bases()
		_start_logo_glow()
		return
	for b in _buttons:
		b.modulate.a = 0.0  # kaymadan önce görünmesin (ilk karede yanıp sönme olmasın)
	if not logo_ready:
		_reveal_tweens.append(UiKit.fade_in(_logo, 0.0, 0.3))
	for i in _extras.size():
		_reveal_tweens.append(UiKit.fade_in(_extras[i], 0.1 + i * 0.05, 0.3))
	await get_tree().process_frame  # kapsayıcı yerleşimi bitsin: taban konumlar doğru okunsun
	if gen != _reveal_gen or not is_inside_tree():
		return  # bu arada açılış atlandı ya da ekran kapandı
	_store_bases()
	var k := UiKit.anim_scale()
	for i in _buttons.size():
		var b := _buttons[i]
		var base: float = b.get_meta("base_x")
		b.position.x = base - 36.0
		b.modulate.a = 0.0
		var tw := b.create_tween().set_parallel()
		tw.tween_property(b, "position:x", base, 0.35 * k).set_delay((0.15 + i * 0.07) * k) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "modulate:a", 1.0, 0.25 * k).set_delay((0.15 + i * 0.07) * k)
		_reveal_tweens.append(tw)
	_start_logo_glow()


func _store_bases() -> void:
	for b in _buttons:
		b.set_meta("base_x", b.position.x)


func _start_logo_glow() -> void:
	if _logo.has_meta("glowing"):
		return
	_logo.set_meta("glowing", true)
	var glow := _logo.create_tween().set_loops()  # logo yavaşça parlar
	glow.tween_property(_logo, "self_modulate", Color(1.2, 1.15, 1.0), 1.6).set_trans(Tween.TRANS_SINE)
	glow.tween_property(_logo, "self_modulate", Color.WHITE, 1.6).set_trans(Tween.TRANS_SINE)
	_sparkles.active = true


func _input(event: InputEvent) -> void:
	if not intro_playing():
		return
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		skip_intro()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


# --- Düğmeler ---

func _on_continue() -> void:
	Screens.resume_saved_run()


func _on_new_game() -> void:
	if not Profile.has_saved_run():
		Screens.goto(Screens.KINGDOM_SELECT)
		return
	_confirm = Overlay.new(240.0, false, 10, true)
	var box := _confirm.content
	var title := UiKit.label(tr("Yeni oyun"), 16, UiKit.COLOR_INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UiKit.wrapped(tr("Yarım kalan koşun var. Yeni koşu başlatırsan o koşu silinir."), 10,
			UiKit.COLOR_INK))
	box.add_child(UiKit.button_primary(tr("Krallık seçimine geç"), func() -> void:
		_confirm.close()
		Screens.goto(Screens.KINGDOM_SELECT)))
	box.add_child(UiKit.button(tr("Vazgeç"), cancel_confirm))
	_confirm.closed.connect(func() -> void: _confirm = null)
	add_child(_confirm)


func cancel_confirm() -> void:
	if _confirm:
		_confirm.close()


## Logonun çevresinde yanıp sönen küçük ışıltılar (dört kollu yıldız). Logo etiketinin çocuğu, fareyi yok sayar.
class _LogoSparkles:
	extends Control

	const COUNT := 5
	const LIFE := 1.4
	var active := false
	var _time := 0.0
	var _rng := RandomNumberGenerator.new()
	var _sparks: Array[Vector3] = []  ## x, y, doğum zamanı

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		_rng.seed = 1071

	func _process(delta: float) -> void:
		if not active:
			return
		_time += delta
		for i in range(_sparks.size() - 1, -1, -1):
			if _time - _sparks[i].z > LIFE:
				_sparks.remove_at(i)
		while _sparks.size() < COUNT:
			_sparks.append(Vector3(_rng.randf_range(0.0, size.x), _rng.randf_range(size.y * 0.15, size.y * 0.8),
					_time + _rng.randf_range(0.0, LIFE)))
		queue_redraw()

	func _draw() -> void:
		for sp in _sparks:
			var age := _time - sp.z
			if age < 0.0:
				continue
			var k := sin(age / LIFE * PI)  # 0 -> 1 -> 0
			var r := 1.0 + 3.0 * k
			var c := Color(1.0, 0.97, 0.8, 0.9 * k)
			var p := Vector2(sp.x, sp.y)
			draw_line(p - Vector2(r, 0), p + Vector2(r, 0), c, 1.0)
			draw_line(p - Vector2(0, r), p + Vector2(0, r), c, 1.0)
			draw_circle(p, 0.8 + 0.6 * k, c)
