class_name SquadView
extends Node2D
## Bir bölüğü ekrana çizer. Simülasyondaki SquadState'i sadece okur, hiçbir şeyi değiştirmez.
## Her asker UnitSprites sayfasından bir karedir: yürürken iki kare arasında gidip gelir,
## saldırınca kısa süre saldırı karesine geçer.
##
## Üç katman: gölgeler (_under, askerlerin arkasında), askerler (bu düğüm, vuruş flaşı
## shader'ı burada), sayı etiketi (_over, üstte). Flaş sadece askerleri boyasın diye gölge ve
## etiket ayrı CanvasItem'larda: bir düğümün material'ı çocuklarına geçmez.
## Askerler 16x16 minik figürlerdir (MiniUnitArt); formasyon layout() ile sık ve düzgün dizilir.

## Bir asker düştü. at: askerin konumu (bu düğümün ebeveyninin koordinatında).
signal soldier_died(view: SquadView, at: Vector2)

## Formasyon: sütun sayısı ceil(sqrt(asker * COLUMN_FACTOR)); aralık figür genişliğinin bu oranı.
const COLUMN_FACTOR := 1.6
const SPACING_RATIO := 0.75
const MIN_SPACING_RATIO := 0.7  ## Komşu figür merkezleri ekranda en az frame_w * bu kadar uzak.
const BASE_SPAN := 1.6  ## Formasyonun yarıçapı (karo) en çok bu kadar; çok kalabalıkta 0.9 + 0.015 * n.
## Vuruş flaşı: 70 ms tam beyaz, sonra 40 ms yarı güç (gorsel_yon_dokumani.md 5.2). Kademeli
## (yumuşak geçişsiz) flaş piksel sanatta daha net okunur.
const HIT_FLASH_TIME := 0.11
const HIT_FLASH_FULL := 0.07
const HIT_FLASH_PEAK := 0.6  ## En yüksek flaş gücü: 1.0 tüm bölüğü saf beyaz yapıp takım rengini siliyordu.
const HIT_FLASH_SHADER := preload("res://assets/shaders/hit_flash.gdshader")
## Ayarlarda "Vuruş flaşı" kapalıysa flaş bu güçte ve yumuşak renkte kalır (göz yormasın).
const SOFT_FLASH := 0.35
const SOFT_FLASH_COLOR := Color("fdcbb0")  ## Resurrect 64 şeftali
const ATTACK_ANIM_TIME := 0.2  ## Saldırı karesinin ekranda kalma süresi.
const WALK_FPS := 7.0  ## Yürüme animasyonunda saniyede kare değişimi.
## Askerler aynı anda saldırmasın: üç gruba ayrılır, her grup bir öncekinden bu kadar geç vurur.
const ATTACK_STAGGER := 0.04
## Yakın dövüşte asker saldırı karesinde baktığı yöne bu kadar piksel atılır (sonra geri döner).
## Uzak saldırıda (ok, büyü) geri tepme: ters yöne RECOIL_PX. Hep tam piksel: piksel sanat kaymaz.
const LUNGE_PX := 1.0  ## Minik figürde atılma 1 px; piksel kaymasın.
const BOSS_LUNGE_PX := 3.0  ## Boss büyük çizimli: daha uzun atılır.
const RECOIL_PX := 1.0
## Boss'un eski takım diski (koyu kenarlar Resurrect 64 lacivert / bordo). Renk UnitSprites.team_color'dan:
## oyuncu altın f9c22b, rakip kırmızı e83b3b (figür gövdesiyle aynı kaynak).
const TEAM_EDGES := {
	SquadState.Team.PLAYER: Color("323353"),
	SquadState.Team.ENEMY: Color("6e2727"),
}
## Boss diskinin dolgu saydamlığı.
const SHADOW_ALPHA := 0.75
## Boss diski satırları: [dikey konum, yarı genişlik] (BOSS_SCALE ile büyür).
const DISC_ROWS := [[-1, 3], [0, 4], [1, 3]]
## Minik figürün gölgesi: figür başına 5x2 px (geniş rollerde 7x2) yarı saydam siyah.
const SHADOW_COLOR := Color(0, 0, 0, 0.35)
## Figürün baş üstü: 16x16 karede baş yaklaşık 2. satırda; sayı bunun 4 px üstüne oturur.
const HEAD_ROW := 2
const LABEL_GAP := 4
const LABEL_SIZE := 8
const COUNT_PULSE_TIME := 0.15  ## Asker kaybında sayı bu sürede büyüyüp kızarır.
const COUNT_PULSE_COLOR := Color("f68181")
## Atlı ve kuşatma figürleri geniş: gölgeleri de geniş (7x2).
const WIDE_ROLES: Array[StringName] = [&"cavalry", &"siege"]
const AURA_ALPHA := 0.12  ## Ferman aurası iç dolgusunun saydamlığı (ince leke).
const AURA_EDGE_ALPHA := 0.7  ## Aura kenar halkasının saydamlığı (1 px, kesik).
const AURA_PAD := Vector2(7, 4)  ## Aura, formasyonun dışına bu kadar taşar (yarıçap, piksel).
const BOSS_AURA_RADIUS := Vector2(20, 9)

