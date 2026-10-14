extends Node
## Oyuncu ayarları (autoload: Settings): ses düzeyleri, tam ekran, pencere boyutu,
## varsayılan savaş hızı, ekran sarsıntısı, dil.
## İlerlemeden (Profile, save.json) ayrı tutulur: ayarlar cihaza ait, ilerleme oyuncuya.
## Godot'nun ConfigFile biçimi (INI benzeri, bölüm + anahtar) kullanılır: user://settings.cfg.

## Audio'nun sabitlerine (kanal taban düzeyleri) script üzerinden erişilir; "Audio" autoload adı
## araç scriptlerinde (-s) derleme anında tanınmaz.
const AudioScript = preload("res://scripts/audio/audio.gd")
const SETTINGS_PATH := "user://settings.cfg"
const LANGUAGES := ["tr", "en"]
const SPEEDS: Array[int] = [1, 2, 4]
const BASE_SIZE := Vector2i(640, 360)  ## Arayüz düzeninin boyutu (project.godot viewport). canvas_items
## modunda her şey pencere çözünürlüğünde çizilir (3x pencerede 1920x1080).

## Ayar dosyası. Testler bunu değiştirir; oyuncunun gerçek ayarlarına dokunmasınlar diye.
var settings_path := SETTINGS_PATH
var volumes := {}  ## bus adı -> 0..1 (Master, Music, SFX)
var fullscreen := false
var window_scale := 3  ## Pencere = BASE_SIZE x bu sayı (3 = 1920x1080; ekrana sığmazsa en büyük kat).
var battle_speed := 1
var screen_shake := true
var language := ""  ## "tr" / "en"; boşsa sistem diline göre seçilir.


func _init() -> void:
	_reset()  # dosya okunmadan önce de geçerli değerler olsun


func _ready() -> void:
	load_settings()
	apply_all()


func load_settings() -> void:
	_reset()
	var file := ConfigFile.new()
	if file.load(settings_path) != OK:
		return  # dosya yok ya da okunamadı: varsayılanlar
	for bus: StringName in volumes:
		volumes[bus] = clampf(float(file.get_value("audio", String(bus), volumes[bus])), 0.0, 1.0)
	fullscreen = bool(file.get_value("video", "fullscreen", fullscreen))
	window_scale = clampi(int(file.get_value("video", "window_scale", window_scale)), 1, 8)
	var speed := int(file.get_value("game", "battle_speed", battle_speed))
	battle_speed = speed if SPEEDS.has(speed) else 1
	screen_shake = bool(file.get_value("game", "screen_shake", screen_shake))
	var lang := String(file.get_value("game", "language", ""))
	language = lang if LANGUAGES.has(lang) else ""


func save_settings() -> void:
	var file := ConfigFile.new()
	for bus: StringName in volumes:
		file.set_value("audio", String(bus), volumes[bus])
	file.set_value("video", "fullscreen", fullscreen)
	file.set_value("video", "window_scale", window_scale)
	file.set_value("game", "battle_speed", battle_speed)
	file.set_value("game", "screen_shake", screen_shake)
	file.set_value("game", "language", language)
	var err := file.save(settings_path)
	if err != OK:
		push_error("Ayarlar kaydedilemedi: %s (%d)" % [settings_path, err])


func apply_all() -> void:
	for bus: StringName in volumes:
		_apply_volume(bus)
	_apply_window()
	TranslationServer.set_locale(current_language())


# --- Değiştiriciler: uygular ve kaydeder ---

func set_volume(bus: StringName, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volume(bus)
	save_settings()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_window()
	save_settings()


func set_window_scale(value: int) -> void:
	window_scale = value
	_apply_window()
	save_settings()


func set_battle_speed(value: int) -> void:
	battle_speed = value if SPEEDS.has(value) else 1
	save_settings()


func set_screen_shake(value: bool) -> void:
	screen_shake = value
	save_settings()


## Dil değişince ekrandaki yazılar kendiliğinden yenilenmez (çoğu koddan kurulur);
## çağıran ekranı yeniden yüklemelidir.
func set_language(code: String) -> void:
	language = code if LANGUAGES.has(code) else ""
	TranslationServer.set_locale(current_language())
	save_settings()


func current_language() -> String:
	if language != "":
		return language
	return "tr" if OS.get_locale_language() == "tr" else "en"


## Ekrana sığan pencere katları (1x = 640x360, 2x = 1280x720, 3x = 1920x1080 ...).
func available_scales() -> Array[int]:
	var screen := DisplayServer.screen_get_size()
	var result: Array[int] = [1]
	for s in range(2, 9):
		if BASE_SIZE.x * s <= screen.x and BASE_SIZE.y * s <= screen.y:
			result.append(s)
	return result


# --- İç işler ---

func _reset() -> void:
	volumes = {&"Master": 1.0, &"Music": 0.8, &"SFX": 0.8}
	fullscreen = false
	window_scale = 3
	battle_speed = 1
	screen_shake = true
	language = ""


## Ses düzeyi kaydırıcısı doğrusal (0-1), ses sunucusu desibel ister: linear_to_db çevirir.
## Audio'nun kanal başına taban düzeyi (DEFAULT_VOLUMES) korunur, kaydırıcı onun üstüne biner.
func _apply_volume(bus: StringName) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return
	var value: float = volumes[bus]
	AudioServer.set_bus_mute(index, value <= 0.0)
	var base: float = AudioScript.DEFAULT_VOLUMES.get(bus, 0.0)
	AudioServer.set_bus_volume_db(index, base + linear_to_db(maxf(value, 0.001)))


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
		return
	window.mode = Window.MODE_WINDOWED
	var scales := available_scales()
	var s: int = window_scale if scales.has(window_scale) else scales.back()
	window.size = BASE_SIZE * s
	window.move_to_center()
