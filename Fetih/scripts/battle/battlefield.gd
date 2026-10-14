class_name Battlefield
extends Node2D
## İzometrik savaş alanı.
## - Karoları koddan döşer; savaş alanı boyutu ileride orduya göre değişebilir.
## - Fare altındaki karoyu vurgular ve koordinatını gösterir.
## - Savaş alanı koordinatı (karo, ondalıklı) <-> ekran konumu dönüşümlerini sağlar.

enum Zone { PLAYER, NEUTRAL, ENEMY }

const FIELD_WIDTH := 10  ## Cephe genişliği (x ekseni, ekranda sağ alta doğru).
const FIELD_DEPTH := 16  ## İki ordu arası derinlik (y ekseni, ekranda sol alta doğru).
const DEPLOY_ROWS := 5  ## Her ordunun yerleşim bölgesi kaç satır.

## Karonun yarı boyutu (64x32 karo). Dönüşüm formülleri buna dayanır.
const TILE_HALF := Vector2(32, 16)

# battlefield_tileset.tres içindeki atlas koordinatları (tools/build_placeholder_tiles.gd ile aynı sıra).
const SOURCE_ID := 0
const TILE_GRASS_A := Vector2i(0, 0)
const TILE_GRASS_B := Vector2i(1, 0)
const TILE_PLAYER_ZONE := Vector2i(2, 0)
const TILE_ENEMY_ZONE := Vector2i(3, 0)
const TILE_HIGHLIGHT := Vector2i(4, 0)

const ZONE_NAMES := {
	Zone.PLAYER: "Oyuncu bölgesi",
	Zone.NEUTRAL: "Orta saha",
	Zone.ENEMY: "Düşman bölgesi",
}

@onready var ground_art: GroundArt = $GroundArt
## Görünmez: sadece karo <-> ekran dönüşümleri için (local_to_map, map_to_local). Zemini GroundArt çizer.
@onready var ground: TileMapLayer = $Ground
@onready var highlight: TileMapLayer = $Highlight
@onready var units: Node2D = $Units
@onready var fx: BattleFx = $Fx
@onready var camera: BattleCamera = $BattleCamera
@onready var cell_label: Label = $DebugHUD/CellLabel

var _hovered_cell := Vector2i(-1, -1)


## Geliştirici araçları: fare altındaki karo vurgusu, koordinat yazısı, tıklanan karo çıktısı.
## Koşuda kapalı (savaşta karo seçilmez); sahne tek başına açılınca (test modu) açık.
func set_debug_tools(on: bool) -> void:
	$DebugHUD.visible = on
	set_process(on)
	set_process_unhandled_input(on)
	if not on:
		highlight.clear()


## Savaş alanı koordinatını ekran (dünya) konumuna çevirir.
## Tam sayı koordinatlar karo merkezlerine denk gelir; map_to_local() ile aynı sonucu verir.
static func field_to_world(p: Vector2) -> Vector2:
	return field_offset_to_world(p) + TILE_HALF


## Savaş alanındaki bir yön/uzaklığı ekran yönüne çevirir (konum değil, fark).
static func field_offset_to_world(d: Vector2) -> Vector2:
	return Vector2(TILE_HALF.x * (d.x - d.y), TILE_HALF.y * (d.x + d.y))


func _ready() -> void:
	_build_field()
	_setup_camera()
	set_biome(&"default")


## Arazi görünümü (zemin tonu, ağaçlar) rakip krallığa göre. Bkz. GroundArt.BIOMES.
func set_biome(kingdom_id: StringName) -> void:
	ground_art.setup(kingdom_id, units)


func _process(_delta: float) -> void:
	_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := mouse_cell()
		if is_inside(cell):
			print("Tıklanan karo: ", cell, "  dünya konumu: ", ground.map_to_local(cell))


## Oyuncu sol altta (büyük y), düşman sağ üstte (küçük y).
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


## Farenin üstünde durduğu karo. Ekran koordinatı -> harita koordinatı dönüşümü.
func mouse_cell() -> Vector2i:
	return ground.local_to_map(ground.get_local_mouse_position())


func _build_field() -> void:
	for y in FIELD_DEPTH:
		for x in FIELD_WIDTH:
			var cell := Vector2i(x, y)
			ground.set_cell(cell, SOURCE_ID, _tile_for(cell))


func _tile_for(cell: Vector2i) -> Vector2i:
	match zone_of(cell):
		Zone.PLAYER:
			return TILE_PLAYER_ZONE
		Zone.ENEMY:
			return TILE_ENEMY_ZONE
	# Orta sahada dama deseni: karolar birbirinden ayırt edilsin.
	return TILE_GRASS_A if (cell.x + cell.y) % 2 == 0 else TILE_GRASS_B


func _setup_camera() -> void:
	# Kamera, dört köşe karonun oluşturduğu dikdörtgenin içinde gezebilir.
	var corners: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(FIELD_WIDTH - 1, 0),
		Vector2i(0, FIELD_DEPTH - 1),
		Vector2i(FIELD_WIDTH - 1, FIELD_DEPTH - 1),
	]
	var bounds := Rect2(ground.map_to_local(corners[0]), Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(ground.map_to_local(corner))
	camera.bounds = bounds
	camera.position = bounds.get_center()


func _update_hover() -> void:
	var cell := mouse_cell()
	if cell == _hovered_cell:
		return
	_hovered_cell = cell
	highlight.clear()
	if is_inside(cell):
		highlight.set_cell(cell, SOURCE_ID, TILE_HIGHLIGHT)
		cell_label.text = "Karo: %s  -  %s" % [cell, ZONE_NAMES[zone_of(cell)]]
	else:
		cell_label.text = ""
