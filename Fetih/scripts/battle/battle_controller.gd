extends Node2D
## Savaşı yürütür: simülasyonu sabit adımlarla ilerletir, bölük görüntülerini günceller.
##
## İki modda çalışır:
## - Koşu modu (RunState.active): ordular RunState'ten gelir; savaş bitince "Devam" düğmesi çıkar.
## - Test modu (sahne tek başına, F6): seed'e göre rastgele iki birlik, taraf başına 2 bölük.
##   R: aynı savaşı tekrar. N: yeni seed ve yeni eşleşme.

const SPEEDS: Array[int] = [1, 2, 4]
## x1 hızında simülasyonun gerçek zamana oranı. Savaş gözle takip edilebilsin diye 1'in altında
## (ortanca savaş ~12 sn simülasyon zamanı, x1'de ~17 sn sürer).
const PLAYBACK := 0.7
## Kamera kutusunda bir bölüğün kapladığı alan: yarı genişlik ve ayaktan yukarı yükseklik (piksel).
## Formasyon ~1 karo yayılır; sancak ve sayı askerlerin üstünde.
const SQUAD_FRAME_PAD := Vector2(40, 48)
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
## Vuruş duraksaması (hit-stop) ve yavaş çekim: sadece gösterim saati durur / yavaşlar;
## simülasyon adımları ve sonuç aynı kalır (biriken süre bu sırada artmaz ya da yavaş artar).
## Değerler gorsel_yon_dokumani.md 5.2. Ayarlardan "Vuruş duraklaması" kapatılabilir.
const HITSTOP_GAP := 0.4  ## İki duraksama arası en az bu kadar (kitle savaşında sürekli donmasın).
var _hitstop := 0.0
var _hitstop_gap := 0.0
var _slowmo := 0.0  ## Kalan yavaş çekim süresi (gerçek sn).
var _slowmo_scale := 1.0
## Sonuç paneli (başlık + "Devam"): ekran ortasında, birliklerin üstünde serbest durmaz.
var _result_panel: PanelContainer
## Alt bilgi yazılarının arkasındaki yarı saydam koyu şerit.
const INFO_STRIP_TOP := 314.0


func _ready() -> void:
	for i in SPEEDS.size():
		var button: Button = speed_buttons.get_child(i)
		button.pressed.connect(_set_speed.bind(SPEEDS[i]))
		button.pressed.connect(UiKit.click_sound)
	_build_info_strip()
	_build_result_panel()
	continue_button.pressed.connect(UiKit.click_sound)
	continue_button.pressed.connect(_on_continue)
	battlefield.set_debug_tools(not RunState.active)
	battlefield.fx.camera = battlefield.camera
	battlefield.fx.hitstop_requested.connect(_request_hitstop)
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
	# PLAYBACK sadece gösterimi yavaşlatır: adımlar ve sonuç aynı kalır (deterministik).
	var sim_delta := delta * _speed * PLAYBACK
	_hitstop_gap = maxf(_hitstop_gap - delta, 0.0)
	if _hitstop > 0.0:
		_hitstop -= delta
		sim_delta = 0.0
	elif _slowmo > 0.0:
		_slowmo -= delta
		sim_delta *= _slowmo_scale
	_accumulator += sim_delta
	while _accumulator >= BattleSimulation.TICK:
		simulation.step()
		_accumulator -= BattleSimulation.TICK
	var alpha := _accumulator / BattleSimulation.TICK
	for view: SquadView in _views.values():
		view.update_visual(alpha, sim_delta)
	battlefield.fx.advance(sim_delta)
	battlefield.camera.follow(_squads_rect(), delta)  # gerçek süre: x4'te kamera telaşlanmasın
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
	_hitstop = 0.0
	_slowmo = 0.0
	result_label.text = ""
	continue_button.visible = false
	if simulation:
		simulation.dispose()

	var seed_value := RunState.battle_seed() if RunState.active else _test_seed
	simulation = BattleSimulation.new(seed_value, battlefield.field_rect())
	simulation.squad_attacked.connect(_on_squad_attacked)
	simulation.battle_finished.connect(_on_battle_finished)
	simulation.squad_spawned.connect(_on_squad_spawned)  # bölünen slime'ların yeni bölükleri
	simulation.squad_destroyed.connect(_on_squad_destroyed)
	simulation.squad_revived.connect(func(squad: SquadState) -> void: battlefield.fx.revive(_views[squad]))

	if RunState.active:
		_setup_run_battle()
	else:
		_setup_test_battle()
	battlefield.camera.follow(_squads_rect(), 0.0, true)
	_start_music()


