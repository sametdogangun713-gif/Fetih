class_name SquadView
extends Node2D
## Bir bölüğü ekrana çizer. Simülasyondaki SquadState'i sadece okur, hiçbir şeyi değiştirmez.
## Her asker UnitSprites sayfasından bir karedir: yürürken iki kare arasında gidip gelir,
## saldırınca kısa süre saldırı karesine geçer.
##
## Üç katman: gölgeler (_under, askerlerin arkasında), askerler (bu düğüm, vuruş flaşı
## shader'ı burada), sancak/sayı (_over, üstte). Flaş sadece askerleri boyasın diye gölge ve
## sancak ayrı CanvasItem'larda: bir düğümün material'ı çocuklarına geçmez.

## Bir asker düştü. at: askerin konumu (bu düğümün ebeveyninin koordinatında).
signal soldier_died(view: SquadView, at: Vector2)

const COLUMNS := 5  ## Formasyonun genişliği (asker).
const SOLDIER_SPACING := 0.24  ## Askerler arası mesafe (karo).
const HIT_FLASH_TIME := 0.14
const HIT_FLASH_SHADER := preload("res://assets/shaders/hit_flash.gdshader")
## Ayarlarda "Vuruş flaşı" kapalıysa flaş bu güçte ve yumuşak renkte kalır (göz yormasın).
const SOFT_FLASH := 0.35
const SOFT_FLASH_COLOR := Color("ffd8b0")
const ATTACK_ANIM_TIME := 0.2  ## Saldırı karesinin ekranda kalma süresi.
const WALK_FPS := 7.0  ## Yürüme animasyonunda saniyede kare değişimi.
## Askerler aynı anda saldırmasın: üç gruba ayrılır, her grup bir öncekinden bu kadar geç vurur.
const ATTACK_STAGGER := 0.04
## Yakın dövüşte asker saldırı karesinde baktığı yöne bu kadar piksel atılır (sonra geri döner).
## Uzak saldırıda (ok, büyü) geri tepme: ters yöne RECOIL_PX. Hep tam piksel: piksel sanat kaymaz.
const LUNGE_PX := 2.0
const HEAVY_LUNGE_PX := 3.0  ## Atlılar ve boss daha uzun atılır.
const RECOIL_PX := 1.0
const TEAM_COLORS := {
	SquadState.Team.PLAYER: Color("3d6fd1"),
	SquadState.Team.ENEMY: Color("c8443a"),
}
## Asker ayağındaki takım gölgesinin saydamlığı: iki ordu aynı birlikten olsa da ayırt edilsin.
const SHADOW_ALPHA := 0.7
## Atlı ve kuşatma figürleri geniş: gölgeleri de geniş.
const WIDE_ROLES: Array[StringName] = [&"cavalry", &"siege"]

var squad: SquadState
var sheet: UnitSprites.Sheet
var flip := false  ## Sola bakıyor mu (sprite yatay çevrilir).

var _slots: Array[Vector2] = []  ## Her askerin formasyondaki yeri: x = yana, y = geriye (karo).
var _alive_slots: Array[int] = []
var _offsets := {}  ## yer -> bölük merkezine göre ekran konumu (bu kare)
var _flash := 0.0
var _attack_time := 0.0  ## Son saldırıdan beri geçen süre.
var _anim_time := 0.0
var _moving := false
var _facing_dir := Vector2.RIGHT  ## Ekranda baktığı yön (birim vektör): atılma ve geri tepme yönü.
var _melee_attack := true  ## Son saldırı yakın dövüş müydü (atılma) yoksa atış mı (geri tepme).
## Sadece görsel rastgelelik (hangi askerin düşeceği). Simülasyonun sonucunu etkilemez.
var _visual_rng := RandomNumberGenerator.new()
var _material := ShaderMaterial.new()
var _under := Node2D.new()  ## Gölgeler: show_behind_parent ile askerlerin arkasında çizilir.
var _over := Node2D.new()  ## Sancak, sayı, boss can çubuğu: askerlerin üstünde, flaşsız.
var _settings: Node
## Gölge ve sancak katmanları sadece içerikleri değişince yeniden çizilir (performans):
## konum değişimi için yeniden çizim gerekmez, düğümün dönüşümü kaydırır.
var _under_key := Vector3.ZERO  ## (yön x, yön y, asker sayısı)
var _over_key := -1


