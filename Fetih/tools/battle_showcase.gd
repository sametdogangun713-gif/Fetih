extends SceneTree
## Savaş sahnesini test modunda belirli bir seed ile açar (efekt ve ses denemesi, ekran kaydı).
##   godot --path Fetih -s res://tools/battle_showcase.gd -- <seed> [hız]
##   Kayıt: sona --write-movie out.png --quit-after 900 ekle (-- işaretinden önce).
##   Seed listesi: godot --headless --path Fetih -s res://tools/battle_showcase.gd -- list
##   Boss savaşı: -- boss <krallık sırası 0-9> [hız]  (koşu modunda 5. savaş; kayıt ayrı dosyaya)
##   Geç oyun: -- run <krallık sırası> <savaş sayısı> [hız]  (koşu o kadar savaş botla oynanır,
##     sonra sıradaki savaş açılır; bot alınabilen ilk kartı alır)
##   Başka ekran: -- scene res://scenes/run/prep.tscn [settings|pause]  (kayıt ayrı dosyaya)
##   Meydan: -- meydan prep|battle|cards [krallık sırası] [oynanmış savaş sayısı]  (kayıt ayrı dosyaya)
##   Yakın kamera: herhangi bir yerde "zoom" (sabit 2x, otomatik takip kapalı).
##   İpuçsuz: herhangi bir yerde "notips" (ekran görüntüleri için).
##   Flaş/sarsıntı kapalı: herhangi bir yerde "nofx" (bellekte; ayar dosyasına yazılmaz).
##   İngilizce: en baştaki argüman "en" olursa dil İngilizce olur (ayar dosyasına yazılmaz).
##   Profil: tüm modlarda her açılışta boş gösterim profili (user://showcase_save.json);
##     oyuncunun gerçek kaydı (user://save.json) ne okunur ne yazılır.

const SHOWCASE_SAVE := "user://showcase_save.json"  ## Oyuncunun gerçek kaydına asla yazılmaz.


## Araç scripti autoload'lardan önce oluşur. Profile autoload'u ağaca girerken (_ready'de kaydı
## okumadan önce) node_added sinyaliyle yakalanıp kayıt yolu gösterim dosyasına çevrilir.
func _init() -> void:
	# Her açılış boş profille başlar: ekran görüntüleri tekrarlanabilir, eski kopyalar kalmaz.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SHOWCASE_SAVE))
	node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node.get_parent() == root and node.name == "Profile":
		node.save_path = SHOWCASE_SAVE
		node_added.disconnect(_on_node_added)


func _initialize() -> void:
	await process_frame  # autoload'lar hazır olsun (Settings dili kendi ayarına göre kurar)
	var profile := root.get_node("Profile")
	if profile.save_path != SHOWCASE_SAVE:  # yedek yol: yakalanamadıysa yolu çevir, yeniden yükle
		push_warning("Profile autoload'u yakalanamadı; gösterim kaydı sonradan yüklendi.")
		profile.save_path = SHOWCASE_SAVE
		profile.load_profile()
	print("Gösterim profili: %s (Şan %d)" % [profile.save_path, profile.glory])
	var args := Array(OS.get_cmdline_user_args())
	var zoom := args.has("zoom")  # savaşta kamera 2x yakın (ekran görüntüleri için)
	args.erase("zoom")
	if args.has("notips"):  # ekran görüntüleri için: ipuçları sadece bellekte "görüldü" (kayda yazılmaz)
		args.erase("notips")
		for id in ["menu", "prep", "battle", "cards", "treasury"]:
			profile.tips_seen.append(id)
	if args.has("nofx"):  # erişilebilirlik denemesi: flaş ve sarsıntı kapalı (sadece bellekte, ayar dosyasına yazılmaz)
		args.erase("nofx")
		var settings := root.get_node("Settings")
		settings.flash_effects = false
		settings.screen_shake = false
	if not args.is_empty() and args[0] == "en":
		TranslationServer.set_locale("en")
		args.pop_front()
	if args.size() > 1 and args[0] == "scene":
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
	if args.size() > 1 and args[0] == "meydan":
		# -- meydan prep|battle|cards [krallık sırası] [oynanmış savaş sayısı]: Meydan sahnesi o aşamada açılır.
		var kingdoms := KingdomCatalog.all()
		var run := root.get_node("RunState")
		run.start_run(kingdoms[(int(args[2]) if args.size() > 2 else 0) % kingdoms.size()], 11)
		for i in (int(args[3]) if args.size() > 3 else 0):  # bot geçmiş savaşları oynar, alınabilen ilk kartı alır
			run.finish_battle(_simulate(run))
			for offer in run.card_offers():
				if run.can_take(offer) and not run.needs_replace(offer):
					run.take_card(offer)
					break
			run.advance()
		if args[1] == "cards":
			run.finish_battle(_simulate(run))
		load("res://scripts/ui/screens.gd").next_phase = args[1]  # sınıf load() ile: autoload'sız derleme
		var meydan: Node = load("res://scenes/run/meydan.tscn").instantiate()
		root.add_child(meydan)
		if zoom:
			meydan.battlefield.camera.auto_follow = false
			meydan.battlefield.camera._set_zoom_index(BattleCamera.ZOOM_LEVELS.size() - 1)
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
		var kingdoms := KingdomCatalog.all()
		root.get_node("RunState").start_run(kingdoms[int(args[1]) % kingdoms.size()], 7)
		# Rakip krallık kendi kilit sırasına göre seçilir; 5. savaş her zaman boss.
		root.get_node("RunState").battle_index = Balance.BOSS_EVERY - 1
		speed_arg = 2
	elif args.size() > 2 and args[0] == "run":
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
	if zoom:  # sabit 2x yakın kamera: otomatik takip kapanır
		battle.battlefield.camera.auto_follow = false
		battle.battlefield.camera._set_zoom_index(BattleCamera.ZOOM_LEVELS.size() - 1)
	if args.size() > speed_arg:
		battle.hud.set_speed(int(args[speed_arg]))


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
