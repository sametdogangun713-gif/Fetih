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

## Savaş yürütme (simülasyon adımı, görüntüler, hit-stop, kamera) BattleRunner'da; burada HUD ve test modu.
var runner: BattleRunner
var _test_seed := 1
var _pause_menu: PauseMenu
## Sonuç paneli (başlık + "Devam"): ekran ortasında, birliklerin üstünde serbest durmaz.
var _result_panel: PanelContainer
## Alt bilgi yazılarının arkasındaki yarı saydam koyu şerit.
const INFO_STRIP_TOP := 338.0  ## 22 px'lik ince şerit: sadece süre / seed.
## Sol üstteki küçük "Savaş n / 20 · Rakip" kutusunun en geniş hali (sağdaki hız düğmelerine çarpmasın).
const MATCHUP_MAX_WIDTH := 470.0


## Runner _init'te eklenir: sahne ağaca girmeden serbest bırakılırsa (araçlar) çocuk olarak birlikte silinir.
func _init() -> void:
	runner = BattleRunner.new()
	add_child(runner)
	process_priority = 1  # yazı, runner'ın adımından sonra güncellensin (aynı karede doğru süre)


func _ready() -> void:
	# CanvasLayer bir Control değil: tema ebeveynden devralınmaz, HUD'daki her Control'e ayrı verilir.
	for child in $HUD.get_children():
		if child is Control:
			child.theme = UiKit.theme()
	_build_matchup_panel()
	for i in SPEEDS.size():
		var button: Button = speed_buttons.get_child(i)
		button.pressed.connect(_set_speed.bind(SPEEDS[i]))
		button.pressed.connect(UiKit.click_sound)
	_build_info_strip()
	_build_result_panel()
	continue_button.pressed.connect(UiKit.click_sound)
	continue_button.pressed.connect(_on_continue)
	battlefield.set_debug_tools(not RunState.active)
	runner.setup(battlefield)
	runner.finished.connect(_on_battle_finished)
	# Şerit ekran pikselidir: ilk kamera çerçevesi kutunun altına bu payı ekler.
	runner.frame_pad_bottom = 360.0 - INFO_STRIP_TOP
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


func _process(_delta: float) -> void:
	if runner.simulation == null:
		return
	if RunState.active:
		info_label.text = tr("Süre: %.1f sn") % runner.simulation.elapsed
	else:
		info_label.text = "Seed: %d   Süre: %.1f sn   (R: tekrar, N: yeni)" % [_test_seed, runner.simulation.elapsed]


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
	result_label.text = ""
	continue_button.visible = false
	var states: Array[SquadState]
	if RunState.active:
		states = _setup_run_battle()
	else:
		states = _setup_test_battle()
	var seed_value := RunState.battle_seed() if RunState.active else _test_seed
	runner.start(seed_value, states)
	if RunState.active:
		_apply_auras()


## Koşu savaşı: durumlar RunState'ten (seviyeler ve fermanlar SquadBuilder'da uygulanır).
## Biyom, kamplar ve eşleşme yazısı burada; ferman aurası start'tan sonra (_apply_auras).
func _setup_run_battle() -> Array[SquadState]:
	var states: Array[SquadState] = []
	states.append_array(RunState.build_player_squads())
	states.append_array(RunState.build_enemy_squads())
	var opponent := RunState.current_opponent()
	battlefield.set_biome(opponent.id)
	battlefield.set_camps(RunState.kingdom, opponent)
	matchup_label.text = tr("Savaş %d / %d  ·  Rakip: %s") % [RunState.battle_index + 1,
			Balance.RUN_LENGTH, tr(opponent.display_name)]
	if RunState.is_final_battle():
		matchup_label.text += tr("  ·  BÜYÜK FETİH")
	elif RunState.is_boss_battle():
		matchup_label.text += tr("  ·  BOSS: %s") % tr(opponent.boss.display_name)
	_fit_matchup_label()
	return states


## Ferman aurası (sadece görüntü): build_*_squads sırası ordu sırasıyla aynıdır, görüntüler ekleme sırasındadır.
func _apply_auras() -> void:
	var views := runner.views().values()
	var player_count := RunState.army.size()
	var enemy_army := RunState.current_enemy_army()
	var enemy_fermans := RunState.enemy_passives()
	for i in player_count:
		views[i].aura_color = SquadView.aura_color_for(RunState.army[i], RunState.passives)
	for i in enemy_army.size():
		views[player_count + i].aura_color = SquadView.aura_color_for(enemy_army[i], enemy_fermans)


func _setup_test_battle() -> Array[SquadState]:
	var matchup := _choose_test_matchup()
	battlefield.set_camps(KingdomCatalog.get_kingdom(&"humans"), KingdomCatalog.get_kingdom(&"orcs"))
	var states: Array[SquadState] = []
	for slot in TEST_PLAYER_SLOTS:
		states.append(SquadState.new(matchup[0], SquadState.Team.PLAYER,
				UnitCatalog.count_for_budget(matchup[0], TEST_SQUAD_BUDGET), slot))
	for slot in TEST_ENEMY_SLOTS:
		states.append(SquadState.new(matchup[1], SquadState.Team.ENEMY,
				UnitCatalog.count_for_budget(matchup[1], TEST_SQUAD_BUDGET), slot))
	matchup_label.text = "%s  vs  %s" % [_describe(matchup[0]), _describe(matchup[1])]
	_fit_matchup_label()
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