func setup(p_squad: SquadState) -> void:
	squad = p_squad
	sheet = UnitSprites.sheet_for(squad.unit)
	_attack_time = ATTACK_ANIM_TIME * 2.0
	_material.shader = HIT_FLASH_SHADER
	_under.show_behind_parent = true
	_under.draw.connect(_draw_under)
	_over.draw.connect(_draw_over)
	add_child(_under)
	add_child(_over)
	var rows := ceili(float(squad.max_count) / COLUMNS)
	for i in squad.max_count:
		var col := i % COLUMNS
		var row := i / COLUMNS
		_slots.append(Vector2(
				(col - (COLUMNS - 1) / 2.0) * SOLDIER_SPACING,
				(row - (rows - 1) / 2.0) * SOLDIER_SPACING))
		_alive_slots.append(i)
	update_visual(1.0, 0.0)


## Her karede çağrılır. alpha: iki simülasyon adımı arasında nerede olduğumuz (0-1).
## delta: savaş hızıyla çarpılmış süre (x4'te animasyonlar da hızlanır).
func update_visual(alpha: float, delta: float) -> void:
	position = Battlefield.field_to_world(squad.previous_position.lerp(squad.position, alpha))
	_moving = squad.position.distance_squared_to(squad.previous_position) > 0.000001
	var world_facing := Battlefield.field_offset_to_world(squad.facing)
	if absf(world_facing.x) > 0.01:
		flip = world_facing.x < 0.0
	if world_facing.length_squared() > 0.0001:
		_facing_dir = world_facing.normalized()
	_update_offsets()
	var alive := mini(squad.alive_count(), _slots.size())
	while _alive_slots.size() > alive:
		_remove_front_soldier()
	# Onarım ve diriliş asker sayısını artırabilir: boş yerleri arkadan doldur.
	var i := _slots.size() - 1
	while _alive_slots.size() < alive and i >= 0:
		if not _alive_slots.has(i):
			_alive_slots.append(i)
		i -= 1
	_flash = maxf(_flash - delta, 0.0)
	_attack_time += delta
	_anim_time += delta
	visible = squad.is_alive()
	_update_flash()
	queue_redraw()  # askerler: animasyon kareleri her karede değişir
	var under_key := Vector3(squad.facing.x, squad.facing.y, _alive_slots.size())
	if under_key != _under_key:
		_under_key = under_key
		_under.queue_redraw()
	var over_key := roundi(squad.hp_pool / squad.max_hp * 100.0) if squad.unit.is_boss 			else squad.alive_count()
	if over_key != _over_key:
		_over_key = over_key
		_over.queue_redraw()


func flash() -> void:
	_flash = HIT_FLASH_TIME


## Shader'a flaş gücünü ver: vuruş anında tam beyaz, sonra hızla söner (ease-out).
## Shader parametresi her karede değişebilir; bölük başına ayrı material olduğu için
## bir bölüğün flaşı diğerlerini etkilemez. Flaş yokken material kaldırılır: özel shader'lı
## CanvasItem'lar toplu çizimi (batching) böler, bu yüzden sadece vuruş anında takılır.
func _update_flash() -> void:
	if _flash <= 0.0:
		material = null
		return
	material = _material
	var t := _flash / HIT_FLASH_TIME  # 1 -> 0
	var amount := t * t * (3.0 - 2.0 * t)  # smoothstep: başta ve sonda yumuşak
	if _settings == null and is_inside_tree():  # setup() ağaca eklenmeden de çağırır
		_settings = get_node_or_null(^"/root/Settings")
	if _settings and not _settings.flash_effects:
		_material.set_shader_parameter(&"flash_color", SOFT_FLASH_COLOR)
		amount *= SOFT_FLASH
	else:
		_material.set_shader_parameter(&"flash_color", Color.WHITE)
	_material.set_shader_parameter(&"flash", amount)


## Bölük saldırdı: askerler saldırı karesine geçer. melee: yakın dövüşte ileri atılır,
## atışta (ok, büyü, gülle) hafifçe geri teper.
func play_attack(melee := true) -> void:
	_attack_time = 0.0
	_melee_attack = melee


