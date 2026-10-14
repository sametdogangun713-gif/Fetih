extends SceneTree
## Kayıt sistemi testleri. Oyuncunun gerçek kaydına dokunmaz (user://test_save.json kullanır).
## Çalıştırma: godot --headless --path Fetih -s res://tools/save_test.gd

const ProfileScript = preload("res://scripts/meta/profile.gd")
const RunStateScript = preload("res://scripts/run/run_state.gd")
const SettingsScript = preload("res://scripts/meta/settings.gd")
const TEST_PATH := "user://test_save.json"
const TEST_SETTINGS_PATH := "user://test_settings.cfg"

var failures := 0


func check(name: String, ok: bool) -> void:
	print("%s  %s" % ["TAMAM " if ok else "HATA  ", name])
	if not ok:
		failures += 1


func new_profile() -> Node:
	var p: Node = ProfileScript.new()
	p.save_path = TEST_PATH
	return p


func play_battle(run: Node) -> bool:
	var sim := BattleSimulation.new(run.battle_seed(), Rect2(0, 0, 9, 15))
	for s in run.build_player_squads():
		sim.add_squad(s)
	for s in run.build_enemy_squads():
		sim.add_squad(s)
	while not sim.finished:
		sim.step()
	var won := sim.winner == SquadState.Team.PLAYER
	sim.dispose()
	return won


## Bir savaş + ilk alınabilen kart. Sonuç özetini döndürür.
func play_step(run: Node) -> String:
	var won := play_battle(run)
	run.finish_battle(won)
	var summary := "W" if won else "L"
	if run.is_defeated() or run.is_last_battle():
		return summary + "|son"
	for offer in run.card_offers():
		if run.can_take(offer) and not run.needs_replace(offer):
			run.take_card(offer)
			summary += "|%d" % offer.kind
			break
	run.advance()
	return summary + "|%d" % roundi(run.army_power(run.army))