func _set_speed(value: int) -> void:
	runner.set_speed(value)
	for i in SPEEDS.size():
		var button: Button = speed_buttons.get_child(i)
		button.disabled = SPEEDS[i] == value


## Runner ses + yavaş çekimi yaptı; burada sonuç yazısı ve (koşuda) kayıt.
func _on_battle_finished(won: bool, survivors: int) -> void:
	if won:
		result_label.text = tr("ZAFER! (%d asker hayatta)") % survivors
		result_label.add_theme_color_override("font_color", UiKit.COLOR_GOOD)
	else:
		result_label.text = tr("YENİLGİ (rakipte %d asker kaldı)") % survivors
		result_label.add_theme_color_override("font_color", UiKit.COLOR_BAD)
	_pop_result()
	if RunState.active:
		RunState.finish_battle(won)
		# Sonuç hemen kaydedilir: kart ekranına geçmeden çıkılırsa da savaş sonucu kalıcıdır.
		var over := RunState.is_defeated() or RunState.is_last_battle()
		Profile.store_run(RunState.to_dict("end" if over else "cards"))
		continue_button.visible = true


## Sol üst köşede küçük etiket kutusu: "Savaş n / 20 · Rakip: X" (test modunda eşleşme metni).
## Godot: MatchupLabel sahnede HUD'un çocuğu; reparent ile ince panelin içine taşınır, başvuru geçerli kalır.
func _build_matchup_panel() -> void:
	var panel := UiKit.strip_panel(0.82)
	panel.theme = UiKit.theme()
	panel.position = Vector2(4, 4)
	$HUD.add_child(panel)
	matchup_label.reparent(panel, false)
	matchup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Etiket genişliği metne göre (en çok MATCHUP_MAX_WIDTH): kutu metin kadar olur, uzun test metni alt satıra geçer.
func _fit_matchup_label() -> void:
	var font := matchup_label.get_theme_font("font")
	var size := matchup_label.get_theme_font_size("font_size")
	matchup_label.custom_minimum_size.x = minf(
			font.get_string_size(matchup_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 2.0,
			MATCHUP_MAX_WIDTH)


## Alt bilgi şeridi (22 px): sadece süre / seed. Yarı saydam koyu zemin + üstte 1 px tema kenar çizgisi.
## Godot: CanvasLayer'a eklenen Control'ler sırayla çizilir; şerit en başa (move_child 0) konur, yazılar üstünde kalır.
func _build_info_strip() -> void:
	var hud: CanvasLayer = $HUD
	var strip := ColorRect.new()
	strip.color = Color(UiKit.COLOR_BG, 0.8)
	strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = INFO_STRIP_TOP - 360.0
	strip.offset_bottom = 0.0
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge := ColorRect.new()
	edge.color = UiKit.COLOR_EDGE
	edge.set_anchors_preset(Control.PRESET_TOP_WIDE)
	edge.offset_bottom = 1.0
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(edge)
	hud.add_child(strip)
	hud.move_child(strip, 0)


## Sonuç paneli: başlık ve "Devam" düğmesi tek çerçevede, ekranın ortasında (CenterContainer).
## Etiket ve düğme sahnedeki düğümlerdir; reparent ile panelin VBox'ına taşınır (başvurular geçerli kalır).
func _build_result_panel() -> void:
	var hud: CanvasLayer = $HUD
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE  # panelin dışı tıklamayı engellemesin
	center.theme = UiKit.theme()
	hud.add_child(center)
	_result_panel = UiKit.panel(Color(UiKit.COLOR_PANEL, 0.96))
	var style: StyleBoxFlat = _result_panel.get_theme_stylebox("panel")  # UiKit.panel_style: keskin köşe, gölge
	style.set_border_width_all(2)  # kartlarla aynı 2 px çerçeve, altın
	style.border_color = UiKit.COLOR_GOLD
	style.set_content_margin_all(14)
	_result_panel.visible = false
	center.add_child(_result_panel)
	var box := UiKit.vbox(10)
	_result_panel.add_child(box)
	result_label.reparent(box, false)
	continue_button.reparent(box, false)
	result_label.custom_minimum_size = Vector2(240, 0)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 16)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.custom_minimum_size = Vector2(100, 26)


## Sonuç yazısı büyükten yerine oturur (TRANS_BACK: hafif taşıp geri gelir), "Devam" sonra belirir.
## Panel görününce Container yerleşimi bir kare sonra biter; pivot doğru olsun diye o kare beklenir.
func _pop_result() -> void:
	_result_panel.visible = true
	result_label.modulate.a = 0.0
	continue_button.modulate.a = 0.0
	await get_tree().process_frame
	result_label.pivot_offset = result_label.size / 2.0
	result_label.scale = Vector2.ONE * 2.0
	var tween := create_tween().set_parallel()
	tween.tween_property(result_label, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(result_label, "modulate:a", 1.0, 0.15)
	tween.tween_property(continue_button, "modulate:a", 1.0, 0.25).set_delay(0.35)


func _on_continue() -> void:
	Screens.after_battle()
