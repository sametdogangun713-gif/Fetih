class_name BattleCamera
extends Camera2D
## Savaş alanı kamerası.
## WASD / ok tuşları: kaydır. Sağ veya orta tuşla sürükle: kaydır. Fare tekerleği: yakınlaştır.
## shake(): ekran sarsıntısı (boss vuruşu, patlama).

const PAN_SPEED := 320.0  ## Saniyede kaç ekran pikseli kayar.
## Piksel sanatın bozulmaması için yakınlaştırma sadece bu değerleri alır.
const ZOOM_LEVELS: Array[float] = [0.5, 1.0, 2.0]
const SHAKE_DECAY := 18.0  ## Sarsıntı gücü saniyede bu kadar piksel azalır.
const MAX_SHAKE := 8.0

## Kamera merkezinin dışına çıkamayacağı alan. battlefield.gd ayarlar.
var bounds := Rect2()

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
		# Yakınlaşınca aynı tuş daha az dünya mesafesi kaydırsın diye zoom'a bölünür.
		position += dir.normalized() * PAN_SPEED * delta / zoom.x
		_clamp_to_bounds()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_set_zoom_index(_zoom_index + 1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_set_zoom_index(_zoom_index - 1)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		position -= event.relative / zoom.x
		_clamp_to_bounds()


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
