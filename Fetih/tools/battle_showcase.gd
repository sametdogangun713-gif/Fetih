extends SceneTree
## Savaş sahnesini test modunda belirli bir seed ile açar (efekt ve ses denemesi, ekran kaydı).
##   godot --path Fetih -s res://tools/battle_showcase.gd -- <seed> [hız]
##   Kayıt: sona --write-movie out.png --quit-after 900 ekle (-- işaretinden önce).
##   Seed listesi: godot --headless --path Fetih -s res://tools/battle_showcase.gd -- list
##   Boss savaşı: -- boss <krallık sırası 0-9> [hız]  (koşu modunda 5. savaş; kayıt ayrı dosyaya)
##   Geç oyun: -- run <krallık sırası> <savaş sayısı> [hız]  (koşu o kadar savaş botla oynanır,
##     sonra sıradaki savaş açılır; bot alınabilen ilk kartı alır)
##   Başka ekran: -- scene res://scenes/run/prep.tscn [settings|pause]  (kayıt ayrı dosyaya)
##   Yakın kamera: herhangi bir yerde "zoom".
##   İpuçsuz: herhangi bir yerde "notips" (ekran görüntüleri için).
##   İngilizce: en baştaki argüman "en" olursa dil İngilizce olur (ayar dosyasına yazılmaz).

const SHOWCASE_SAVE := "user://showcase_save.json"  ## Oyuncunun gerçek kaydına asla yazılmaz.


func _initialize() -> void:
	await process_frame  # autoload'lar hazır olsun (Settings dili kendi ayarına göre kurar)
	var args := Array(OS.get_cmdline_user_args())
	var zoom := args.has("zoom")  # savaşta kamera 2x yakın (ekran görüntüleri için)
	args.erase("zoom")
	if args.has("notips"):  # ekran görüntüleri için: ipuçları sadece bellekte "görüldü" (kayda yazılmaz)
		args.erase("notips")
		var profile := root.get_node("Profile")
		for id in ["menu", "prep", "battle", "cards", "treasury"]:
			profile.tips_seen.append(id)
	if not args.is_empty() and args[0] == "en":
		TranslationServer.set_locale("en")
		args.pop_front()
	if args.size() > 1 and args[0] == "scene":
		root.get_node("Profile").save_path = SHOWCASE_SAVE
		var screen: Node = load(args[1]).instantiate()
		root.add_child(screen)
		# Sınıflar load() ile alınır: doğrudan ad kullanılsa bu araç autoload'lar kurulmadan
		# derlenirken (Settings, RunState) "Identifier not found" hatası verir.
		if args.has("settings"):
			load("res://scripts/ui/settings_panel.gd").open(screen, true)
		if args.has("pause"):
			for child in screen.get_children():
				if child.get_script() == load("res://scripts/ui/pause_menu.gd"):
					child.open()
		return
	var battle: Node = load("res://scenes/battle/battle.tscn").instantiate()
	if args.size() > 0 and args[0] == "list":
		for s in range(1, 41):
			battle._test_seed = s
			var m: Array = battle._choose_test_matchup()
			print("%d: %s (%s) vs %s (%s)" % [s, m[0].display_name, m[0].role, m[1].display_name, m[1].role])
		battle.free()
		quit()
		return
	var speed_arg := 1
	if args.size() > 0 and args[0] == "boss":
		var profile := root.get_node("Profile")
		profile.save_path = SHOWCASE_SAVE
		var kingdoms := KingdomCatalog.all()
		root.get_node("RunState").start_run(kingdoms[int(args[1]) % kingdoms.size()], 7)
		# Rakip krallık kendi kilit sırasına göre seçilir; 5. savaş her zaman boss.
		root.get_node("RunState").battle_index = Balance.BOSS_EVERY - 1
		speed_arg = 2
	elif args.size() > 2 and args[0] == "run":
		root.get_node("Profile").save_path = SHOWCASE_SAVE
		var kingdoms := KingdomCatalog.all()
		var run := root.get_node("RunState")
		run.start_run(kingdoms[int(args[1]) % kingdoms.size()], 11)
		for i in int(args[2]):
			run.finish_battle(_simulate(run))
			if run.is_defeated() or run.is_last_battle():
				break
			for offer in run.card_offers():
				if run.can_take(offer) and not run.needs_replace(offer):
					run.take_card(offer)
					break
			run.advance()
		speed_arg = 3
	else:
		battle._test_seed = int(args[0]) if args.size() > 0 else 1
	root.add_child(battle)
	if zoom:
		battle.battlefield.camera._set_zoom_index(2)
	if args.size() > speed_arg:
		battle._set_speed(int(args[speed_arg]))


## Savaşı ekransız sonuna kadar oynatır (koşu modu sırasıyla aynı bölükler ve seed).
func _simulate(run: Node) -> bool:
	var sim := BattleSimulation.new(run.battle_seed(), Rect2(0, 0, 9, 15))
	for squad in run.build_player_squads():
		sim.add_squad(squad)
	for squad in run.build_enemy_squads():
		sim.add_squad(squad)
	while not sim.finished:
		sim.step()
	var won: bool = sim.winner == SquadState.Team.PLAYER
	sim.dispose()
	return won
