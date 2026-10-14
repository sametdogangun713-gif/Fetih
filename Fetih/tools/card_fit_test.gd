extends SceneTree
## Kart yüksekliği testi: her birlik için birlik kartı, 3 kartlık (geniş) ve 4 kartlık (sıkışık) düzende,
## kartın en küçük yüksekliği 640x360 ekranda kart satırına sığıyor mu?
##   godot --headless --path Fetih -s res://tools/card_fit_test.gd
## Kart satırı en fazla ~ ROW_MAX piksel yüksek olabilir (başlık ve alt satır düşüldükten sonra).

const ROW_MAX := 272.0


func _initialize() -> void:
	await process_frame
	if OS.get_cmdline_user_args().has("en"):  # İngilizce metinler daha uzun olabilir
		TranslationServer.set_locale("en")
	var run_state := root.get_node("RunState")
	var card_script: GDScript = load("res://scripts/ui/card_select.gd")
	run_state.start_run(KingdomCatalog.all()[0], 1)
	var host := Control.new()
	host.theme = UiKit.theme()
	root.add_child(host)
	var worst := 0.0
	var failures := 0
	for compact in [false, true]:
		var width := 148.0 if compact else 200.0
		for unit in UnitCatalog.all():
			var selector: Control = card_script.new()
			selector._compact = compact
			var card: Control = selector._card(CardOffer.unit_card(unit))
			card.custom_minimum_size.x = width
			host.add_child(card)
			await process_frame
			var height := card.get_combined_minimum_size().y
			worst = maxf(worst, height)
			if height > ROW_MAX:
				failures += 1
				print("TAŞAR: %s %s h=%.0f" % [unit.id, "sıkışık" if compact else "geniş", height])
			host.remove_child(card)
			card.queue_free()
			selector.free()
	print("En yüksek kart: %.0f px (sınır %.0f)" % [worst, ROW_MAX])
	print("SONUÇ: ", "HEPSİ SIĞDI" if failures == 0 else "%d KART TAŞAR" % failures)
	quit(1 if failures > 0 else 0)