func _setup_run_battle() -> void:
	# Seviyeler ve fermanlar SquadBuilder'da uygulanır.
	for squad in RunState.build_player_squads():
		_add_state(squad)
	for squad in RunState.build_enemy_squads():
		_add_state(squad)
	var opponent := RunState.current_opponent()
	battlefield.set_biome(opponent.id)
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


## Yaşayan bütün bölükleri (askerler, sancak, sayı dahil) kapsayan kutu: kamera bunu takip eder.
func _squads_rect() -> Rect2:
	var rect := Rect2()
	var first := true
	for squad: SquadState in _views:
		if not squad.is_alive():
			continue
		var view: SquadView = _views[squad]
		var half := maxf(SQUAD_FRAME_PAD.x, view.sheet.frame_size.x)
		var top := maxf(SQUAD_FRAME_PAD.y, view.sheet.frame_size.y + 16.0)
		var box := Rect2(view.position + Vector2(-half, -top), Vector2(half * 2.0, top + 16.0))
		rect = box if first else rect.merge(box)
		first = false
	return rect


func _add_view(squad: SquadState) -> void:
	var view := SquadView.new()
	view.setup(squad)
	view.soldier_died.connect(battlefield.fx.soldier_died)
	battlefield.units.add_child(view)
	battlefield.fx.track(view)
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
	var gap := attacker.position.distance_to(target.position) - 2.0 * BattleSimulation.SQUAD_RADIUS
	if attacker.unit.is_ranged() and gap > BattleSimulation.MELEE_GAP:
		attacker_view.play_attack(false)
		battlefield.fx.launch(attacker_view, _views[target])
	else:
		attacker_view.play_attack(true)
		battlefield.fx.melee_hit(attacker_view, _views[target])


func _on_squad_destroyed(squad: SquadState) -> void:
	battlefield.fx.squad_down(_views[squad])
	if squad.unit.is_boss:
		_request_hitstop(0.15, true)
		_slow_motion(0.5, 0.4)


## force: bekleme süresini (HITSTOP_GAP) yok say (boss ölümü kaçmasın).
func _request_hitstop(duration: float, force := false) -> void:
	if not Settings.hit_stop or (_hitstop_gap > 0.0 and not force):
		return
	_hitstop = maxf(_hitstop, duration)
	_hitstop_gap = HITSTOP_GAP


func _slow_motion(duration: float, scale: float) -> void:
	if not Settings.hit_stop:
		return
	_slowmo = duration
	_slowmo_scale = scale


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
	_slow_motion(0.6, 0.5)  # son bölük düşerken kısa yavaş çekim
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


## Alt bilgi şeridi: MatchupLabel ve InfoLabel'ın arkasında yarı saydam koyu zemin + üstte 1 px altın çizgi.
## Godot: CanvasLayer'a eklenen Control'ler sırayla çizilir; şerit en başa (move_child 0) konur, yazılar üstünde kalır.
func _build_info_strip() -> void:
	var hud: CanvasLayer = $HUD
	var strip := ColorRect.new()
	strip.color = Color(UiKit.COLOR_BG, 0.72)
	strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = INFO_STRIP_TOP - 360.0
	strip.offset_bottom = 0.0
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge := ColorRect.new()
	edge.color = Color(UiKit.COLOR_GOLD, 0.35)
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
	_result_panel = UiKit.panel(Color(UiKit.COLOR_PANEL, 0.94))
	var style: StyleBoxFlat = _result_panel.get_theme_stylebox("panel")
	style.set_border_width_all(1)
	style.border_color = UiKit.COLOR_GOLD.darkened(0.4)
	style.set_content_margin_all(12)
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
