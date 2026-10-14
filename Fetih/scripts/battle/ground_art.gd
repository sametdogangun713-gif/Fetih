class_name GroundArt
extends Node2D
## Savaş alanının HD zemini (sadece görüntü; simülasyona ve koordinatlara dokunmaz).
## Çimen karoları, ot/kaya süsleri, yerleşim bölgesi renkleri ve alanın etrafında arazi çizer;
## ağaçları bölüklerle derinlik sıralansın diye Units düğümüne Sprite2D olarak ekler.
## Görseller CC0 (rubberduck, OpenGameArt): kaynak_assetler/LISANSLAR.md.
##
## Karo dokusu 128x64, dünyada 64x32 yer kaplar: 3x pencerede (1920x1080) ekranda 192x96 olur.
## Bu yüzden düğüm doğrusal süzme kullanır (piksel sanat birlikleri Nearest kalır).

const SHEET: Texture2D = preload("res://assets/terrain/ground_128x64.png")
const PLANT_DIR := "res://assets/terrain/plants/"
const CELL := 128  ## Sayfadaki hücre: karo hücrenin alt yarısında (128x64), süsler hücrenin ortasında.
const GRASS_VARIANTS := 8
## Süs satırları ve satırdaki adet: 1-2 ot öbeği, 3 yapraklı bitki, 4 kuru ot, 5-6 kaya.
const TUFTS: Array[Vector2i] = [Vector2i(1, 8), Vector2i(2, 8)]
const PLANTS: Array[Vector2i] = [Vector2i(3, 8), Vector2i(4, 8)]
const ROCKS: Array[Vector2i] = [Vector2i(5, 8), Vector2i(6, 4)]
const MARGIN := 9  ## Savaş alanının etrafında kaç karo arazi çizilir.
const BACKDROP := Vector2(4000, 2400)  ## Arazinin altındaki düz zemin (dünya pikseli).
const TREE_SCALE := 0.34  ## 256 piksellik ağaç dokusu dünyada ~85 piksel: 3x pencerede aşağı yukarı 1:1.
const ZONE_TINT := {
	Battlefield.Zone.PLAYER: Color(0.25, 0.45, 1.0, 0.16),
	Battlefield.Zone.ENEMY: Color(1.0, 0.3, 0.2, 0.16),
}

## Rakip krallığa göre arazi: zemin tonu, ağaç türleri (plants/ klasöründeki dosya adı başları),
## ağaç yoğunluğu çarpanı.
const BIOMES := {
	&"default": {tint = Color(1, 1, 1), trees = ["pine-none", "bigtree", "bush"], density = 1.0},
	&"humans": {tint = Color(1, 1, 1), trees = ["bigtree", "pine-none", "bush"], density = 1.0},
	&"elves": {tint = Color(0.9, 1.05, 0.9), trees = ["bigtree", "pine-none"], density = 1.5},
	&"orcs": {tint = Color(1.08, 0.98, 0.78), trees = ["shrub1", "bush"], density = 0.7},
	&"dwarves": {tint = Color(1.05, 1.08, 1.15), trees = ["pine-full", "pine-half"], density = 1.1},
	&"undead": {tint = Color(0.78, 0.8, 0.78), trees = ["pine-half", "shrub2"], density = 0.8},
	&"demons": {tint = Color(1.1, 0.8, 0.7), trees = ["shrub2", "shrub1"], density = 0.6},
	&"slimes": {tint = Color(0.9, 1.1, 0.85), trees = ["bush", "bigtree"], density = 1.0},
	&"mud": {tint = Color(0.8, 0.85, 0.7), trees = ["shrub2", "bush"], density = 1.2},
	&"golems": {tint = Color(0.95, 0.95, 0.95), trees = ["pine-half", "pine-none"], density = 0.8},
	&"centaurs": {tint = Color(1.12, 1.05, 0.75), trees = ["shrub1", "bush"], density = 0.4},
}

var _biome: Dictionary = BIOMES[&"default"]
var _trees: Array[Sprite2D] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## Araziyi kurar. biome: krallık id (BIOMES'ta yoksa varsayılan). tree_parent: y-sort'lu Units düğümü.
func setup(biome: StringName, tree_parent: Node2D) -> void:
	_biome = BIOMES.get(biome, BIOMES[&"default"])
	for tree in _trees:
		tree.queue_free()
	_trees.clear()
	_plant_trees(tree_parent)
	queue_redraw()


func _draw() -> void:
	var w := Battlefield.FIELD_WIDTH
	var d := Battlefield.FIELD_DEPTH
	var tint: Color = _biome.tint
	# Altta düz zemin rengi: karoların yumuşak kenarlarındaki ince boşluklar ve çizilen arazinin
	# dışı (kamera en uzakta, köşeler) boş kalmasın.
	var mid := Battlefield.field_to_world(Vector2(w, d) / 2.0)
	draw_rect(Rect2(mid - BACKDROP / 2.0, BACKDROP), Color("3a6326") * tint * Color(0.86, 0.88, 0.84))
	for y in range(-MARGIN, d + MARGIN):
		for x in range(-MARGIN, w + MARGIN):
			var cell := Vector2i(x, y)
			var rng := _cell_rng(cell, 1)
			var variant := rng.randi_range(0, GRASS_VARIANTS - 1)
			var inside := x >= 0 and x < w and y >= 0 and y < d
			var shade := tint if inside else tint * Color(0.86, 0.88, 0.84)
			var center := Battlefield.field_to_world(Vector2(cell))
			draw_texture_rect_region(SHEET, Rect2(center - Vector2(33, 17), Vector2(66, 34)),
					Rect2(variant * CELL, CELL / 2, CELL, CELL / 2), shade)
	# Yerleşim bölgeleri: hafif takım rengi.
	var rows := Battlefield.DEPLOY_ROWS
	draw_colored_polygon(_diamond(Vector2(0, d - rows), Vector2(w, d)), ZONE_TINT[Battlefield.Zone.PLAYER])
	draw_colored_polygon(_diamond(Vector2(0, 0), Vector2(w, rows)), ZONE_TINT[Battlefield.Zone.ENEMY])
	# Savaş alanının sınırı.
	var edge := _diamond(Vector2.ZERO, Vector2(w, d))
	edge.append(edge[0])
	draw_polyline(edge, Color(0.1, 0.12, 0.05, 0.35), 1.0)
	_draw_decals(w, d)


