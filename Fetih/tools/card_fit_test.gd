extends SceneTree
## Kart yüksekliği testi (meydan kart paneli): her birlik, yükseltme ve ferman kartı, 3 kartlık (geniş) ve
## 4 kartlık (sıkışık) düzende, kartın en küçük yüksekliği panelin kart satırına (CardLayer.ROW_MAX) sığıyor mu?
##   godot --headless --path Fetih -s res://tools/card_fit_test.gd [-- en]
## Kart paneli ekranın alt ~%40'ında; kartlar kısa tutulur, ayrıntılar ipucuna taşınır.


func _initialize() -> void:
	await process_frame
	if OS.get_cmdline_user_args().has("en"):  # İngilizce metinler daha uzun olabilir
		TranslationServer.set_locale("en")
	var run_state := root.get_node("RunState")
	# Sınıf load() ile alınır: araç autoload'lar kurulmadan derlenirken CardLayer -> RunState çözülemez.
	var layer_script: GDScript = load("res://scripts/run/card_layer.gd")
	var row_max: float = layer_script.ROW_MAX
	run_state.start_run(KingdomCatalog.all()[0], 1)
	var offers: Array[CardOffer] = []
	for unit in UnitCatalog.all():
		offers.append(CardOffer.unit_card(unit))
	for upgrade in [ArmySquad.Upgrade.ATTACK, ArmySquad.Upgrade.DEFENSE, ArmySquad.Upgrade.REINFORCE]:
		offers.append(CardOffer.upgrade_card(run_state.army[0], upgrade))
	for passive in PassiveCatalog.all():
		offers.append(CardOffer.passive_card(passive))
	var host := Control.new()
	host.theme = UiKit.theme()
	root.add_child(host)
	var worst := 0.0
	var failures := 0
	for compact in [false, true]:
		var width := 148.0 if compact else 200.0
		for offer in offers:
			var layer: CanvasLayer = layer_script.new()
			layer._compact = compact
			var card: Control = layer._card(offer)
			card.custom_minimum_size.x = width
			host.add_child(card)
			await process_frame
			var height := card.get_combined_minimum_size().y
			worst = maxf(worst, height)
			if height > row_max:
				failures += 1
				print("TAŞAR: %s h=%.0f" % ["sıkışık" if compact else "geniş", height])
			host.remove_child(card)
			card.queue_free()
			layer.free()
	print("En yüksek kart: %.0f px (sınır %.0f)" % [worst, row_max])
	print("SONUÇ: ", "HEPSİ SIĞDI" if failures == 0 else "%d KART TAŞAR" % failures)
	quit(1 if failures > 0 else 0)
