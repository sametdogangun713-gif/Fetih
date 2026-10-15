class_name BattleHud
extends CanvasLayer
## Savaş arayüzü: sol üstte eşleşme kutusu, sağ üstte hız + duraklat düğmeleri, altta süre şeridi,
## ortada sonuç paneli ("ZAFER!" + "Devam"). Meydan (koşu) ve battle.tscn (test modu) aynı HUD'u kullanır.
## Godot: CanvasLayer ekrana sabit çizilir; Control'ler kodla kurulur. CanvasLayer bir Control olmadığı için
## tema ebeveynden gelmez: kök Control'e verilir, çocuklar devralır.

## "Devam" basıldı (test modunda düğme hiç görünmez).
signal continue_pressed

const SPEEDS: Array[int] = [1, 2, 4]
## Alt bilgi şeridi: 22 px'lik ince şerit (süre / seed).
const STRIP_HEIGHT := 22.0
## Sol üstteki küçük "Savaş n / 20 · Rakip" kutusunun en geniş hali (sağdaki hız düğmelerine çarpmasın).
const MATCHUP_MAX_WIDTH := 470.0

## Alt şeritteki yazı: Callable(elapsed: float) -> String. Boşsa "Süre: %.1f sn". Test modu seed yazısı verir.
var info_text := Callable()

var _runner: BattleRunner
var _root: Control
var _matchup_label: Label
var _info_label: Label
var _speed_buttons: Array[Button] = []
var _result_panel: PanelContainer
var _result_label: Label
var _continue_button: Button


func _init() -> void:
	process_priority = 1  # yazı, runner'ın adımından sonra güncellensin (aynı karede doğru süre)


## Düğmeleri ve panelleri kurar. runner: hız ayarı ve süre buradan; pause_menu: "II" düğmesi açar (boş olabilir).
func setup(runner: BattleRunner, pause_menu: PauseMenu) -> void:
	_runner = runner
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiKit.theme()
	add_child(_root)
	_build_info_strip()
	_build_matchup_panel()
	_build_speed_buttons(pause_menu)
	_build_result_panel()
	# Şerit ekran pikselidir: ilk kamera çerçevesi kutunun altına bu payı ekler.
	runner.frame_pad_bottom = STRIP_HEIGHT
	set_speed(Settings.battle_speed)


## Yeni savaş: sonuç paneli kapanır, hız ayardaki değere döner.
func reset() -> void:
	_result_label.text = ""
	_result_panel.visible = false
	_continue_button.visible = false
	set_speed(Settings.battle_speed)


func show_matchup(text: String) -> void:
	_matchup_label.text = text
	# Etiket genişliği metne göre (en çok MATCHUP_MAX_WIDTH): kutu metin kadar olur, uzun metin alt satıra geçer.
	var font := _matchup_label.get_theme_font("font")
	var size := _matchup_label.get_theme_font_size("font_size")
	_matchup_label.custom_minimum_size.x = minf(
			font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 2.0, MATCHUP_MAX_WIDTH)


## Sonuç yazısı + renk + açılış animasyonu; can_continue ise "Devam" düğmesi de çıkar.
func show_result(won: bool, survivors: int, can_continue: bool) -> void:
	if won:
		_result_label.text = tr("ZAFER! (%d asker hayatta)") % survivors
		_result_label.add_theme_color_override("font_color", UiKit.COLOR_GOOD)
	else:
		_result_label.text = tr("YENİLGİ (rakipte %d asker kaldı)") % survivors
		_result_label.add_theme_color_override("font_color", UiKit.COLOR_BAD)
	_continue_button.visible = can_continue
	_pop_result()


func set_speed(value: int) -> void:
	_runner.set_speed(value)
	for i in SPEEDS.size():
		_speed_buttons[i].disabled = SPEEDS[i] == value


func _process(_delta: float) -> void:
	if not visible or _runner == null or _runner.simulation == null:
		return
	var elapsed := _runner.simulation.elapsed
	if info_text.is_valid():
		_info_label.text = info_text.call(elapsed)
	else:
		_info_label.text = tr("Süre: %.1f sn") % elapsed


