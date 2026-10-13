extends SceneTree
## Geçici (placeholder) izometrik karoları ve TileSet'i üretir.
## Gerçek çizimler gelene kadar kullanılır.
##
## Çalıştırma (iki adım; PNG önce Godot'a içe aktarılmalı):
##   godot --headless --path Fetih -s res://tools/build_placeholder_tiles.gd
##   godot --headless --path Fetih --import
##   godot --headless --path Fetih -s res://tools/build_placeholder_tiles.gd

const TILE_W := 64
const TILE_H := 32
const PNG_PATH := "res://assets/tiles/iso_placeholder.png"
const TILESET_PATH := "res://assets/tiles/battlefield_tileset.tres"

# Atlas sırası: battlefield.gd içindeki TILE_* sabitleriyle aynı olmalı.
const FILL_COLORS: Array[Color] = [
	Color("5a8f3c"),  # 0: çimen A
	Color("528536"),  # 1: çimen B (dama deseni için)
	Color("4a7d78"),  # 2: oyuncu yerleşim bölgesi (mavimsi)
	Color("85604a"),  # 3: düşman yerleşim bölgesi (kırmızımsı)
	Color(1, 1, 1, 0.18),  # 4: fare imleci (yarı saydam)
]
const HIGHLIGHT_INDEX := 4


func _init() -> void:
	var image := _draw_atlas()
	image.save_png(ProjectSettings.globalize_path(PNG_PATH))
	print("PNG kaydedildi: ", PNG_PATH)

	if ResourceLoader.exists(PNG_PATH):
		_build_tileset()
	else:
		print("PNG henüz içe aktarılmadı. '--import' çalıştırıp bu scripti tekrar çalıştır.")
	quit()


func _draw_atlas() -> Image:
	var image := Image.create_empty(TILE_W * FILL_COLORS.size(), TILE_H, false, Image.FORMAT_RGBA8)
	for i in FILL_COLORS.size():
		var fill := FILL_COLORS[i]
		var edge := Color(1, 0.9, 0.4) if i == HIGHLIGHT_INDEX else fill.darkened(0.25)
		for py in TILE_H:
			for px in TILE_W:
				# Piksel merkezinin baklavanın merkezine "baklava uzaklığı": 1'den küçükse içeride.
				var d: float = absf(px + 0.5 - TILE_W / 2.0) / (TILE_W / 2.0) \
						+ absf(py + 0.5 - TILE_H / 2.0) / (TILE_H / 2.0)
				if d > 1.0:
					continue
				var color := edge if d > 0.93 else fill
				image.set_pixel(i * TILE_W + px, py, color)
	return image


func _build_tileset() -> void:
	var source := TileSetAtlasSource.new()
	source.texture = load(PNG_PATH)
	source.texture_region_size = Vector2i(TILE_W, TILE_H)
	for i in FILL_COLORS.size():
		source.create_tile(Vector2i(i, 0))

	var tileset := TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tileset.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tileset.tile_size = Vector2i(TILE_W, TILE_H)
	tileset.add_source(source, 0)

	var err := ResourceSaver.save(tileset, TILESET_PATH)
	print("TileSet kaydedildi: ", TILESET_PATH, " (hata kodu: ", err, ")")
