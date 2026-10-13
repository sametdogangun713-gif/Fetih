extends SceneTree
## Savaş sahnesini test modunda belirli bir seed ile açar (efekt ve ses denemesi, ekran kaydı).
##   godot --path Fetih -s res://tools/battle_showcase.gd -- <seed> [hız]
##   Kayıt: sona --write-movie out.png --quit-after 900 ekle (-- işaretinden önce).
##   Seed listesi: godot --headless --path Fetih -s res://tools/battle_showcase.gd -- list
##   Boss savaşı: -- boss <krallık sırası 0-9> [hız]  (koşu modunda 5. savaş; kayıt ayrı dosyaya)
##   Başka ekran: -- scene res://scenes/run/prep.tscn  (kayıt ayrı dosyaya)

const SHOWCASE_SAVE := "user://showcase_save.json"  ## Oyuncunun gerçek kaydına asla yazılmaz.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1 and args[0] == "scene":
		root.get_node("Profile").save_path = SHOWCASE_SAVE
		root.add_child(load(args[1]).instantiate())
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
