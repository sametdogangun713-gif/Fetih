class_name KingdomCamp
extends RefCounted
## Bir ordunun arkasındaki krallık kampı ve kalesi (sadece görüntü; simülasyona ve kamera sınırına etkisi yok).
## 5-7 yapı alanın arka kenarının dışında x boyunca dizilir, imza yapı ortada. Oyuncu ordusunun
## arkası ekranda sağ altta (y = FIELD_DEPTH+1..+3), rakibin arkası ayna (sol üst, y = -2..-4).
## Yapılar y-sort'lu Units düğümüne Sprite2D olarak eklenir; ateş ve imza yapının parlak kısmı
## gövdenin çocuğu ayrı Sprite2D'dir ve yavaşça "nefes alır" (Tween ile modulate:a).
## Yerleşim hash(kingdom.id) ile sabittir; konumlar tam piksele yuvarlanır.

const POOL: Array[StringName] = [&"fire", &"banner", &"tower", &"tent", &"wall", &"tower"]
const PULSE_LOW := 0.7
const PULSE_TIME := 0.6  ## Bir yön (0.7 -> 1.0); tam döngü 1.2 sn.

static var _textures := {}  ## "tür|ana|vurgu" -> Texture2D


## Kampı kurar ve gövde Sprite2D'lerini döndürür (parlayan çocuklar bunların altındadır).
static func build(parent: Node2D, kingdom: KingdomData, team: SquadState.Team) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kingdom.id)
	var kinds := _kinds(rng, kingdom.id)
	var width := Battlefield.FIELD_WIDTH
	var depth := Battlefield.FIELD_DEPTH
	var count := kinds.size()
	var mirror := team != SquadState.Team.PLAYER
	for i in count:
		var kind := kinds[i]
		var is_sig := kind.begins_with("signature_")
		# x: alan genişliği boyunca eşit aralık + küçük sapma; imza ortada.
		var x := lerpf(0.4, width - 1.4, float(i) / (count - 1)) + rng.randf_range(-0.25, 0.25)
		var behind := 2.0 if is_sig else float(rng.randi_range(1, 3))
		if kind == &"wall":
			behind = 3.0
		var field := Vector2(x, depth - 1.0 + behind)
		if mirror:  # rakip: noktaya göre ayna
			field = Vector2(width - 1.0 - field.x, depth - 1.0 - field.y)
		out.append(_add_piece(parent, kind, kingdom, field, rng))
	return out


## Yapı türleri soldan sağa: imza ortada, kalan türler sabit karışımdan (ateş ve sancak hep var).
static func _kinds(rng: RandomNumberGenerator, kingdom_id: StringName) -> Array[StringName]:
	var count := rng.randi_range(5, 7)
	var rest: Array[StringName] = POOL.slice(0, count - 1)
	for i in range(rest.size() - 1, 0, -1):  # Fisher-Yates, aynı rng: deterministik
		var j := rng.randi_range(0, i)
		var tmp := rest[i]
		rest[i] = rest[j]
		rest[j] = tmp
	var out: Array[StringName] = []
	@warning_ignore("integer_division")
	var mid := count / 2
	var r := 0
	for i in count:
		if i == mid:
			out.append(StringName("signature_%s" % kingdom_id))
		else:
			out.append(rest[r])
			r += 1
	return out


static func _add_piece(parent: Node2D, kind: StringName, kingdom: KingdomData,
		field: Vector2, rng: RandomNumberGenerator) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = _texture(kind, kingdom, false)
	sprite.offset = -Vector2(BuildingArt.ANCHOR)
	sprite.position = Battlefield.field_to_world(field).round()
	parent.add_child(sprite)
	if BuildingArt.has_glow(kind):
		var lit := Sprite2D.new()
		lit.centered = false
		lit.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		lit.texture = _texture(kind, kingdom, true)
		lit.offset = sprite.offset
		lit.modulate.a = rng.randf_range(PULSE_LOW, 1.0)  # her yapı farklı evrede
		sprite.add_child(lit)
		var tween := lit.create_tween().set_loops()
		tween.tween_property(lit, "modulate:a", PULSE_LOW, PULSE_TIME).set_trans(Tween.TRANS_SINE)
		tween.tween_property(lit, "modulate:a", 1.0, PULSE_TIME).set_trans(Tween.TRANS_SINE)
	return sprite


static func _texture(kind: StringName, kingdom: KingdomData, glow: bool) -> Texture2D:
	var key := "%s|%s|%s|%s" % [kind, kingdom.color.to_html(), kingdom.accent_color.to_html(), glow]
	if not _textures.has(key):
		var img := BuildingArt.glow(kind, kingdom.color, kingdom.accent_color) if glow \
				else BuildingArt.piece(kind, kingdom.color, kingdom.accent_color, false)
		_textures[key] = ImageTexture.create_from_image(img)
	return _textures[key]
