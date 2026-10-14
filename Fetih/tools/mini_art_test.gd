extends SceneTree
## Minik birlik sanatı kontrolü (GR4): boyut, figür ölçüsü, palet, takım rengi, önbellek.
## Çalıştırma: godot --headless --path Fetih -s res://tools/mini_art_test.gd

var failures := 0


func check(name: String, ok: bool) -> void:
	if not ok:
		failures += 1
		print("HATA: ", name)


func _init() -> void:
	var gold := UnitSprites.TEAM_PLAYER
	var red := UnitSprites.TEAM_ENEMY
	var seen_roles := {}
	for unit: UnitData in UnitCatalog.all():
		if unit.is_boss:
			continue
		seen_roles[unit.role] = true
		var img := MiniUnitArt.sheet(unit, gold)
		check("%s boyut" % unit.id, img.get_height() == MiniUnitArt.CELL * 4)
		var used := img.get_region(Rect2i(0, 0, 16, 16)).get_used_rect()
		check("%s figür 8-13 px (%d) ve <=14 geniş (%d)" % [unit.id, used.size.y, used.size.x],
				used.size.y >= 8 and used.size.y <= 13 and used.size.x <= 14)
		check("%s ayak alt çizgide" % unit.id, used.end.y == MiniUnitArt.FOOT.y + 1)
		var bad := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0 and (c.a < 1.0 or SpritePalette.nearest(c) != Color(c, 1.0)):
					bad += 1
		check("%s palet (%d dışı)" % [unit.id, bad], bad == 0)
		# her animasyon satırında beklenen kare sayısı dolu, ötesi boş
		for anim in MiniUnitArt.FRAMES.size():
			for col in img.get_width() / MiniUnitArt.CELL:
				var cell := img.get_region(Rect2i(col * 16, anim * 16, 16, 16))
				var filled := not cell.is_invisible()
				check("%s anim %d kare %d" % [unit.id, anim, col], filled == (col < MiniUnitArt.FRAMES[anim]))
		# rakip rengi farklı
		check("%s takım rengi farklı" % unit.id, MiniUnitArt.sheet(unit, red).get_data() != img.get_data())
		# UnitSprites geçişi
		var sheet_p := UnitSprites.sheet_for(unit)
		var sheet_e := UnitSprites.sheet_for(unit, SquadState.Team.ENEMY)
		check("%s sayfa kare boyutu" % unit.id, sheet_p.frame_size == Vector2i(16, 16))
		check("%s kare sayıları" % unit.id, sheet_p.counts == MiniUnitArt.FRAMES)
		check("%s takım önbelleği ayrı" % unit.id, sheet_p != sheet_e and sheet_p == UnitSprites.sheet_for(unit))
		check("%s icon" % unit.id, UnitSprites.icon(unit).get_size().x > 0)
	check("7 rol kapsandı", seen_roles.size() == RoleRules.ROLE_ORDER.size())
	# boss eski yolda kalır (büyük çizim)
	var boss: UnitData = load("res://data/bosses/human_boss.tres")
	check("boss büyük sayfa", UnitSprites.sheet_for(boss).frame_size.x > 16)
	print("Hata: ", failures)
	quit(1 if failures else 0)
