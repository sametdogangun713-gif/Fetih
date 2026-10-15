class_name RunMap
extends Control
## Koşu haritası: 20 savaşlık yol. Her kutu bir savaş.
## Yeşil = kazanıldı, kırmızı = kaybedildi, altın çerçeve = şu anki savaş.
## Boss savaşları altın çizgili ve büyük. Kutudaki harf rakip krallığın baş harfi.
## Üstüne gelince ayrıntı (ipucu) görünür.

const BOX := 20.0
const BOSS_BOX := 24.0
const GAP := 4.0


func _ready() -> void:
	custom_minimum_size = Vector2(_total_width(), BOSS_BOX + 2)
	tooltip_text = " "  # ipucu sisteminin _get_tooltip'i çağırması için boş olmayan bir değer


func _draw() -> void:
	var font := UiKit.pixel_font(true)
	for i in Balance.RUN_LENGTH:
		var rect := _box_rect(i)
		var opponent := RunState.opponents[i]
		var fill := opponent.color.darkened(0.6)
		if i < RunState.results.size():
			fill = UiKit.COLOR_GOOD.darkened(0.3) if RunState.results[i] else UiKit.COLOR_BAD.darkened(0.3)
		draw_rect(rect, fill)
		if Balance.is_boss_battle(i):
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), UiKit.COLOR_GOLD)
		if i == RunState.battle_index:
			draw_rect(rect.grow(1), UiKit.COLOR_GOLD, false, 2.0)
		# İki harf: İnsanlar (İn) ile İblisler (İb) karışmasın.
		var letters := tr(opponent.display_name).left(2)
		draw_string(font, Vector2(rect.position.x, rect.end.y - 6), letters,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 8, UiKit.COLOR_TEXT)
		if RunState.locked.has(opponent.id) and Balance.is_boss_battle(i):
			draw_rect(Rect2(rect.end - Vector2(5, 5), Vector2(4, 4)), UiKit.COLOR_GOLD)  # mühür fırsatı


func _get_tooltip(at_position: Vector2) -> String:
	for i in Balance.RUN_LENGTH:
		if _box_rect(i).grow(GAP / 2).has_point(at_position):
			var text := tr("Savaş %d: %s") % [i + 1, tr(RunState.opponents[i].display_name)]
			if Balance.is_final_battle(i):
				text += tr(" - BÜYÜK FETİH (boss)")
			elif Balance.is_boss_battle(i):
				text += tr(" - BOSS")
			if Balance.is_boss_battle(i) and RunState.locked.has(RunState.opponents[i].id):
				text += tr(" - kilitli krallık: yenersen mühür")
			if i < RunState.results.size():
				text += tr(" - kazanıldı") if RunState.results[i] else tr(" - kaybedildi")
			return text
	return ""


func _box_rect(i: int) -> Rect2:
	var x := 0.0
	for j in i:
		x += _size_of(j) + GAP
	var s := _size_of(i)
	return Rect2(x, (BOSS_BOX - s) / 2.0 + 1, s, s)


func _size_of(i: int) -> float:
	return BOSS_BOX if Balance.is_boss_battle(i) else BOX


func _total_width() -> float:
	var width := 0.0
	for i in Balance.RUN_LENGTH:
		width += _size_of(i) + GAP
	return width
