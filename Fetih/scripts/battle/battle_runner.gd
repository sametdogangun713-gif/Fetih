class_name BattleRunner
extends Node
## Savaş yürütücü: simülasyonu sabit adımlarla ilerletir, bölük görüntülerini ve efektleri günceller.
## Arayüzsüzdür: savaş sahnesi (BattleController) ve Meydan aynı yürütücüyü kullanır.
## show_static: simülasyonsuz görüntü (hazırlık ve kart aşamaları).

## Savaş bitti. won: oyuncu kazandı mı; survivors: kazanan tarafın hayatta kalan askeri.
signal finished(won: bool, survivors: int)

## x1 hızında simülasyonun gerçek zamana oranı. Savaş gözle takip edilebilsin diye 1'in altında
## (ortanca savaş ~12 sn simülasyon zamanı, x1'de ~17 sn sürer).
const PLAYBACK := 0.7
## Kamera kutusunda bir bölüğün kapladığı alan: yarı genişlik ve ayaktan yukarı yükseklik (piksel).
## Formasyon ~1 karo yayılır; sancak ve sayı askerlerin üstünde.
const SQUAD_FRAME_PAD := Vector2(24, 24)
## Vuruş duraksaması (hit-stop) ve yavaş çekim: sadece gösterim saati durur / yavaşlar;
## simülasyon adımları ve sonuç aynı kalır (biriken süre bu sırada artmaz ya da yavaş artar).
## Değerler gorsel_yon_dokumani.md 5.2. Ayarlardan "Vuruş duraklaması" kapatılabilir.
const HITSTOP_GAP := 0.4  ## İki duraksama arası en az bu kadar (kitle savaşında sürekli donmasın).

var battlefield: Battlefield
var simulation: BattleSimulation
var running := false
## İlk kamera çerçevesinde kutunun altına eklenen ekran pikseli (alt şeridin kampı örtmemesi için).
var frame_pad_bottom := 0.0
## Aynısı kutunun üstü için (üst şerit / paneller sahneyi örtmesin).
var frame_pad_top := 0.0
## Aynısı kutunun solu için (sol bilgi paneli).
var frame_pad_left := 0.0
var _views := {}  ## SquadState -> SquadView (ekleme sırası = verilen sıra)
var _accumulator := 0.0
var _speed := 1
var _hitstop := 0.0
var _hitstop_gap := 0.0
var _slowmo := 0.0  ## Kalan yavaş çekim süresi (gerçek sn).
var _slowmo_scale := 1.0


func setup(field: Battlefield) -> void:
	battlefield = field
	battlefield.fx.camera = battlefield.camera
	battlefield.fx.hitstop_requested.connect(_request_hitstop)


func set_speed(value: int) -> void:
	_speed = value


func views() -> Dictionary:
	return _views


## Savaşı başlatır: durumları simülasyona ve görüntü olarak sahneye ekler.
func start(seed_value: int, states: Array[SquadState]) -> void:
	clear()
	simulation = BattleSimulation.new(seed_value, battlefield.field_rect())
	simulation.squad_attacked.connect(_on_squad_attacked)
	simulation.battle_finished.connect(_on_battle_finished)
	simulation.squad_spawned.connect(_on_squad_spawned)  # bölünen slime'ların yeni bölükleri
	simulation.squad_destroyed.connect(_on_squad_destroyed)
	simulation.squad_revived.connect(func(squad: SquadState) -> void: battlefield.fx.revive(_views[squad]))
	for state in states:
		simulation.add_squad(state)
		_add_view(state)
	frame_all()
	_start_music()
	running = true


## Simülasyonsuz görüntü (hazırlık, kart seçimi). SquadState -> SquadView döndürür.
func show_static(states: Array[SquadState]) -> Dictionary:
	clear()
	for state in states:
		_add_view(state)
	return _views


## Görüntüleri, efektleri ve simülasyonu temizler; yürütmeyi durdurur.
func clear() -> void:
	running = false
	for view: SquadView in _views.values():
		view.queue_free()
	_views.clear()
	battlefield.fx.clear()
	_accumulator = 0.0
	_hitstop = 0.0
	_slowmo = 0.0
	if simulation:
		simulation.dispose()
		simulation = null


## İlk çerçeve: iki ordu ve iki sancak; alt şerit oyuncu sancağını örtmesin diye kutunun
## altına (ve üstüne) frame_pad_* ekran pikseli kadar pay. Savaş içi takip (_process) sadece bölükleri izler.
func frame_all() -> void:
	var first_frame := squads_rect()
	var banners := battlefield.banners_rect()
	if banners.has_area():
		first_frame = first_frame.merge(banners)
	# Pay ekran pikselidir; en uzak yakınlıkta (kutu en küçük görünür) dünya birimine çevrilir.
	var far := BattleCamera.ZOOM_LEVELS[0]
	first_frame.position.y -= frame_pad_top / far
	first_frame.size.y += (frame_pad_bottom + frame_pad_top) / far
	first_frame.position.x -= frame_pad_left / far
	first_frame.size.x += frame_pad_left / far
	battlefield.camera.follow(first_frame, 0.0, true)


func _process(delta: float) -> void:
	if not running:
		return
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
	battlefield.camera.follow(squads_rect(), delta)  # gerçek süre: x4'te kamera telaşlanmasın


func _exit_tree() -> void:
	if simulation:
		simulation.dispose()


## Yaşayan bütün bölükleri (askerler, sancak, sayı dahil) kapsayan kutu: kamera bunu takip eder.
func squads_rect() -> Rect2:
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


## Ses + son yavaş çekim burada; yazı ve paneller dinleyenin işi. `running` açık kalır
## (son ölüm animasyonları oynasın); clear() durdurur.
func _on_battle_finished(winner: SquadState.Team) -> void:
	var won := winner == SquadState.Team.PLAYER
	var survivors := 0
	for squad: SquadState in _views:
		if squad.team == winner:
			survivors += squad.alive_count()
	Audio.play("victory" if won else "defeat", 0.0, 0.0, 0.0)
	_slow_motion(0.6, 0.5)  # son bölük düşerken kısa yavaş çekim
	finished.emit(won, survivors)