## Ot, bitki ve kayalar: alan içinde seyrek ve küçük, dışarıda sık.
func _draw_decals(w: int, d: int) -> void:
	for y in range(-MARGIN, d + MARGIN):
		for x in range(-MARGIN, w + MARGIN):
			var cell := Vector2i(x, y)
			var rng := _cell_rng(cell, 2)
			var inside := x >= 0 and x < w and y >= 0 and y < d
			var roll := rng.randf()
			var group: Array[Vector2i]
			if inside:
				if roll > 0.18:
					continue
				group = TUFTS
			elif roll < 0.35:
				group = TUFTS
			elif roll < 0.5:
				group = PLANTS
			elif roll < 0.6:
				group = ROCKS
			else:
				continue
			var row: Vector2i = group[rng.randi_range(0, group.size() - 1)]
			var col := rng.randi_range(0, row.y - 1)
			var center := Battlefield.field_to_world(Vector2(cell)) \
					+ Vector2(rng.randf_range(-14, 14), rng.randf_range(-6, 6))
			draw_texture_rect_region(SHEET, Rect2(center - Vector2(32, 40), Vector2(64, 64)),
					Rect2(col * CELL, row.x * CELL, CELL, CELL), _biome.tint)


## Ağaçlar alanın dışında, kenardan uzaklaştıkça sıklaşır. Ekranda alanın önünde (aşağıda) kalan
## kenarlarda daha geniş boşluk: uzun ağaçlar kenardaki bölükleri örtmesin.
func _plant_trees(parent: Node2D) -> void:
	var textures := _tree_textures()
	if textures.is_empty():
		return
	var w := Battlefield.FIELD_WIDTH
	var d := Battlefield.FIELD_DEPTH
	for y in range(-MARGIN, d + MARGIN):
		for x in range(-MARGIN, w + MARGIN):
			var back := maxi(-x, -y)  # arka kenarlardan (ekranda yukarı) uzaklık
			var front := maxi(x - (w - 1), y - (d - 1))  # ön kenarlardan (ekranda aşağı) uzaklık
			var dist := maxi(back, front)
			var clear := 3 if front >= back else 2
			if dist < clear:
				continue
			var rng := _cell_rng(Vector2i(x, y), 3)
			var chance := clampf((dist - clear + 1) * 0.1, 0.0, 0.5) * float(_biome.density)
			if rng.randf() > chance:
				continue
			var texture: Texture2D = textures[rng.randi_range(0, textures.size() - 1)]
			var tree := Sprite2D.new()
			tree.texture = texture
			tree.centered = false
			tree.offset = -_tree_base(texture)
			tree.scale = Vector2.ONE * TREE_SCALE * rng.randf_range(0.8, 1.15)
			tree.flip_h = rng.randf() < 0.5
			tree.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			tree.position = Battlefield.field_to_world(Vector2(x, y)) \
					+ Vector2(rng.randf_range(-12, 12), rng.randf_range(-6, 6))
			if tree.flip_h:
				tree.offset.x = -texture.get_width() - tree.offset.x
			parent.add_child(tree)
			_trees.append(tree)


func _tree_textures() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for file in DirAccess.get_files_at(PLANT_DIR):
		if not file.ends_with(".png"):
			continue
		for prefix: String in _biome.trees:
			if file.begins_with(prefix):
				out.append(load(PLANT_DIR + file))
	return out


static var _base_cache := {}  ## doku yolu -> gövde dibi (dokunun piksel koordinatı)


## Ağacın yere bastığı nokta: dolu alanın alt ortası (gölgesi kadar yukarıda).
static func _tree_base(texture: Texture2D) -> Vector2:
	if not _base_cache.has(texture.resource_path):
		var used := texture.get_image().get_used_rect()
		_base_cache[texture.resource_path] = Vector2(used.position.x + used.size.x / 2.0,
				used.end.y - used.size.y * 0.12)
	return _base_cache[texture.resource_path]


## Savaş alanı koordinatındaki dikdörtgenin (karo köşeleri) ekrandaki eşkenar dörtgeni.
static func _diamond(from: Vector2, to: Vector2) -> PackedVector2Array:
	var half := Vector2(0.5, 0.5)
	return PackedVector2Array([
		Battlefield.field_to_world(from - half),
		Battlefield.field_to_world(Vector2(to.x, from.y) - half),
		Battlefield.field_to_world(to - half),
		Battlefield.field_to_world(Vector2(from.x, to.y) - half),
	])


## Karo başına sabit rastgelelik: harita her açılışta aynı görünür (simülasyonla ilgisi yok).
static func _cell_rng(cell: Vector2i, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(cell.x, cell.y, salt))
	return rng
