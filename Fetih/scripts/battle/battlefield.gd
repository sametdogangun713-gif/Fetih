class_name Battlefield
extends Node2D
## İzometrik savaş alanı.
## - Zemini GroundArt çizer; burada sadece koordinat dönüşümleri ve bölgeler var.
## - Savaş alanı koordinatı (karo, ondalıklı) <-> ekran konumu dönüşümlerini sağlar.

enum Zone { PLAYER, NEUTRAL, ENEMY }

const FIELD_WIDTH := 10  ## Cephe genişliği (x ekseni, ekranda sol alta doğru).
const FIELD_DEPTH := 16  ## İki ordu arası derinlik (y ekseni, ekranda sağ alta doğru).
const DEPLOY_ROWS := 5  ## Her ordunun yerleşim bölgesi kaç satır.

## Karonun yarı boyutu (64x32 karo). Dönüşüm formülleri buna dayanır.
const TILE_HALF := Vector2(32, 16)

@onready var ground_art: GroundArt = $GroundArt
@onready var units: Node2D = $Units
@onready var fx: BattleFx = $Fx
@onready var camera: BattleCamera = $BattleCamera

var _camps: Array[Sprite2D] = []  ## Kamp/kale yapıları (KingdomCamp), set_camps yeniler.


## Geliştirici aracı: tıklanan savaş alanı noktasını yazar. Koşuda kapalı; sahne tek başına açılınca açık.
func set_debug_tools(on: bool) -> void:
	set_process_unhandled_input(on)


## Savaş alanı koordinatını ekran (dünya) konumuna çevirir.
## Tam sayı koordinatlar karo merkezlerine denk gelir; karo merkezi = field_offset_to_world + TILE_HALF.
static func field_to_world(p: Vector2) -> Vector2:
	return field_offset_to_world(p) + TILE_HALF


## Savaş alanındaki bir yön/uzaklığı ekran yönüne çevirir (konum değil, fark).
## Aynalı izometrik: x ekseni ekranda sol alta, y ekseni sağ alta gider. Oyuncu (büyük y) sağ altta.
static func field_offset_to_world(d: Vector2) -> Vector2:
	return Vector2(TILE_HALF.x * (d.y - d.x), TILE_HALF.y * (d.x + d.y))


## Ekran (dünya) konumunu savaş alanı koordinatına çevirir (field_to_world'ün tersi).
static func world_to_field(w: Vector2) -> Vector2:
	var q := w - TILE_HALF
	var diff := q.x / TILE_HALF.x  # y - x
	var total := q.y / TILE_HALF.y  # x + y
	return Vector2((total - diff) / 2.0, (total + diff) / 2.0)


## Farenin savaş alanı koordinatı (ondalıklı).
func mouse_field() -> Vector2:
	return world_to_field(get_local_mouse_position())


## Fare olayının savaş alanı koordinatı. Olayın kendi konumundan hesaplanır (imleci yoklamak yerine):
## sentetik olaylarda (Input.parse_input_event) da doğru çalışır. Godot: make_input_local, olayı
## bu düğümün yerel (kamera dahil) koordinatına çevirir.
func event_field(event: InputEventMouse) -> Vector2:
	return world_to_field((make_input_local(event) as InputEventMouse).position)


func zone_of_field(p: Vector2) -> Zone:
	return zone_of(Vector2i(floori(p.x + 0.5), floori(p.y + 0.5)))


func _ready() -> void:
	_setup_camera()
	set_biome(&"default")


## Arazi görünümü (zemin tonu, ağaçlar) rakip krallığa göre. Bkz. GroundArt.BIOMES.
func set_biome(kingdom_id: StringName) -> void:
	ground_art.setup(kingdom_id, units)


## Ordularının arkasındaki krallık kampları: eskileri silinir, yenileri kurulur (sadece görüntü).
func set_camps(player_kingdom: KingdomData, enemy_kingdom: KingdomData) -> void:
	for sprite in _camps:
		sprite.queue_free()
	_camps.clear()
	if player_kingdom != null:
		_camps.append_array(KingdomCamp.build(units, player_kingdom, SquadState.Team.PLAYER))
	if enemy_kingdom != null:
		_camps.append_array(KingdomCamp.build(units, enemy_kingdom, SquadState.Team.ENEMY))


## Kamp yapılarının dünya kutusu (iki kampın sprite'ları birleşik). Kamp yoksa boş Rect2.
## Godot: Sprite2D.offset ve texture boyutu sprite'ın kutusunu verir (centered kapalı).
func camps_rect() -> Rect2:
	var rect := Rect2()
	var first := true
	for sprite in _camps:
		if sprite.texture == null:
			continue
		var box := Rect2(sprite.position + sprite.offset, sprite.texture.get_size())
		rect = box if first else rect.merge(box)
		first = false
	return rect


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Tıklanan nokta: ", mouse_field())


## Oyuncu sağ altta (büyük y), düşman sol üstte (küçük y).
func zone_of(cell: Vector2i) -> Zone:
	if cell.y >= FIELD_DEPTH - DEPLOY_ROWS:
		return Zone.PLAYER
	if cell.y < DEPLOY_ROWS:
		return Zone.ENEMY
	return Zone.NEUTRAL


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < FIELD_WIDTH and cell.y >= 0 and cell.y < FIELD_DEPTH


## Bölük merkezlerinin çıkamayacağı alan (savaş alanı koordinatı).
func field_rect() -> Rect2:
	return Rect2(0, 0, FIELD_WIDTH - 1, FIELD_DEPTH - 1)


func _setup_camera() -> void:
	# Kamera merkezi bu dikdörtgenin içinde gezebilir; savaş başı bütününü sığdırır.
	# Köşeler alanın 3 karo dışında: ordunun arkasındaki yapılar (KingdomCamp) da kapsanır.
	var pad := 3.0
	var corners: Array[Vector2] = [
		Vector2(-pad, -pad),
		Vector2(FIELD_WIDTH - 1 + pad, -pad),
		Vector2(-pad, FIELD_DEPTH - 1 + pad),
		Vector2(FIELD_WIDTH - 1 + pad, FIELD_DEPTH - 1 + pad),
	]
	var bounds := Rect2(field_to_world(corners[0]), Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(field_to_world(corner))
	camera.bounds = bounds
	camera.position = bounds.get_center()