var squad: SquadState
var sheet: UnitSprites.Sheet
var flip := false  ## Sola bakıyor mu (sprite yatay çevrilir).
## Fermanın uygulandığı bölüğün altında çizilen aura rengi (krallık rengi). Alfa 0 = aura yok.
## Çizim alfası sabit AURA_ALPHA; değer atanınca gölge katmanı yeniden çizilir.
var aura_color := Color(0, 0, 0, 0):
	set(value):
		aura_color = value
		_under.queue_redraw()

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
var _over := Node2D.new()  ## Sayı etiketi, boss can çubuğu: askerlerin üstünde, flaşsız.
var _settings: Node
## Gölge ve etiket katmanları sadece içerikleri değişince yeniden çizilir (performans):
## konum değişimi için yeniden çizim gerekmez, düğümün dönüşümü kaydırır.
var _under_key := Vector3.ZERO  ## (yön x, yön y, asker sayısı)
var _over_key := Vector3(-1, 0, 0)  ## (yön x, yön y, asker sayısı ya da boss canı)
var _count_pulse := 0.0  ## Asker kaybında sayı etiketinin sönen vurgusu.
var _last_count := -1


func setup(p_squad: SquadState) -> void:
	squad = p_squad
	sheet = UnitSprites.sheet_for(squad.unit, squad.team)
	_attack_time = ATTACK_ANIM_TIME * 2.0
	_material.shader = HIT_FLASH_SHADER
	_under.show_behind_parent = true
	_under.draw.connect(_draw_under)
	_over.draw.connect(_draw_over)
	add_child(_under)
	add_child(_over)
	_slots = layout(squad.max_count, sheet.frame_size.x)
	for i in squad.max_count:
		_alive_slots.append(i)
	update_visual(1.0, 0.0)


## Askerlerin formasyon yerleri (karo cinsinden: x yana, y geriye), bölüğün merkezine göre.
## Godot: izometrik dönüşümde (field_offset_to_world) kareler eşit görünmez: karo çaprazı ekranda
## en kısa yöndür. Bu yüzden aralık, ızgaranın en yakın komşu yönüne göre (4 yön) hesaplanır ve
## komşu merkezler ekranda hep en az frame_w * 0.7 px ayrı kalır. Son sıra kısa kalırsa tam
## sayıda sütun kaydırılarak ortalanır: ızgara bozulmaz, komşu mesafesi korunur.
@warning_ignore("integer_division")
static func layout(count: int, frame_w: int) -> Array[Vector2]:
	var slots: Array[Vector2] = []
	if count <= 0:
		return slots
	if count == 1:
		slots.append(Vector2.ZERO)
		return slots
	var cols := ceili(sqrt(count * COLUMN_FACTOR))
	var rows := ceili(float(count) / cols)
	var spacing := frame_w * SPACING_RATIO / Battlefield.field_offset_to_world(Vector2(1, 0)).length()
	var floor_spacing := frame_w * MIN_SPACING_RATIO / _min_lattice_px() + 0.0005
	spacing = maxf(spacing, floor_spacing)
	var half_w := (cols - 1) / 2.0
	var half_h := (rows - 1) / 2.0
	var cap := maxf(BASE_SPAN, 0.9 + 0.015 * count)
	var span := Vector2(half_w, half_h).length() * spacing
	if span > cap:
		spacing = maxf(spacing * cap / span, floor_spacing)
	var last := count - (rows - 1) * cols  # son sıradaki asker sayısı
	var shift := (cols - last) / 2  # tam sütun kayması
	for i in count:
		var col := i % cols
		var row := i / cols
		if row == rows - 1:
			col += shift
		slots.append(Vector2((col - half_w) * spacing, (row - half_h) * spacing))
	return slots


