extends SceneTree
## Kart yüksekliği testi (meydan kart paneli): her birlik, yükseltme ve ferman kartı, 3 kartlık (geniş) ve
## 4 kartlık (sıkışık) düzende, kartın en küçük yüksekliği panelin kart satırına (CardLayer.ROW_MAX) sığıyor mu?
## Türkçe ve İngilizce metinlerle iki tur koşar (İngilizce metinler daha uzun olabilir).
##   godot --headless --path Fetih -s res://tools/card_fit_test.gd
## Kart paneli ekranın alt ~%40'ında; kartlar kısa tutulur, ayrıntılar ipucuna taşınır.

var _failures := 0
var _worst := 0.0


func _initialize() -> void:
	await process_frame
	var run_state := root.get_node("RunState")
	run_state.start_run(KingdomCatalog.all()[0], 1)
	await _check_all("TR")
	TranslationServer.set_locale("en")
	await _check_all("EN")
	TranslationServer.set_locale("tr")
	var layer_script: GDScript = load("res://scripts/run/card_layer.gd")
	print("En yüksek kart: %.0f px (sınır %.0f)" % [_worst, layer_script.ROW_MAX])
	print("SONUÇ: ", "HEPSİ SIĞDI" if _failures == 0 else "%d KART TAŞAR" % _failures)
	quit(1 if _failures > 0 else 0)


func _check_all(tag: String) -> void:
	var run_state := root.get_node("RunState")
	# Sınıf load() ile alınır: araç autoload'lar kurulmadan derlenirken CardLayer -> RunState çözülemez.
	var layer_script: GDScript = load("res://scripts/run/card_layer.gd")
	var row_max: float = layer_script.ROW_MAX
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
			var wide := card.get_combined_minimum_size().x
			_worst = maxf(_worst, height)
			if height > row_max or wide > width + 0.5:
				_failures += 1
				print("TAŞAR [%s]: %s h=%.0f w=%.0f" % [tag, "sıkışık" if compact else "geniş", height, wide])
			host.remove_child(card)
			card.queue_free()
			layer.free()
	host.queue_free()
