extends SceneTree
## Savaş sahnesini test modunda belirli bir seed ile açar (efekt ve ses denemesi, ekran kaydı).
##   godot --path Fetih -s res://tools/battle_showcase.gd -- <seed> [hız]
##   Kayıt: sona --write-movie out.png --quit-after 900 ekle (-- işaretinden önce).
##   Seed listesi: godot --headless --path Fetih -s res://tools/battle_showcase.gd -- list
##   Boss savaşı: -- boss <krallık sırası 0-9> [hız]  (koşu modunda 5. savaş; kayıt ayrı dosyaya)
##   Başka ekran: -- scene res://scenes/run/prep.tscn [settings|pause]  (kayıt ayrı dosyaya)
##   İngilizce: en baştaki argüman "en" olursa dil İngilizce olur (ayar dosyasına yazılmaz).

const SHOWCASE_SAVE := "user://showcase_save.json"  ## Oyuncunun gerçek kaydına asla yazılmaz.


func _initialize() -> void:
	await process_frame  # autoload'lar hazır olsun (Settings dili kendi ayarına göre kurar)
	var args := Array(OS.get_cmdline_user_args())
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
	else:
		battle._test_seed = int(args[0]) if args.size() > 0 else 1
	root.add_child(battle)
	if args.size() > speed_arg:
		battle._set_speed(int(args[speed_arg]))