## Birim aralıklı ızgarada en yakın komşu mesafesi (ekran pikseli): (1,0), (0,1), (1,1), (1,-1) yönleri.
static func _min_lattice_px() -> float:
	var best := INF
	for d in [Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, -1)]:
		best = minf(best, Battlefield.field_offset_to_world(d).length())
	return best


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
	var count := squad.alive_count()
	if count < _last_count:
		_count_pulse = COUNT_PULSE_TIME
	_last_count = count
	var pulsing := _count_pulse > 0.0
	_count_pulse = maxf(_count_pulse - delta, 0.0)
	var over_value := roundi(squad.hp_pool / squad.max_hp * 100.0) if squad.unit.is_boss else count
	var over_key := Vector3(squad.facing.x, squad.facing.y, over_value)  # yön: üst figür değişebilir
	if over_key != _over_key or pulsing:
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
	var amount := HIT_FLASH_PEAK if HIT_FLASH_TIME - _flash < HIT_FLASH_FULL else HIT_FLASH_PEAK * 0.5
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
	if aura_color.a > 0.0:
		_draw_aura()
	if squad.unit.is_boss:
		_draw_shadow(Vector2.ZERO)
		return
	for slot in _alive_slots:
		_draw_shadow(_offsets[slot])


## Ferman aurası: formasyonu saran ince elips. İçi çok saydam dolgu (alfa AURA_ALPHA), kenarı krallık
## renginde 1 px kesik halka (her üç pikselden biri boş). Satır satır tam sayı piksel, alt-piksel yok.
## Merkez ve yarıçap yaşayan askerlerin konumlarından hesaplanır; asker sayısı değişince _under_key
## değiştiği için aura da küçülür. Gölgenin altında kalır.
func _draw_aura() -> void:
	var lo := Vector2.ZERO
	var hi := Vector2.ZERO
	var radius := BOSS_AURA_RADIUS
	if not squad.unit.is_boss:
		if _alive_slots.is_empty():
			return
		lo = Vector2(INF, INF)
		hi = Vector2(-INF, -INF)
		for slot in _alive_slots:
			lo = lo.min(_offsets[slot])
			hi = hi.max(_offsets[slot])
		radius = ((hi - lo) / 2.0 + AURA_PAD).round()
	var center := ((lo + hi) / 2.0).round()
	var fill := Color(aura_color, AURA_ALPHA)
	var edge := Color(aura_color, AURA_EDGE_ALPHA)
	var ry := int(radius.y)
	var halves: Array[int] = []
	for dy in range(-ry, ry + 1):
		halves.append(roundi(radius.x * sqrt(maxf(1.0 - float(dy * dy) / (radius.y * radius.y), 0.0))))
	for i in halves.size():
		var dy := i - ry
		var half := halves[i]
		# kenar: dışa komşu satırın bitişinden ötesi (üst/alt satırda tamamı), ortada sadece uçlar
		var outer := -1  # üst/alt satırın dışında komşu yok: tamamı kenar
		if dy == 0:
			outer = half
		elif dy < 0 and i > 0:
			outer = halves[i - 1]
		elif dy > 0 and i < halves.size() - 1:
			outer = halves[i + 1]
		var inner := mini(outer + 1, half)  # |x| >= inner kenar
		if inner > 0:
			_under.draw_rect(Rect2(center + Vector2(-(inner - 1), dy), Vector2(inner * 2 - 1, 1)), fill)
		for x in range(inner, half + 1):
			if posmod(x + dy, 3) == 0:
				continue  # kesik halka
			_under.draw_rect(Rect2(center + Vector2(x, dy), Vector2(1, 1)), edge)
			if x > 0:
				_under.draw_rect(Rect2(center + Vector2(-x, dy), Vector2(1, 1)), edge)


