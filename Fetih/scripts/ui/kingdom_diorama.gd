class_name KingdomDiorama
extends Control
## Krallık seçimindeki canlı sahne: krallığın diyarından küçük bir izometrik yer parçası, o krallığın
## manzara süsleri (TerrainProps), arkada sancağı ve başlangıç birliklerinden figürler (bekler, ara ara
## yürür gibi kıpırdar). Krallık değişince eski sahne yana kayarak çıkar, yenisi gelir.
## Kilitli krallıkta figürler siyah silüet. Sadece görüntü.
## Godot: clip_contents kayan sahneyi kutunun içinde kırpar; her sahne kendi _draw'ını yapar.

const SLIDE_TIME := 0.35

var _scene: Control


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Yeni krallığı gösterir. direction: 1 sağa geçiş (yeni sahne sağdan gelir), -1 sola, 0 animasyonsuz.
func show_kingdom(kingdom: KingdomData, unlocked: bool, direction := 0) -> void:
	var old := _scene
	_scene = _DioramaScene.new(kingdom, unlocked)
	_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_scene)
	if old == null or direction == 0:
		if old:
			old.queue_free()
		return
	var w := size.x
	_scene.position.x = w * direction
	var t := SLIDE_TIME * UiKit.anim_scale()
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_scene, "position:x", 0.0, t)
	tw.tween_property(old, "position:x", -w * direction, t)
	tw.chain().tween_callback(old.queue_free)


func current_kingdom() -> KingdomData:
	return _scene.kingdom if _scene else null


class _DioramaScene:
	extends Control

	const SCALE := 2.0  ## Piksel sanat büyütmesi (düzen pikseli başına).
	var kingdom: KingdomData
	var unlocked: bool
	var _time := 0.0
	var _ramp: Array
	var _props: Array[Array] = []  ## [doku, konum]
	var _figures: Array[Array] = []  ## [Sheet, konum, evre]
	var _built_size := Vector2.ZERO

	func _init(p_kingdom: KingdomData, p_unlocked: bool) -> void:
		kingdom = p_kingdom
		unlocked = p_unlocked
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var biome: Dictionary = GroundArt.BIOMES.get(kingdom.id, GroundArt.BIOMES[&"default"])
		_ramp = biome.ramp

	func _process(delta: float) -> void:
		_time += delta
		if size != _built_size:
			_layout()
		queue_redraw()

	## Süs ve figür konumları kutunun boyutuna göre (seed: krallık id).
	func _layout() -> void:
		_built_size = size
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(kingdom.id))
		var c := _center()
		var half := _half()
		_props.clear()
		var kinds := GroundArt.props_of(kingdom.id)
		# Sancak arkada ortada (0, -0.45): süsler onun çevresini boş bırakır.
		var spots := [Vector2(-0.78, -0.1), Vector2(0.8, -0.05), Vector2(-0.48, -0.5), Vector2(0.55, -0.42),
				Vector2(-0.2, 0.62), Vector2(0.62, 0.42)]
		for i in spots.size():
			if kinds.is_empty():
				break
			var kind: StringName = kinds[i % kinds.size()]
			var tex := TerrainProps.texture(kind, rng.randi_range(0, TerrainProps.VARIANTS - 1))
			_props.append([tex, c + Vector2(spots[i].x * half.x, spots[i].y * half.y), TerrainProps.KINDS[kind].flat])
		_figures.clear()
		var units := kingdom.starting_units
		var count := 10
		for i in count:
			if units.is_empty():
				break
			var unit: UnitData = units[i % units.size()]
			var sheet := UnitSprites.sheet_for(unit, SquadState.Team.PLAYER)
			var col := i / 2
			var row := i % 2
			var block := 0 if i % units.size() == 0 else 1
			var at := c + Vector2(-46 + col * 18 + row * 9 + block * 4, -4 + row * 12 + block * 2)
			_figures.append([sheet, at, rng.randf() * TAU])
		_figures.sort_custom(func(a: Array, b: Array) -> bool: return a[1].y < b[1].y)

	func _center() -> Vector2:
		return Vector2(size.x / 2.0, size.y * 0.58)

	func _half() -> Vector2:
		return Vector2(minf(size.x * 0.46, 170.0), minf(size.y * 0.36, 80.0))

	func _draw() -> void:
		if size.x <= 0.0:
			return
		var top := Color(_ramp[0]).darkened(0.35)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
				PackedColorArray([top, top, Color(_ramp[0]), Color(_ramp[0])]))
		var c := _center()
		var half := _half()
		var diamond := PackedVector2Array([c + Vector2(0, -half.y), c + Vector2(half.x, 0), c + Vector2(0, half.y),
				c + Vector2(-half.x, 0)])
		draw_colored_polygon(diamond + PackedVector2Array(), Color(_ramp[1]))
		var rim := diamond.duplicate()
		rim.append(diamond[0])
		draw_polyline(rim, Color(_ramp[2], 0.8), 1.5)
		var edge := PackedVector2Array([c + Vector2(-half.x, 0), c + Vector2(0, half.y), c + Vector2(half.x, 0),
				c + Vector2(half.x, 8), c + Vector2(0, half.y + 8), c + Vector2(-half.x, 8)])
		draw_colored_polygon(edge, Color(_ramp[0]).darkened(0.2))  # yer parçasının kalınlığı
		for p: Array in _props:  # düz süsler (gölcük, lav) önce
			if p[2]:
				_draw_scaled(p[0], p[1])
		var frame := int(_time * 4.0) % BannerArt.FRAMES
		_draw_scaled(BannerArt.texture(kingdom, frame), c + Vector2(0, -half.y * 0.45), Vector2(BannerArt.ANCHOR))
		for p: Array in _props:
			if not p[2] and p[1].y < c.y:
				_draw_scaled(p[0], p[1])
		for f: Array in _figures:
			_draw_figure(f[0], f[1], f[2])
		for p: Array in _props:
			if not p[2] and p[1].y >= c.y:
				_draw_scaled(p[0], p[1])
		if not unlocked:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.08, 0.35))

	## Doku alt ortası (ya da anchor) verilen noktaya, SCALE kat büyük.
	func _draw_scaled(tex: Texture2D, at: Vector2, anchor := Vector2(-1, -1)) -> void:
		var a := anchor if anchor.x >= 0.0 else Vector2(tex.get_width() / 2.0, tex.get_height())
		draw_texture_rect(tex, Rect2((at - a * SCALE).round(), tex.get_size() * SCALE), false)

	## Figür: durma karelerini döndürür; ara ara 2 px zıplar gibi kıpırdar (evre farklı).
	func _draw_figure(sheet: UnitSprites.Sheet, at: Vector2, phase: float) -> void:
		var anim := UnitSprites.Anim.IDLE
		var walking := sin(_time * 0.9 + phase) > 0.75
		if walking:
			anim = UnitSprites.Anim.WALK
		var frame := int(_time * (8.0 if walking else 3.0) + phase * 3.0) % sheet.count(anim)
		var region := sheet.region(anim, frame)
		var dst := Rect2((at - Vector2(region.size.x / 2.0, region.size.y) * SCALE).round(), region.size * SCALE)
		draw_ellipse_shadow(at)
		var tint := Color.WHITE if unlocked else Color(0, 0, 0, 0.85)
		draw_texture_rect_region(sheet.texture, dst, region, tint)

	func draw_ellipse_shadow(at: Vector2) -> void:
		draw_rect(Rect2(at + Vector2(-5, -2), Vector2(10, 3)), Color(0, 0, 0, 0.25))