## Hayattaki bir askerin konumu (ebeveyn koordinatında). Mermiler buradan çıkar / buraya iner.
func random_soldier_position(rng: RandomNumberGenerator) -> Vector2:
	if _alive_slots.is_empty():
		return position + Vector2(0, -6)
	var slot := _alive_slots[rng.randi_range(0, _alive_slots.size() - 1)]
	return position + _offsets.get(slot, Vector2.ZERO) + Vector2(0, -sheet.frame_size.y / 2.0)


## Ekranda bölüğün üst ortası (boss için gövdenin ortası). Efektler buraya çizilir.
func center() -> Vector2:
	return position + Vector2(0, -sheet.frame_size.y / 2.0)


## Formasyonu bölüğün baktığı yöne çevir: ileri = facing, yan = ona dik.
func _update_offsets() -> void:
	var forward := squad.facing
	var side := Vector2(-forward.y, forward.x)
	for slot in _slots.size():
		var s := _slots[slot]
		_offsets[slot] = Battlefield.field_offset_to_world(side * s.x - forward * s.y).round()


## Ölen asker, en öndeki sıradan rastgele seçilir.
func _remove_front_soldier() -> void:
	var front_row := INF
	for slot in _alive_slots:
		front_row = minf(front_row, _slots[slot].y)
	var candidates: Array[int] = []
	for slot in _alive_slots:
		if is_equal_approx(_slots[slot].y, front_row):
			candidates.append(slot)
	var dead := candidates[_visual_rng.randi_range(0, candidates.size() - 1)]
	_alive_slots.erase(dead)
	soldier_died.emit(self, position + _offsets.get(dead, Vector2.ZERO))


func _draw() -> void:
	if squad.unit.is_boss:
		_draw_soldier(Vector2.ZERO, 0)
		return
	# Ekranda yukarıda olan asker önce çizilir (bölük içi derinlik sıralaması).
	var order := _alive_slots.duplicate()
	order.sort_custom(func(a: int, b: int) -> bool: return _offsets[a].y < _offsets[b].y)
	for slot: int in order:
		_draw_soldier(_offsets[slot], slot)


## Gölgeler (_under düğümünün draw sinyali): askerlerin hep altında kalır.
func _draw_under() -> void:
	if squad.unit.is_boss:
		_draw_shadow(Vector2.ZERO)
		return
	for slot in _alive_slots:
		_draw_shadow(_offsets[slot])


## Sancak ve sayı (_over düğümünün draw sinyali): flaştan etkilenmez.
func _draw_over() -> void:
	if squad.unit.is_boss:
		_draw_boss_bar()
	else:
		_draw_banner()


## Ayağın altında takım renginde yassı oval (üç satır piksel). Boss'unki BOSS_SCALE kat büyük.
## _under düğümüne çizilir (bkz. _draw_under).
func _draw_shadow(at: Vector2) -> void:
	var half := 5 if WIDE_ROLES.has(squad.unit.role) else 3
	var px := UnitSprites.BOSS_SCALE if squad.unit.is_boss else 1
	half *= px
	var color: Color = TEAM_COLORS[squad.team].darkened(0.15)
	color.a = SHADOW_ALPHA
	_under.draw_rect(Rect2(at + Vector2(-half, -px), Vector2(half * 2, px)), color)
	_under.draw_rect(Rect2(at + Vector2(-half - px, 0), Vector2((half + px) * 2, px)), color)
	_under.draw_rect(Rect2(at + Vector2(-half, px), Vector2(half * 2, px)), color)