func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH + ".bozuk"))

	# 1) Profil kaydet / yükle
	var a := new_profile()
	a.load_profile()
	check("yeni profilde 3 krallık açık", a.unlocked.size() == 3)
	a.glory = 77
	a.upgrades = {MetaUpgrades.EXTRA_CARD: 2, MetaUpgrades.SCOUTING: 1}
	a.stats["runs"] = 5
	a.saved_run = {"phase": "prep", "kingdom": "elves", "battle_index": 3}
	a.save_profile()
	var b := new_profile()
	b.load_profile()
	check("Şan geri yüklendi", b.glory == 77)
	check("geliştirmeler geri yüklendi (sayı tipi int)", b.level_of(MetaUpgrades.EXTRA_CARD) == 2
			and typeof(b.upgrades[MetaUpgrades.EXTRA_CARD]) == TYPE_INT)
	check("istatistik geri yüklendi", int(b.stats["runs"]) == 5)
	check("yarım koşu geri yüklendi", b.has_saved_run() and int(b.saved_run["battle_index"]) == 3)
	check("geçici dosya kalmadı", not FileAccess.file_exists(TEST_PATH + ".tmp"))

	# 2) Satın alma
	b.glory = 100
	b.buy(MetaUpgrades.EXTRA_LIFE)
	check("satın alma: Şan düştü, seviye arttı", b.glory == 40 and b.level_of(MetaUpgrades.EXTRA_LIFE) == 1)
	b.buy(MetaUpgrades.EXTRA_LIFE)
	check("en üst seviye tekrar alınamaz", b.glory == 40 and b.level_of(MetaUpgrades.EXTRA_LIFE) == 1)

	# 3) Bozuk kayıt
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{bu json değil")
	f.close()
	var c := new_profile()
	c.load_profile()
	check("bozuk kayıt: varsayılan profil", c.glory == 0 and c.unlocked.size() == 3)
	check("bozuk kayıt yedeklendi", FileAccess.file_exists(TEST_PATH + ".bozuk"))

	# 4) Koşuya devam: kaydet -> JSON -> yükle, sonra iki kopya aynı sonuçları vermeli
	var run1: Node = RunStateScript.new()
	run1.start_run(KingdomCatalog.get_kingdom(&"humans"), 12345, {"rerolls": 1})
	for i in 6:
		play_step(run1)
	var json := JSON.stringify(run1.to_dict("prep"))
	var run2: Node = RunStateScript.new()
	check("koşu JSON'dan yüklendi", run2.from_dict(JSON.parse_string(json)))
	check("ordu gücü aynı", is_equal_approx(run1.army_power(run1.army), run2.army_power(run2.army)))
	var e1: Array[ArmySquad] = run1.current_enemy_army()
	var e2: Array[ArmySquad] = run2.current_enemy_army()
	var same_enemy := e1.size() == e2.size()
	for i in e1.size():
		same_enemy = same_enemy and e1[i].unit == e2[i].unit and e1[i].count == e2[i].count
	check("rakip ordusu aynı", same_enemy)
	var log1 := ""
	var log2 := ""
	for i in 6:
		log1 += play_step(run1) + " "
		log2 += play_step(run2) + " "
	check("devam eden 6 savaş aynı sonuçlar (%s)" % log1.strip_edges(), log1 == log2)

	# 5) Mühür ve krallık açma
	var locked: Array[StringName] = [&"orcs"]
	var run3: Node = RunStateScript.new()
	run3.start_run(KingdomCatalog.get_kingdom(&"humans"), 7, {}, locked)
	while not run3.is_last_battle():
		run3.finish_battle(true)
		run3.advance()
	run3.finish_battle(true)
	var orc_boss_fights := 0
	for i in Balance.RUN_LENGTH:
		if Balance.is_boss_battle(i) and run3.opponents[i].id == &"orcs":
			orc_boss_fights += 1
	check("ork boss'u yenilince mühür (%d ork boss savaşı)" % orc_boss_fights,
			(orc_boss_fights > 0) == run3.seals.has(&"orcs"))
	check("hepsi kazanılınca fetih", run3.is_victory())
	# 3. adımdaki bozuk kayıt yerinde duruyor (profil onu kopyalar, silmez); temiz profil için kaldır.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	check("bozuk test kaydı temizlendi", not FileAccess.file_exists(TEST_PATH))
	var d := new_profile()
	d.load_profile()
	d.unlocked.erase(&"orcs")
	var opened: Array[StringName] = d.record_run_end(run3.glory_earned(), true, &"humans", run3.wins, 20, run3.seals)
	check("fetih sonrası ork krallığı açıldı", d.is_unlocked(&"orcs") == run3.seals.has(&"orcs")
			and opened.size() == run3.seals.size())
	check("Şan: 20 zafer x2 + 4 boss x5 + 25 = 85", run3.glory_earned() == 85)

	# 6) Kalıcı geliştirmeler
	var run4: Node = RunStateScript.new()
	run4.start_run(KingdomCatalog.get_kingdom(&"elves"), 99,
			{"extra_lives": 1, "extra_cards": 2, "veterans": 1, "rerolls": 2})
	check("+1 can: 4 can", run4.lives == 4 and run4.max_lives == 4)
	check("gaziler: başlangıç bölükleri Sv 2", run4.army.all(func(s): return s.level() == 2))
	run4.finish_battle(true)
	var offers_before: Array[CardOffer] = run4.card_offers()
	check("+2 kart: zaferde 5 kart", offers_before.size() == 5)
	run4.reroll_cards()
	var offers_after: Array[CardOffer] = run4.card_offers()
	var changed := false
	for i in mini(offers_before.size(), offers_after.size()):
		var x: CardOffer = offers_before[i]
		var y: CardOffer = offers_after[i]
		if x.kind != y.kind or x.unit != y.unit or x.passive != y.passive or x.target != y.target or x.upgrade != y.upgrade:
			changed = true
	check("yeniden çekme kartları değiştirdi, hak azaldı", changed and run4.rerolls_left == 1)

	# 7) Başlangıç ipuçları
	var e := new_profile()
	e.load_profile()
	e.mark_tip_seen("prep")
	var tips_reload := new_profile()
	tips_reload.load_profile()
	check("görülen ipucu kayda geçti", tips_reload.tips_seen == ["prep"])
	tips_reload.reset_tips()
	e.load_profile()
	check("ipuçları sıfırlandı", e.tips_seen.is_empty())

	# 8) Ayarlar (ayrı dosya: user://test_settings.cfg)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	var s1: Node = SettingsScript.new()
	s1.settings_path = TEST_SETTINGS_PATH
	s1.load_settings()
	check("ayar dosyası yoksa varsayılanlar", s1.battle_speed == 1 and s1.screen_shake and s1.language == "")
	var locale_before := TranslationServer.get_locale()
	s1.set_volume(&"Music", 0.35)
	s1.set_battle_speed(4)
	s1.set_screen_shake(false)
	s1.set_language("en")
	var s2: Node = SettingsScript.new()
	s2.settings_path = TEST_SETTINGS_PATH
	s2.load_settings()
	check("ayarlar geri yüklendi", is_equal_approx(s2.volumes[&"Music"], 0.35) and s2.battle_speed == 4
			and not s2.screen_shake and s2.language == "en")
	s2.set_battle_speed(3)
	check("geçersiz savaş hızı x1'e döner", s2.battle_speed == 1)

	# 9) Çeviri: İngilizce .po yüklü, Türkçe kaynak metin olduğu gibi kalır
	TranslationServer.set_locale("en")
	check("İngilizce çeviri", TranslationServer.translate("Savaşa başla") == "Start battle")
	check("veri metni çevrildi", TranslationServer.translate("Elf Okçusu") == "Elf Archer")
	check("çok satırlı metin çevrildi", TranslationServer.translate(
			"Can %s   Hasar %s   Saldırı %s/sn
Menzil %s   Hız %s   Zırh %s").contains("
Range"))
	TranslationServer.set_locale("tr")
	check("Türkçede metin aynen kalır (İngilizceye düşmez)",
			TranslationServer.translate("Savaşa başla") == "Savaşa başla")
	TranslationServer.set_locale(locale_before)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))

	# 10) Serbest konum kaydı ve eski ("cell") biçim.
	var r1: Node = RunStateScript.new()
	r1.start_run(KingdomCatalog.all()[0], 777)
	r1.army[0].pos = Vector2(7.25, 2.5)
	var r2: Node = RunStateScript.new()
	check("pos kaydı yüklendi", r2.from_dict(JSON.parse_string(JSON.stringify(r1.to_dict("prep")))))
	check("pos korundu", r2.army[0].pos.is_equal_approx(Vector2(7.25, 2.5)))
	var old: Dictionary = r1.to_dict("prep")
	for sq in old.army:
		sq.erase("pos")
		sq["cell"] = [2, 1]
	var r3: Node = RunStateScript.new()
	check("eski biçim yüklendi", r3.from_dict(JSON.parse_string(JSON.stringify(old))))
	check("eski cell dönüştü", r3.army[0].pos.is_equal_approx(Formation.cell_to_deploy(Vector2i(2, 1), Vector2i(3, 3))))
	for node in [r1, r2, r3]:
		node.free()

	for node in [a, b, c, d, e, tips_reload, s1, s2, run1, run2, run3, run4]:
		node.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH + ".bozuk"))
	print("SONUÇ: %s" % ("HEPSİ GEÇTİ" if failures == 0 else "%d HATA" % failures))
	UnitCatalog.clear_cache()
	KingdomCatalog.clear_cache()
	PassiveCatalog.clear_cache()
	quit()
