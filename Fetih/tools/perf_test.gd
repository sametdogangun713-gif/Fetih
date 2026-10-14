extends SceneTree
## Kare hızı (FPS) ölçümü. EKRANLI çalışır (render da ölçülsün diye headless değil):
##   godot --path Fetih -s res://tools/perf_test.gd -- [secs=8] [only=menu,prep,cards,battle5,boss]
##         [vsync] [cap=60] [speed=1]
## Senaryolar: ana menü, hazırlık (koşu haritası), kart seçimi, 5 bölük vs 5 bölük savaş, boss savaşı.
## Varsayılan: VSync kapalı ve Engine.max_fps = 0 (sınırsız), böylece gerçek tavan görülür.
## "vsync" ve "cap=N" oyuncunun ayarlarını taklit eder; "speed=N" savaş hızı.
## Her senaryo önce ısınır (yükleme sıçraması sayılmasın), sonra her kare kaydedilir:
## - kare süresi (iki process_frame arası) -> min / ortalama / %1 düşük FPS
## - betik süresi: process_frame -> RenderingServer.frame_pre_draw (bütün _process'ler + _draw'lar)
## - savaş _process: BattleController._process süresi (simülasyon + görüntü güncelleme + efektler)
## - render: frame_pre_draw -> frame_post_draw (CPU'nun çizim komutlarını hazırlaması)
## - Performance monitörleri: TIME_PROCESS / TIME_PHYSICS_PROCESS (Godot bunları saniyede bir,
##   o saniyenin EN UZUN karesi olarak günceller), draw call, nesne, düğüm, Object, bellek.
## Oyuncunun kaydına ve ayarlarına dokunmaz: ayrı save_path / settings_path kullanır.

const PERF_SAVE := "user://perf_save.json"
const PERF_SETTINGS := "user://perf_settings.cfg"
const WARMUP := 1.5  ## sn: sahne yüklendikten sonra ölçülmeyen süre
const SCENARIOS := ["menu", "prep", "cards", "battle5", "boss"]
const TIPS := ["menu", "prep", "battle", "cards", "treasury"]
const SPIKE_MS := 12.0  ## Bu süreden uzun kare takılma sayılır ve listelenir.

var _sampling := false
var _last_usec := 0
var _frame_begin_usec := 0
var _pre_draw_usec := 0
var _start_usec := 0
var _speed := 1
var _battle: Node  ## Ölçülen savaş sahnesi (yoksa null). _process'ini bu araç çağırır, süresini ölçer.
var _samples := {}  ## ad -> PackedFloat32Array
var _max_nodes := 0.0
var _max_object_count := 0.0
var _max_memory := 0.0
var _results: Array[String] = []
var _spikes: Array[String] = []


func _initialize() -> void:
	await process_frame  # autoload'lar hazır olsun
	var args := Array(OS.get_cmdline_user_args())
	var secs := 8.0
	var only: Array = SCENARIOS.duplicate()
	var vsync := false
	var cap := 0
	for arg: String in args:
		if arg.begins_with("secs="):
			secs = float(arg.substr(5))
		elif arg.begins_with("only="):
			only = Array(arg.substr(5).split(","))
		elif arg == "vsync":
			vsync = true
		elif arg.begins_with("cap="):
			cap = int(arg.substr(4))
		elif arg.begins_with("speed="):
			_speed = int(arg.substr(6))

	# Oyuncunun kayıt ve ayar dosyaları yerine ayrı dosyalar; varsayılan profil ve ayarlarla başla.
	var profile := root.get_node("Profile")
	profile.save_path = PERF_SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PERF_SAVE))
	profile.load_profile()
	for id: String in TIPS:  # ipucu pencereleri oyunu durdurur: görülmüş say (sadece bellekte)
		profile.tips_seen.append(id)
	var settings := root.get_node("Settings")
	settings.settings_path = PERF_SETTINGS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PERF_SETTINGS))
	settings.load_settings()
	settings.apply_all()
	# apply_all oyuncunun FPS ayarlarını da uygular; ölçüm için üstüne yazılır.
	settings.set("show_fps", false)
	Engine.max_fps = cap
	DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	await process_frame
	await process_frame

	print("Ekran kartı: %s" % RenderingServer.get_video_adapter_name())
	print("Pencere: %s  VSync: %s  max_fps: %d  savaş hızı: x%d  süre: %.0f sn/senaryo" % [root.size,
			"açık" if vsync else "kapalı", Engine.max_fps, _speed, secs])
	process_frame.connect(_on_frame)
	RenderingServer.frame_pre_draw.connect(func() -> void: _pre_draw_usec = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	for scenario: String in only:
		await _measure(scenario, secs)
	print("")
	print("| ekran | min FPS | ort FPS | %1 düşük FPS | betik ms | savaş _process ms | render ms | GPU ms | TIME_PROCESS max ms | draw call ort/max | nesne/kare | düğüm | Object | bellek MB |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for line in _results:
		print(line)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PERF_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PERF_SETTINGS))
	quit()


func _measure(scenario: String, secs: float) -> void:
	var scene := _open(scenario)
	if scene == null:
		push_error("Bilinmeyen senaryo: " + scenario)
		return
	root.add_child(scene)
	if scenario in ["battle5", "boss"]:
		_battle = scene
		scene._set_speed(_speed)
		scene.set_process(false)  # _process'i _on_frame çağırır (süresi ölçülsün)
	await create_timer(WARMUP).timeout
	_reset_samples()
	_sampling = true
	await create_timer(secs).timeout
	_sampling = false
	_results.append(_summary(scenario))
	print(_results.back())
	if not _spikes.is_empty():
		print("  takılmalar (>%.0f ms, zaman ölçüm başından): %s" % [SPIKE_MS, " ".join(_spikes)])
	_battle = null
	scene.queue_free()
	await process_frame
	await process_frame