## Bölüğe uygulanan ilk fermanın krallık rengi (aura için); ferman yoksa alfa 0.
## Sadece rol ya da saf (ön/arka) şartlı fermanlar aura verir: "tüm bölükler" fermanı herkese
## uygulandığı için aura ayırt edici olmaz, gösterilmez. Oyuncu bölükleri için RunState.passives,
## boss savaşında rakip için RunState.enemy_passives().
static func aura_color_for(army_squad: ArmySquad, passives: Array[PassiveData]) -> Color:
	for passive in passives:
		if passive.roles.is_empty() and passive.row == PassiveData.Row.ANY:
			continue
		if passive.applies_to(army_squad):
			var kingdom := KingdomCatalog.get_kingdom(passive.kingdom)
			if kingdom:
				return Color(kingdom.color, 1.0)
	return Color(0, 0, 0, 0)


## Sayı etiketi ve boss çubuğu (_over düğümünün draw sinyali): flaştan etkilenmez.
func _draw_over() -> void:
	if squad.unit.is_boss:
		_draw_boss_bar()
	else:
		_draw_count_label()


## Ayağın altında gölge. Minik figür: 5x2 px (geniş rollerde 7x2) yarı saydam siyah.
## Boss: eski takım diski (üç satır piksel, BOSS_SCALE kat büyük). _under düğümüne çizilir.
## Yatay çevirmede 16 px'lik karenin ortası bir piksel sola kayar: gölge de kayar, figürün altında kalır.
func _draw_shadow(at: Vector2) -> void:
	if not squad.unit.is_boss:
		var wide := WIDE_ROLES.has(squad.unit.role)
		var half := 3 if wide else 2
		var x := at.x - half - (1.0 if flip else 0.0)
		_under.draw_rect(Rect2(Vector2(x, at.y - 1.0), Vector2(half * 2 + 1, 2)), SHADOW_COLOR)
		return
	var px := UnitSprites.BOSS_SCALE  # boss diski 3 kat iri piksel
	var fill := UnitSprites.team_color(squad.team)
	fill.a = SHADOW_ALPHA
	var edge: Color = TEAM_EDGES[squad.team]
	edge.a = 0.9
	for i in DISC_ROWS.size():
		var y: int = DISC_ROWS[i][0] * px
		var half: int = DISC_ROWS[i][1] * px
		var width := half * 2 + px
		if i == DISC_ROWS.size() - 1:  # alt satır tamamen kenar
			_under.draw_rect(Rect2(at + Vector2(-half, y), Vector2(width, px)), edge)
			continue
		_under.draw_rect(Rect2(at + Vector2(-half + px, y), Vector2(width - px * 2, px)), fill)
		_under.draw_rect(Rect2(at + Vector2(-half, y), Vector2(px, px)), edge)
		_under.draw_rect(Rect2(at + Vector2(half, y), Vector2(px, px)), edge)


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
			push = k * (BOSS_LUNGE_PX if squad.unit.is_boss else LUNGE_PX)
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
	var boss := squad.unit.is_boss
	if squad.burn_time > 0.0:  # yanan bölüğün askerlerinin başında kıvılcım
		var spark := int(_anim_time * 10.0 + slot) % 2
		if boss:
			var top := at + Vector2(-2, 1.0 - size.y)
			draw_rect(Rect2(top + Vector2(spark, -2), Vector2(2, 2)), Color("ff9a30"))
			draw_rect(Rect2(top + Vector2(spark + 1, -3), Vector2(1, 1)), Color("ffe080"))
		else:  # minik figür: 1 px'lik kıvılcım başın üstünde
			var head := at + Vector2(-1 if flip else 0, 1.0 - size.y + HEAD_ROW)
			draw_rect(Rect2(head + Vector2(spark - 1, -2), Vector2(1, 2)), Color("ff9a30"))
			draw_rect(Rect2(head + Vector2(spark, -3), Vector2(1, 1)), Color("ffe080"))
	elif squad.slow_time > 0.0:  # yavaşlatılmış bölük: ayakta çamur
		if boss:
			draw_rect(Rect2(at + Vector2(-3, -1), Vector2(6, 2)), Color("6a5a2a"))
		else:
			draw_rect(Rect2(at + Vector2(-2, -1), Vector2(4, 1)), Color("6a5a2a"))


