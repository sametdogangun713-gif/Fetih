class_name GroundArt
extends Node2D
## Savaş alanının piksel zemini (sadece görüntü; simülasyona ve koordinatlara dokunmaz).
## 9 Kings gibi sakin zemin: biyom başına tek düz renk (ramp[1]), üstünde çok seyrek, düşük kontrastlı
## motif (ot tutamı, kum dalgası, taşçık: 2-5 px, karo başına ~0.3). Karo deseni ve alan sınırı yok;
## alan dışında aynı renk sürer. Büyük süsler (ot, bitki, kaya) alan kenarında seyrekten sıka geçer;
## ağaçlar bölüklerle derinlik sıralansın diye Units düğümüne Sprite2D olarak eklenir.
## Süs ve ağaç görselleri CC0 (rubberduck, OpenGameArt): kaynak_assetler/LISANSLAR.md.
##
## Süs/ağaç dokuları tools/build_ground.gd ile 0.5x küçültülüp Resurrect 64'e indirilir (süsler 64x64
## hücre, ağaçlar 0.34x). Her piksel dünyada 1 piksel: Nearest süzme, alt-piksel kayma yok.

const TEX_DIR := "res://assets/terrain/px/"
const PLANT_DIR := "res://assets/terrain/px/plants/"
const CELL := 64  ## Sayfadaki süs hücresi (64x64).
## Süs satırları ve satırdaki adet: 1-2 ot öbeği, 3 yapraklı bitki, 4 kuru ot, 5-6 kaya.
const TUFTS: Array[Vector2i] = [Vector2i(1, 8), Vector2i(2, 8)]
const PLANTS: Array[Vector2i] = [Vector2i(3, 8), Vector2i(4, 8)]
const ROCKS: Array[Vector2i] = [Vector2i(5, 8), Vector2i(6, 4)]
const MARGIN := 9  ## Savaş alanının etrafında kaç karo arazi çizilir.
const BACKDROP := Vector2(4000, 2400)  ## Arazinin altındaki düz zemin (dünya pikseli).
const ZONE_COLOR := Color(1, 0.85, 0.3, 0.06)  ## Hazırlıkta oyuncu bölgesi (çok hafif altın).
const MOTIF_CHANCE := 0.3  ## Karo başına motif olasılığı.
const CLUSTER_CELL := 3  ## Ağaç öbeği hücresi (karo).
const CLUSTER_CHANCE := 0.4  ## Hücrede öbek olasılığı (biyom yoğunluğuyla çarpılır).
enum Motif { TUFT, WAVE, PEBBLE }  ## Ot tutamı, kum dalgası, taşçık.
## Biyomun motif türü: çimen biyomları ot, çöl/kuru kum, karanlık taş.
const MOTIF_OF := {
	&"default": Motif.TUFT, &"humans": Motif.TUFT, &"elves": Motif.TUFT, &"slimes": Motif.TUFT,
	&"dwarves": Motif.TUFT, &"orcs": Motif.WAVE, &"centaurs": Motif.WAVE, &"undead": Motif.PEBBLE,
	&"demons": Motif.PEBBLE, &"mud": Motif.PEBBLE, &"golems": Motif.PEBBLE,
}