## Askerin karesi: saldırı > yürüme > durma. Ayak ortası `at` noktasına oturur.
func _draw_soldier(at: Vector2, slot: int) -> void:
	var anim := UnitSprites.Anim.IDLE
	# Her asker farklı evrede: hepsi aynı anda adım atmasın.
	var frame := int(_anim_time * 2.0 + slot * 0.37) % sheet.count(anim)
	var since_attack := _attack_time - (slot % 3) * ATTACK_STAGGER
	var push := 0.0  # baktığı yöne kayma (piksel); eksi = geri
	if since_attack >= 0.0 and since_attack < ATTACK_ANIM_TIME:
		anim = UnitSprites.Anim.ATTACK
		frame = int(since_attack / ATTACK_ANIM_TIME * sheet.count(anim))
		# sin(0..PI): hızla öne çık, aynı yoldan geri dön. Squash-stretch yerine konum
		# kullanılır: ölçek değişse pikseller eşitsiz büyür (piksel sanat bozulur).
		var k := sin(since_attack / ATTACK_ANIM_TIME * PI)
		if _melee_attack:
			push = k * (HEAVY_LUNGE_PX if _is_heavy() else LUNGE_PX)
		else:
			push = -k * RECOIL_PX
	elif _moving:
		anim = UnitSprites.Anim.WALK
		frame = int(_anim_time * WALK_FPS + slot * 0.5) % sheet.count(anim)
	var size := Vector2(sheet.frame_size)
	var dest := Rect2(Vector2(-size.x / 2.0, 1.0 - size.y), size)
	# Yatay çevirme: çizim dönüşümü x'te -1 ölçeklenir, ayak ortası yerinde kalır (Sprite2D'nin
	# flip_h'si gibi). Negatif genişlikli Rect2 kareyi bir genişlik sağa kaydırıyordu.
	# Vurulunca bir piksel geri sarsılır (flaşla aynı anda).
	push -= _flash / HIT_FLASH_TIME * RECOIL_PX
	at += (_facing_dir * push).round()
	draw_set_transform(at, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	var source := sheet.region(anim, frame)
	draw_texture_rect_region(sheet.texture, dest, source)  # flaşı hit_flash shader'ı boyar
	draw_set_transform(Vector2.ZERO)
	var top := at + Vector2(-2, 1.0 - size.y)
	if squad.burn_time > 0.0:  # yanan bölüğün askerlerinin başında kıvılcım
		var spark := int(_anim_time * 10.0 + slot) % 2
		draw_rect(Rect2(top + Vector2(spark, -2), Vector2(2, 2)), Color("ff9a30"))
		draw_rect(Rect2(top + Vector2(spark + 1, -3), Vector2(1, 1)), Color("ffe080"))
	elif squad.slow_time > 0.0:  # yavaşlatılmış bölük: ayakta çamur
		draw_rect(Rect2(at + Vector2(-3, -1), Vector2(6, 2)), Color("6a5a2a"))


func _is_heavy() -> bool:
	return squad.unit.is_boss or squad.unit.role == RoleRules.CAVALRY


## Boss tek asker olduğu için sayı yerine can çubuğu ve adı.
func _draw_boss_bar() -> void:
	var top := 1.0 - sheet.frame_size.y
	var ratio := clampf(squad.hp_pool / squad.max_hp, 0.0, 1.0)
	var bar := Rect2(Vector2(-14, top - 5), Vector2(28, 3))
	_over.draw_rect(bar, Color(0, 0, 0, 0.6))
	_over.draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), TEAM_COLORS[squad.team])
	var name_at := Vector2(-50, top - 8)
	_over.draw_string_outline(ThemeDB.fallback_font, name_at, tr(squad.unit.display_name),
			HORIZONTAL_ALIGNMENT_CENTER, 100, 8, 3, Color(0, 0, 0, 0.85))
	_over.draw_string(ThemeDB.fallback_font, name_at, tr(squad.unit.display_name),
			HORIZONTAL_ALIGNMENT_CENTER, 100, 8, UiKit.COLOR_GOLD)


## Bölüğün üstünde takım renginde sancak ve asker sayısı.
func _draw_banner() -> void:
	var pole_top := Vector2(0, -28)
	_over.draw_line(Vector2(0, -14), pole_top, Color("3a2a1a"), 1.0)
	_over.draw_rect(Rect2(pole_top, Vector2(7, 5)), TEAM_COLORS[squad.team])
	var font := ThemeDB.fallback_font
	var at := pole_top + Vector2(-12, -2)
	var count := str(squad.alive_count())
	# Koyu kontur: sayı kalabalık askerlerin ve çimin üstünde de okunsun.
	_over.draw_string_outline(font, at, count, HORIZONTAL_ALIGNMENT_CENTER, 24, 10, 3, Color(0, 0, 0, 0.85))
	_over.draw_string(font, at, count, HORIZONTAL_ALIGNMENT_CENTER, 24, 10)
	# Seviye: sancak direğinin yanında küçük altın noktalar (Sv 2 = 1 nokta ... Sv 5 = 4 nokta).
	for i in squad.level - 1:
		_over.draw_rect(Rect2(Vector2(-4, -26 + i * 3), Vector2(2, 2)), UiKit.COLOR_GOLD)