## Boss tek asker olduğu için sayı yerine can çubuğu ve adı.
func _draw_boss_bar() -> void:
	var top := 1.0 - sheet.frame_size.y
	var ratio := clampf(squad.hp_pool / squad.max_hp, 0.0, 1.0)
	var bar := Rect2(Vector2(-14, top - 5), Vector2(28, 3))
	_over.draw_rect(bar, Color(0, 0, 0, 0.6))
	_over.draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), UnitSprites.team_color(squad.team))
	var name_at := Vector2(-50, top - 8)
	var font := UiKit.ui_font(800)
	_over.draw_string_outline(font, name_at, tr(squad.unit.display_name),
			HORIZONTAL_ALIGNMENT_CENTER, 100, 8, 3, Color(0, 0, 0, 0.85))
	_over.draw_string(font, name_at, tr(squad.unit.display_name),
			HORIZONTAL_ALIGNMENT_CENTER, 100, 8, UiKit.COLOR_GOLD)


## Bölüğün en üst figürünün 4 px üstünde takım renginde küçük asker sayısı (1 px koyu gölgeli).
## Renk körlüğü için sayı zaten ayırt edici; renk ek ipucu. Asker kaybında sayı bir an 1.3 kat
## büyür ve kızarır (ölçek sayının ortasından). Seviye: sayının yanında küçük altın noktalar.
## Godot: draw_set_transform ölçek + konum verir; yazı bunun içinde çizilince büyüme yerinde kalır.
func _draw_count_label() -> void:
	var font := UiKit.ui_font(800)
	var top := 0.0  # en üst figürün baş satırı (bu düğüme göre)
	var first := true
	for slot in _alive_slots:
		var y: float = _offsets[slot].y + 1.0 - sheet.frame_size.y + HEAD_ROW
		top = y if first else minf(top, y)
		first = false
	if first:
		return
	var count := str(squad.alive_count())
	var pulse := _count_pulse / COUNT_PULSE_TIME
	var team_color := UnitSprites.team_color(squad.team)
	var color := team_color.lerp(COUNT_PULSE_COLOR, pulse)
	var width := 24.0
	var center := Vector2(0, top - LABEL_GAP - LABEL_SIZE * 0.5)
	_over.draw_set_transform(center.round(), 0.0, Vector2.ONE * (1.0 + 0.3 * pulse))
	var at := Vector2(-width / 2.0, LABEL_SIZE * 0.5 - 1.0)
	_over.draw_string(font, at + Vector2(0, 1), count, HORIZONTAL_ALIGNMENT_CENTER, width, LABEL_SIZE, Color(0, 0, 0, 0.85))
	_over.draw_string(font, at, count, HORIZONTAL_ALIGNMENT_CENTER, width, LABEL_SIZE, color)
	_over.draw_set_transform(Vector2.ZERO)
	for i in squad.level - 1:  # seviye noktaları sayının sağında
		_over.draw_rect(Rect2(center + Vector2(width * 0.5 - 4 + i * 2, -LABEL_SIZE * 0.5), Vector2(1, 1)), UiKit.COLOR_GOLD)