## Senaryonun sahnesini kurar. Sınıflar load() ile alınır (araç autoload'lardan önce derlenir).
func _open(scenario: String) -> Node:
	var run := root.get_node("RunState")
	match scenario:
		"menu":
			return load("res://scenes/ui/kingdom_select.tscn").instantiate()
		"prep":
			run.start_run(KingdomCatalog.all()[0], 4242)
			run.battle_index = 6
			return load("res://scenes/run/prep.tscn").instantiate()
		"cards":
			run.start_run(KingdomCatalog.all()[0], 4242)
			run.finish_battle(true)
			return load("res://scenes/ui/card_select.tscn").instantiate()
		"battle5", "boss":
			run.start_run(KingdomCatalog.all()[0], 4242)
			_crowded_army(run)
			# 14. savaş: rakip 5 bölük; 15. savaş: boss + ordusu.
			run.battle_index = 13 if scenario == "battle5" else 14
			return load("res://scenes/battle/battle.tscn").instantiate()
	return null


## En kalabalık oyuncu ordusu: asker sayısı en yüksek 5 birlik, hepsi Sv 5 (takviye).
func _crowded_army(run: Node) -> void:
	var units := UnitCatalog.all()
	units.sort_custom(func(a: UnitData, b: UnitData) -> bool:
		return UnitCatalog.count_for_budget(a, Balance.SQUAD_BUDGET) > UnitCatalog.count_for_budget(b, Balance.SQUAD_BUDGET))
	run.army.clear()
	for i in Balance.MAX_SQUADS:
		var squad := ArmySquad.new(units[i], Balance.SQUAD_BUDGET)
		for k in Balance.MAX_LEVEL - 1:
			squad.upgrade(ArmySquad.Upgrade.REINFORCE)
		run.army.append(squad)
	ArmyGenerator.auto_arrange(run.army, Balance.GRID_SIZE)


func _reset_samples() -> void:
	_samples.clear()
	for key in ["frame", "script", "battle", "render", "gpu", "time_process", "draw_calls", "objects"]:
		_samples[key] = PackedFloat32Array()
	_max_nodes = 0.0
	_max_object_count = 0.0
	_max_memory = 0.0
	_spikes.clear()
	_last_usec = Time.get_ticks_usec()
	_start_usec = _last_usec


func _add(key: String, value: float) -> void:
	var arr: PackedFloat32Array = _samples[key]
	arr.append(value)
	_samples[key] = arr


## process_frame: karenin başı (düğümlerin _process'inden önce).
func _on_frame() -> void:
	var now := Time.get_ticks_usec()
	var delta := (now - _last_usec) / 1000000.0
	_frame_begin_usec = now
	if _sampling:
		var ms := delta * 1000.0
		_add("frame", ms)
		if ms > SPIKE_MS and _spikes.size() < 40:
			_spikes.append("%.0fms@%.2fs" % [ms, (now - _start_usec) / 1000000.0])
		var vp := root.get_viewport_rid()
		_add("gpu", RenderingServer.viewport_get_measured_render_time_gpu(vp))
		_add("time_process", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_add("draw_calls", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_add("objects", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		_max_nodes = maxf(_max_nodes, Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		_max_object_count = maxf(_max_object_count, Performance.get_monitor(Performance.OBJECT_COUNT))
		_max_memory = maxf(_max_memory, Performance.get_monitor(Performance.MEMORY_STATIC))
	_last_usec = now
	if is_instance_valid(_battle) and _battle.is_inside_tree():
		var t := Time.get_ticks_usec()
		_battle._process(delta)
		if _sampling:
			_add("battle", (Time.get_ticks_usec() - t) / 1000.0)


func _on_post_draw() -> void:
	if not _sampling:
		return
	var now := Time.get_ticks_usec()
	if _pre_draw_usec >= _frame_begin_usec:
		_add("script", (_pre_draw_usec - _frame_begin_usec) / 1000.0)
		_add("render", (now - _pre_draw_usec) / 1000.0)


func _summary(scenario: String) -> String:
	var frames: PackedFloat32Array = _samples["frame"]
	if frames.is_empty():
		return "| %s | (kare yok) |" % scenario
	var sorted := frames.duplicate()
	sorted.sort()
	var worst := sorted[sorted.size() - 1]
	var p99 := sorted[clampi(int(sorted.size() * 0.99), 0, sorted.size() - 1)]
	var battle := "-" if _samples["battle"].is_empty() else "%.2f" % _avg(_samples["battle"])
	return "| %s | %.0f | %.0f | %.0f | %.2f | %s | %.2f | %.2f | %.1f | %.0f/%.0f | %.0f | %.0f | %.0f | %.1f |" % [
			scenario, 1000.0 / worst, 1000.0 / _avg(frames), 1000.0 / p99,
			_avg(_samples["script"]), battle, _avg(_samples["render"]), _avg(_samples["gpu"]),
			_avg(_samples["time_process"]), _avg(_samples["draw_calls"]), _max(_samples["draw_calls"]),
			_avg(_samples["objects"]), _max_nodes, _max_object_count, _max_memory / 1048576.0]


func _avg(values: PackedFloat32Array) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / maxf(values.size(), 1.0)


func _max(values: PackedFloat32Array) -> float:
	var m := 0.0
	for v in values:
		m = maxf(m, v)
	return m