## Rakip krallığa göre arazi. tint: yalnızca build_ground.gd süsleri boyarken kullanır (çalışma anında
## çarpan yok, aksi hâlde palet bozulur). ramp: çimen karosunun koyu-orta-açık Resurrect 64 renkleri.
## trees: ağaç türleri (plants/ klasöründeki dosya adı başları), density: ağaç yoğunluğu çarpanı.
const BIOMES := {
	&"default": {tint = Color(1, 1, 1), ramp = ["165a4c", "239063", "1ebc73"],
			trees = ["pine-none", "bush"], density = 1.0},
	&"humans": {tint = Color(1, 1, 1), ramp = ["165a4c", "239063", "1ebc73"],
			trees = ["pine-none", "bush", "shrub1"], density = 1.0},
	&"elves": {tint = Color(0.9, 1.05, 0.9), ramp = ["239063", "1ebc73", "91db69"],
			trees = ["pine-none", "bush"], density = 1.5},
	&"orcs": {tint = Color(1.08, 0.98, 0.78), ramp = ["4c3e24", "676633", "a2a947"],
			trees = ["shrub1", "bush"], density = 0.7},
	&"dwarves": {tint = Color(1.05, 1.08, 1.15), ramp = ["374e4a", "547e64", "92a984"],
			trees = ["pine-full", "pine-half"], density = 1.1},
	&"undead": {tint = Color(0.78, 0.8, 0.78), ramp = ["313638", "374e4a", "625565"],
			trees = ["pine-half", "shrub2"], density = 0.8},
	&"demons": {tint = Color(1.1, 0.8, 0.7), ramp = ["2e222f", "4c3e24", "6e2727"],
			trees = ["shrub2", "shrub1"], density = 0.6},
	&"slimes": {tint = Color(0.9, 1.1, 0.85), ramp = ["165a4c", "239063", "0eaf9b"],
			trees = ["bush", "pine-none"], density = 1.0},
	&"mud": {tint = Color(0.8, 0.85, 0.7), ramp = ["313638", "4c3e24", "676633"],
			trees = ["shrub2", "bush"], density = 1.2},
	&"golems": {tint = Color(0.95, 0.95, 0.95), ramp = ["313638", "625565", "ab947a"],
			trees = ["pine-half", "pine-none"], density = 0.8},
	&"centaurs": {tint = Color(1.12, 1.05, 0.75), ramp = ["676633", "a2a947", "cddf6c"],
			trees = ["shrub1", "bush"], density = 0.4},
}

static var _sheets := {}  ## biyom id -> Texture2D (ground_<biyom>.png)
static var _base_cache := {}  ## doku yolu -> gövde dibi (dokunun piksel koordinatı)

