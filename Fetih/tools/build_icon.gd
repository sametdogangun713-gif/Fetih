extends SceneTree
## Geçici uygulama ikonunu koddan çizer: koyu kırmızı kalkan, çapraz kılıçlar, altın taç.
## Gerçek ikon çizilince res://icon.png ve res://icon.ico onunla değiştirilir.
##
##   godot --headless --path Fetih -s res://tools/build_icon.gd
##   uvx --with pillow python -c "from PIL import Image; Image.open('Fetih/icon.png').save('Fetih/icon.ico', sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])"
##   godot --headless --path Fetih --import
## (Windows .ico dosyasını Godot yazamaz; Pillow ile PNG'den çevrilir.)

const SIZE := 32  ## Piksel sanat boyutu; 8 kat büyütülüp 256x256 kaydedilir.
const SCALE := 8
const OUTLINE := Color("1c1612")
const SHIELD := Color("8a2230")
const SHIELD_LIGHT := Color("b03a44")
const STEEL := Color("d8dce4")
const STEEL_DARK := Color("8a8e99")
const HILT := Color("7a5636")
const GOLD := Color("e8c25a")
const GOLD_DARK := Color("b08a30")
const RUBY := Color("c0303a")


func _initialize() -> void:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_shield(img)
	_sword(img, false)
	_sword(img, true)
	_crown(img)
	_outline(img)
	img.resize(SIZE * SCALE, SIZE * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path("res://icon.png"))
	print("kaydedildi: res://icon.png")
	quit()


## Üstü düz, altı sivri kalkan.
func _shield(img: Image) -> void:
	for y in range(8, 30):
		var half := 11 if y < 20 else 11 - (y - 19)
		for x in range(16 - half, 16 + half):
			img.set_pixel(x, y, SHIELD_LIGHT if x < 16 and y < 18 else SHIELD)


## Kalkanın önünde çapraz kılıç (sol alttan sağ üste ya da tersi).
func _sword(img: Image, mirrored: bool) -> void:
	for i in 17:
		var x := 7 + i
		var y := 27 - i
		if mirrored:
			x = 31 - x
		_px(img, x, y, STEEL)
		_px(img, x + (-1 if mirrored else 1), y, STEEL_DARK)
	# kabza ve balçak
	var hx := 8 if not mirrored else 23
	_px(img, hx - 1, 27, HILT)
	_px(img, hx - 2, 28, HILT)
	_px(img, hx - 3, 29, GOLD)
	for d in [-2, -1, 0, 1, 2]:
		_px(img, hx + 1 + d, 25 + d * (1 if mirrored else -1), GOLD_DARK)


func _crown(img: Image) -> void:
	for x in range(9, 23):
		for y in range(5, 9):
			img.set_pixel(x, y, GOLD if y < 7 else GOLD_DARK)
	for x in [9, 15, 16, 22]:  # dişler
		for y in range(1, 5):
			img.set_pixel(x, y, GOLD)
	for x in [12, 19]:
		for y in range(3, 5):
			img.set_pixel(x, y, GOLD)
	img.set_pixel(15, 6, RUBY)
	img.set_pixel(16, 6, RUBY)
	img.set_pixel(11, 6, RUBY)
	img.set_pixel(20, 6, RUBY)


func _outline(img: Image) -> void:
	var source := img.duplicate() as Image
	for y in SIZE:
		for x in SIZE:
			if source.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < SIZE and n.y < SIZE and source.get_pixelv(n).a > 0.0:
					img.set_pixel(x, y, OUTLINE)
					break


func _px(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
		img.set_pixel(x, y, color)
