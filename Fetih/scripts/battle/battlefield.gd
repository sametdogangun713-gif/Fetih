extends Node2D
## İzometrik savaş alanı (Aşama 1).
## - Karoları koddan döşer; savaş alanı boyutu ileride orduya göre değişebilir.
## - Fare altındaki karoyu vurgular ve koordinatını gösterir.
## - Sol tık: karoya test askeri koyar (Y-sort denemesi). C tuşu: test askerlerini siler.

enum Zone { PLAYER, NEUTRAL, ENEMY }

const FIELD_WIDTH := 10  ## Cephe genişliği (x ekseni, ekranda sağ alta doğru).
const FIELD_DEPTH := 16  ## İki ordu arası derinlik (y ekseni, ekranda sol alta doğru).
const DEPLOY_ROWS := 5  ## Her ordunun yerleşim bölgesi kaç satır.

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

@onready var ground: TileMapLayer = $Ground
@onready var highlight: TileMapLayer = $Highlight
@onready var units: Node2D = $Units
@onready var camera: Camera2D = $BattleCamera
@onready var cell_label: Label = $DebugHUD/CellLabel

var _hovered_cell := Vector2i(-1, -1)


func _ready() -> void:
	_build_field()
	_setup_camera()


func _process(_delta: float) -> void:
	_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := mouse_cell()
		if is_inside(cell):
			print("Tıklanan karo: ", cell, "  dünya konumu: ", ground.map_to_local(cell))
			_spawn_test_soldier(cell)
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_C:
		for soldier in units.get_children():
			soldier.queue_free()


## Oyuncu sol altta (büyük y), düşman sağ üstte (küçük y).
func zone_of(cell: Vector2i) -> Zone:
	if cell.y >= FIELD_DEPTH - DEPLOY_ROWS:
		return Zone.PLAYER
	if cell.y < DEPLOY_ROWS:
		return Zone.ENEMY
	return Zone.NEUTRAL


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < FIELD_WIDTH and cell.y >= 0 and cell.y < FIELD_DEPTH


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


## Geçici asker: ayakları karonun ortasında duran bir dikdörtgen.
## Units düğümünde Y-sort açık olduğu için ekranda aşağıda olan önde çizilir.
func _spawn_test_soldier(cell: Vector2i) -> void:
	var soldier := Polygon2D.new()
	soldier.polygon = PackedVector2Array([
		Vector2(-4, -20), Vector2(4, -20), Vector2(4, 0), Vector2(-4, 0),
	])
	soldier.color = Color("c8443a") if zone_of(cell) == Zone.ENEMY else Color("3d6fd1")
	soldier.position = ground.map_to_local(cell)
	units.add_child(soldier)
