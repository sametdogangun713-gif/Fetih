class_name BattleCamera
extends Camera2D
## Savaş alanı kamerası.
## Otomatik takip (varsayılan): follow() her karede yaşayan bölükleri kapsayan kutuyu alır;
## kamera kutunun ortasına kayar ve hepsi sığdığı sürece en yakın seviyeye geçer.
## WASD / ok tuşları: kaydır. Sağ veya orta tuşla sürükle: kaydır. Fare tekerleği: yakınlaştır.
## Elle kaydırma/yakınlaştırma takibi kapatır; F tuşu tekrar açar.
## shake(): ekran sarsıntısı (boss vuruşu, patlama).

const PAN_SPEED := 320.0  ## Saniyede kaç ekran pikseli kayar.
## Yakınlık seviyeleri. Oyun pencere çözünürlüğünde çizildiği için (canvas_items, 3x pencerede
## 1920x1080) ara değerler de temiz görünür; piksel sanat birlikler ekranda 3 x yakınlık katı büyür.
const ZOOM_LEVELS: Array[float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
const SHAKE_DECAY := 18.0  ## Sarsıntı gücü saniyede bu kadar piksel azalır.
const MAX_SHAKE := 8.0
const FOLLOW_SPEED := 2.5  ## Takipte kameranın hedefe yaklaşma hızı (1/sn, üstel).
const ZOOM_SPEED := 3.0
## Daha yakına geçmek için kutunun etrafında kalması gereken boşluk (ekran pikseli). Geri çıkmak için
## daha az boşluk yeter: iki eşik arasında yakınlık sabit kalır, kamera gidip gelmez.
const FIT_MARGIN := 40.0
const KEEP_MARGIN := 12.0

## Kamera merkezinin dışına çıkamayacağı alan. battlefield.gd ayarlar.
var bounds := Rect2()

var auto_follow := true

var _zoom_index := 1
var _dragging := false
var _shake := 0.0


## Ekranı sarsar (piksel). Üst üste gelen sarsıntılar toplanmaz, güçlü olan geçerlidir.
func shake(strength: float) -> void:
	_shake = clampf(maxf(_shake, strength), 0.0, MAX_SHAKE)


func _process(delta: float) -> void:
	_update_shake(delta)
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		auto_follow = false
		# Yakınlaşınca aynı tuş daha az dünya mesafesi kaydırsın diye zoom'a bölünür.
		position += dir.normalized() * PAN_SPEED * delta / zoom.x
		_clamp_to_bounds()


## Otomatik takip: rect (bu düğümün ebeveyn koordinatında) ekranda kalsın. instant: beklemeden atla
## (savaş başı). Yakınlık ZOOM_LEVELS değerlerine yerleşir; aradaki değerler sadece geçiş anında.
func follow(rect: Rect2, delta: float, instant := false) -> void:
	if not auto_follow or not rect.has_area():
		return
	var screen := get_viewport_rect().size
	var current := ZOOM_LEVELS[_zoom_index]
	var best := ZOOM_LEVELS[0]
	for level in ZOOM_LEVELS:
		var margin := KEEP_MARGIN if level <= current else FIT_MARGIN
		if rect.size.x * level <= screen.x - margin * 2.0 and rect.size.y * level <= screen.y - margin * 2.0:
			best = level
	_zoom_index = ZOOM_LEVELS.find(best)
	var z := best if instant else lerpf(zoom.x, best, 1.0 - exp(-ZOOM_SPEED * delta))
	if absf(z - best) < 0.01:
		z = best
	zoom = Vector2(z, z)
	var t := 1.0 if instant else 1.0 - exp(-FOLLOW_SPEED * delta)
	position = position.lerp(rect.get_center(), t)
	_clamp_to_bounds()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					auto_follow = false
					_set_zoom_index(_zoom_index + 1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					auto_follow = false
					_set_zoom_index(_zoom_index - 1)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		auto_follow = false
		position -= event.relative / zoom.x
		_clamp_to_bounds()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		auto_follow = true


func _set_zoom_index(index: int) -> void:
	_zoom_index = clampi(index, 0, ZOOM_LEVELS.size() - 1)
	zoom = Vector2.ONE * ZOOM_LEVELS[_zoom_index]


func _clamp_to_bounds() -> void:
	if bounds.has_area():
		position = position.clamp(bounds.position, bounds.end)


## Kameranın kendisi değil, offset'i titrer: kaydırma ve sınırlar etkilenmez.
## Tam piksele yuvarlanır ki piksel sanat bulanıklaşmasın.
func _update_shake(delta: float) -> void:
	if _shake <= 0.0:
		offset = Vector2.ZERO
		return
	offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
	_shake = maxf(_shake - SHAKE_DECAY * delta, 0.0)
