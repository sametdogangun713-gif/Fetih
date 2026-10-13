extends Node
## Ses efektleri ve müzik (autoload: Audio). Örnek: Audio.play("hit"), Audio.play_music("battle").
## Dosyalar: assets/audio/sfx/<ad>.wav, assets/audio/music/<ad>.ogg ya da .wav.
## Geçici sesler tools/build_audio.gd ile koddan üretildi; gerçek sesler aynı adla konunca onlar çalar.
## Dosya yoksa ses sessizce atlanır (oyun çökmez).

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICES := 12  ## Aynı anda çalabilen en fazla efekt.
## Aynı efekt bu süreden sık çalmaz: x4 hızda yüzlerce vuruş sesi üst üste binmesin.
const MIN_INTERVAL := 0.06
const MUSIC_FADE := 1.0  ## Müzik geçişinde eski parçanın sönme / yenisinin yükselme süresi.
const SILENT_DB := -40.0
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
## Varsayılan ses düzeyleri (dB). Ayarlar menüsü (Aşama 10) bunları değiştirecek.
const DEFAULT_VOLUMES := {BUS_MUSIC: -9.0, BUS_SFX: -4.0}

var _streams := {}  ## yol -> AudioStream (dosya yoksa null)
var _last_played := {}  ## efekt adı -> son çalınma zamanı (ms)
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _music_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # oyun duraklasa da müzik sürsün
	_setup_buses()
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_voices.append(player)


## Efekt çalar. pitch_jitter: her çalışta perdeyi biraz değiştirir, tekrar eden ses yorucu olmasın.
func play(sound: String, volume_db := 0.0, pitch_jitter := 0.08, min_interval := MIN_INTERVAL) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_played.get(sound, -100000) < min_interval * 1000.0:
		return
	var stream := _load(SFX_DIR + sound + ".wav")
	if stream == null:
		return
	_last_played[sound] = now
	var player := _free_voice()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


## Müziği değiştirir (yumuşak geçiş). Aynı parça zaten çalıyorsa bir şey yapmaz. "" = sustur.
func play_music(track: String) -> void:
	if track == _music_name:
		return
	_music_name = track
	if _music:
		var old := _music
		var fade := create_tween()
		fade.tween_property(old, "volume_db", SILENT_DB, MUSIC_FADE)
		fade.tween_callback(old.queue_free)
		_music = null
	if track == "":
		return
	var stream := _load(MUSIC_DIR + track + ".ogg")
	if stream == null:
		stream = _load(MUSIC_DIR + track + ".wav")
	if stream == null:
		return
	_make_loop(stream)
	_music = AudioStreamPlayer.new()
	_music.bus = BUS_MUSIC
	_music.stream = stream
	_music.volume_db = SILENT_DB
	add_child(_music)
	_music.play()
	create_tween().tween_property(_music, "volume_db", 0.0, MUSIC_FADE)


## Boştaki ses kanalı; hepsi doluysa sıradakini keser (en eski başlayan).
func _free_voice() -> AudioStreamPlayer:
	for i in VOICES:
		var player := _voices[(_next_voice + i) % VOICES]
		if not player.playing:
			_next_voice = (_next_voice + i + 1) % VOICES
			return player
	var oldest := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	return oldest


func _load(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]


## Müzik dosyası döngü ayarsız içe aktarılmış olabilir; çalarken döngüye alınır.
func _make_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	elif stream is AudioStreamOggVorbis:
		stream.loop = true


## Müzik ve efekt için ayrı ses kanalları (bus): ayarlardan ayrı ayrı kısılabilsin.
func _setup_buses() -> void:
	for bus_name: StringName in DEFAULT_VOLUMES:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")
		AudioServer.set_bus_volume_db(index, DEFAULT_VOLUMES[bus_name])