var _biome: Dictionary = BIOMES[&"default"]
var _biome_id: StringName = &"default"
var _sheet: Texture2D  ## Süs sayfası (ot/bitki/kaya).
var _show_zone := false
var _trees: Array[Sprite2D] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Araziyi kurar. biome: krallık id (BIOMES'ta yoksa varsayılan). tree_parent: y-sort'lu Units düğümü.
func setup(biome: StringName, tree_parent: Node2D) -> void:
	var id := biome if BIOMES.has(biome) else &"default"
	_biome = BIOMES[id]
	_biome_id = id
	_sheet = _load_sheet(id)
	for tree in _trees:
		tree.queue_free()
	_trees.clear()
	_plant_trees(tree_parent)
	queue_redraw()


## Hazırlıkta oyuncu bölgesini çok hafif altın gösterir.
func show_player_zone(on: bool) -> void:
	_show_zone = on
	queue_redraw()


## Biyom sayfası (bir kez yüklenir). Dosya yoksa varsayılan biyom.
static func _load_sheet(id: StringName) -> Texture2D:
	if not _sheets.has(id):
		var path := TEX_DIR + "ground_%s.png" % id
		_sheets[id] = load(path) if ResourceLoader.exists(path) else _load_sheet(&"default")
	return _sheets[id]


func _draw() -> void:
	if _sheet == null:
		return
	var w := Battlefield.FIELD_WIDTH
	var d := Battlefield.FIELD_DEPTH
	# (1) Düz zemin: alanın içi ve dışı aynı renk.
	var mid := Battlefield.field_to_world(Vector2(w, d) / 2.0)
	draw_rect(Rect2(mid - BACKDROP / 2.0, BACKDROP), Color(_biome.ramp[1]))
	# (2) Seyrek motifler: noktalar motif_points'ten (test ile görüntü aynı kaynak), hepsi tam piksel.
	var rect := Rect2i(-MARGIN, -MARGIN, w + MARGIN * 2, d + MARGIN * 2)
	var dark := Color(_biome.ramp[0])
	var light := Color(_biome.ramp[2])
	for p in motif_points(_biome_id, rect):
		_draw_motif(p, dark, light)
	# (3) Hazırlıkta oyuncu bölgesi.
	if _show_zone:
		var rows := Battlefield.DEPLOY_ROWS
		draw_colored_polygon(_diamond(Vector2(0, d - rows), Vector2(w, d)), ZONE_COLOR)
	# (4) Seyrek kenar süsleri.
	_draw_decals(w, d)


## Motif noktaları: (dünya x, dünya y, Motif türü). Karo başına _cell_rng(cell, 4); deterministik.
## rect karo koordinatındadır; her karoda MOTIF_CHANCE olasılıkla karo içinde rastgele bir nokta.
static func motif_points(biome_id: StringName, rect: Rect2i) -> Array[Vector3i]:
	var kind: int = MOTIF_OF.get(biome_id, Motif.TUFT)
	var out: Array[Vector3i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			var rng := _cell_rng(cell, 4)
			if rng.randf() >= MOTIF_CHANCE:
				continue
			var pos := (Battlefield.field_to_world(Vector2(cell)) 					+ Vector2(rng.randf_range(-24, 24), rng.randf_range(-10, 10))).round()
			out.append(Vector3i(int(pos.x), int(pos.y), kind))
	return out


## Tek motif: sol üst köşesi p; sadece draw_rect (1 piksel birimleri), alt-piksel yok.
func _draw_motif(p: Vector3i, dark: Color, light: Color) -> void:
	var x := p.x
	var y := p.y
	match p.z:
		Motif.TUFT:  # "ı ı" biçimi: 1x2 + 1x3 + 1x2 dikey çubuklar, tabanları hizalı
			draw_rect(Rect2(x, y + 1, 1, 2), light)
			draw_rect(Rect2(x + 2, y, 1, 3), light)
			draw_rect(Rect2(x + 4, y + 1, 1, 2), light)
		Motif.WAVE:  # yatay 2 px, 1 px yukarı, yatay 2 px
			draw_rect(Rect2(x, y + 1, 2, 1), dark)
			draw_rect(Rect2(x + 2, y, 1, 1), dark)
			draw_rect(Rect2(x + 3, y + 1, 2, 1), dark)
		_:  # taşçık 2x1
			draw_rect(Rect2(x, y, 2, 1), light)


## Ot, bitki ve kayalar: alan içinde çok seyrek (eşik 0.04), dışarıda biraz sık (0.12/0.18/0.22). Konumlar tam piksele yuvarlanır.
func _draw_decals(w: int, d: int) -> void:
	for y in range(-MARGIN, d + MARGIN):
		for x in range(-MARGIN, w + MARGIN):
			var cell := Vector2i(x, y)
			var rng := _cell_rng(cell, 2)
			var inside := x >= 0 and x < w and y >= 0 and y < d
			var roll := rng.randf()
			var group: Array[Vector2i]
			if inside:
				if roll > 0.04:
					continue
				group = TUFTS
			elif roll < 0.12:
				group = TUFTS
			elif roll < 0.18:
				group = PLANTS
			elif roll < 0.22:
				group = ROCKS
			else:
				continue
			var row: Vector2i = group[rng.randi_range(0, group.size() - 1)]
			var col := rng.randi_range(0, row.y - 1)
			var center := (Battlefield.field_to_world(Vector2(cell)) \
					+ Vector2(rng.randf_range(-14, 14), rng.randf_range(-6, 6))).round()
			draw_texture_rect_region(_sheet, Rect2(center - Vector2(32, 40), Vector2(64, 64)),
					Rect2(col * CELL, row.x * CELL, CELL, CELL))


## Ağaçlar alanın dışında öbek öbek (2-5 ağaçlık kümeler) durur: 3x3 karoluk kaba hücrelerin bir kısmında
## küme var. Kenardan uzak tutulur (ekranda alanın önünde kalan kenarlarda daha geniş boşluk: uzun ağaçlar
## kenardaki bölükleri örtmesin) ve ordu arkasındaki sancak yeri (BannerArt, 1-2 karo dışı) boş kalır.
func _plant_trees(parent: Node2D) -> void:
	var textures := _tree_textures()
	if textures.is_empty():
		return
	var w := Battlefield.FIELD_WIDTH
	var d := Battlefield.FIELD_DEPTH
	var lo := floori(float(-MARGIN) / CLUSTER_CELL) - 1
	var hi_x := ceili(float(w + MARGIN) / CLUSTER_CELL) + 1
	var hi_y := ceili(float(d + MARGIN) / CLUSTER_CELL) + 1
	for gy in range(lo, hi_y):
		for gx in range(lo, hi_x):
			var rng := _cell_rng(Vector2i(gx, gy), 3)
			if rng.randf() > CLUSTER_CHANCE * float(_biome.density):
				continue
			var center := Vector2(gx + 0.5, gy + 0.5) * CLUSTER_CELL
			for i in rng.randi_range(2, 5):
				var spot := center + Vector2(rng.randf_range(-1.6, 1.6), rng.randf_range(-1.6, 1.6))
				var cell := Vector2i(roundi(spot.x), roundi(spot.y))
				if not tree_allowed(cell):
					continue
				var texture: Texture2D = textures[rng.randi_range(0, textures.size() - 1)]
				var tree := Sprite2D.new()
				tree.texture = texture
				tree.centered = false
				tree.offset = -_tree_base(texture)
				tree.flip_h = rng.randf() < 0.5
				tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				# Tam sayı konum: ağaç pikselleri ekran pikseliyle hizalı kalır.
				tree.position = Battlefield.field_to_world(spot).round()
				if tree.flip_h:
					tree.offset.x = -texture.get_width() - tree.offset.x
				parent.add_child(tree)
				_trees.append(tree)


## Bu karoda ağaç olabilir mi: alandan yeterince uzak, arazi sınırı içinde ve sancak yeri dışında.
static func tree_allowed(cell: Vector2i) -> bool:
	var w := Battlefield.FIELD_WIDTH
	var d := Battlefield.FIELD_DEPTH
	if cell.x < -MARGIN or cell.x >= w + MARGIN or cell.y < -MARGIN or cell.y >= d + MARGIN:
		return false
	var back := maxi(-cell.x, -cell.y)  # arka kenarlardan (ekranda yukarı) uzaklık
	var front := maxi(cell.x - (w - 1), cell.y - (d - 1))  # ön kenarlardan (ekranda aşağı) uzaklık
	var clear := 4 if front >= back else 3
	if maxi(back, front) < clear:
		return false
	# Sancak yeri: iki ordunun arkasının ortası, ilk 2 karo (sancak ve direğin üstündeki bez).
	if cell.x >= 2 and cell.x <= w - 3:
		if (cell.y >= d and cell.y <= d + 1) or (cell.y <= -1 and cell.y >= -2):
			return false
	return true


func _tree_textures() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for file in DirAccess.get_files_at(PLANT_DIR):
		if not file.ends_with(".png"):
			continue
		for prefix: String in _biome.trees:
			if file.begins_with(prefix):
				out.append(load(PLANT_DIR + file))
	return out


## Ağacın yere bastığı nokta: dolu alanın alt ortası (gölgesi kadar yukarıda). Tam sayı piksel.
static func _tree_base(texture: Texture2D) -> Vector2:
	if not _base_cache.has(texture.resource_path):
		var used := texture.get_image().get_used_rect()
		_base_cache[texture.resource_path] = Vector2(used.position.x + used.size.x / 2,
				used.end.y - roundi(used.size.y * 0.12))
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