## Sol üst köşede küçük etiket kutusu: "Savaş n / 20 · Rakip: X" (test modunda eşleşme metni).
func _build_matchup_panel() -> void:
	var panel := UiKit.strip_panel(0.82)
	panel.position = Vector2(4, 4)
	_root.add_child(panel)
	_matchup_label = UiKit.label("", 10)
	_matchup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_matchup_label)


## Sağ üst: x1 / x2 / x4 (seçili olan devre dışı) ve en sağda duraklatma.
func _build_speed_buttons(pause_menu: PauseMenu) -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.offset_left = -138.0
	row.offset_top = 4.0
	row.offset_right = -4.0
	row.offset_bottom = 24.0
	_root.add_child(row)
	for speed in SPEEDS:
		var button := Button.new()
		button.text = "x%d" % speed
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(UiKit.click_sound)
		button.pressed.connect(set_speed.bind(speed))
		row.add_child(button)
		_speed_buttons.append(button)
	if pause_menu != null:
		var pause_button := Button.new()
		pause_button.text = "II"
		pause_button.focus_mode = Control.FOCUS_NONE
		pause_button.tooltip_text = tr("Duraklat (Esc)")
		pause_button.pressed.connect(UiKit.click_sound)
		pause_button.pressed.connect(pause_menu.open)
		row.add_child(pause_button)


## Alt bilgi şeridi: yarı saydam koyu zemin + üstte 1 px tema kenar çizgisi; yazı üstünde.
## Godot: aynı Control'e eklenen çocuklar sırayla çizilir; şerit önce eklenir, yazı üstte kalır.
func _build_info_strip() -> void:
	var strip := ColorRect.new()
	strip.color = Color(UiKit.COLOR_BG, 0.8)
	strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -STRIP_HEIGHT
	strip.offset_bottom = 0.0
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge := ColorRect.new()
	edge.color = UiKit.COLOR_EDGE
	edge.set_anchors_preset(Control.PRESET_TOP_WIDE)
	edge.offset_bottom = 1.0
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(edge)
	_root.add_child(strip)
	_info_label = UiKit.label("", 10)
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_info_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info_label.offset_left = 8.0
	_info_label.offset_top = -STRIP_HEIGHT
	_info_label.offset_right = 400.0
	_info_label.offset_bottom = 0.0
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_info_label)


## Sonuç paneli: başlık ve "Devam" düğmesi tek çerçevede, ekranın ortasında (CenterContainer).
func _build_result_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE  # panelin dışı tıklamayı engellemesin
	_root.add_child(center)
	_result_panel = UiKit.panel(Color(UiKit.COLOR_PANEL, 0.96))
	var style: StyleBoxFlat = _result_panel.get_theme_stylebox("panel")  # UiKit.panel_style: keskin köşe, gölge
	style.set_border_width_all(2)  # kartlarla aynı 2 px çerçeve, altın
	style.border_color = UiKit.COLOR_GOLD
	style.set_content_margin_all(14)
	_result_panel.visible = false
	center.add_child(_result_panel)
	var box := UiKit.vbox(10)
	_result_panel.add_child(box)
	_result_label = Label.new()
	_result_label.custom_minimum_size = Vector2(240, 0)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.set_font_size(_result_label, 16)
	box.add_child(_result_label)
	_continue_button = Button.new()
	_continue_button.text = tr("Devam")
	_continue_button.focus_mode = Control.FOCUS_NONE
	_continue_button.visible = false
	_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue_button.custom_minimum_size = Vector2(100, 26)
	_continue_button.pressed.connect(UiKit.click_sound)
	_continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	box.add_child(_continue_button)


## Sonuç yazısı büyükten yerine oturur (TRANS_BACK: hafif taşıp geri gelir), "Devam" sonra belirir.
## Panel görününce Container yerleşimi bir kare sonra biter; pivot doğru olsun diye o kare beklenir.
func _pop_result() -> void:
	_result_panel.visible = true
	_result_label.modulate.a = 0.0
	_continue_button.modulate.a = 0.0
	await get_tree().process_frame
	_result_label.pivot_offset = _result_label.size / 2.0
	_result_label.scale = Vector2.ONE * 2.0
	var tween := create_tween().set_parallel()
	tween.tween_property(_result_label, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_result_label, "modulate:a", 1.0, 0.15)
	tween.tween_property(_continue_button, "modulate:a", 1.0, 0.25).set_delay(0.35)
