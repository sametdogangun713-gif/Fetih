class_name Tips
## Başlangıç rehberi: her ekranın ilk açılışında bir kez çıkan kısa ipucu.
## Görülen ipuçları Profile'da tutulur; Ayarlar > "İpuçlarını yeniden göster" sıfırlar.
## İpucu açıkken oyun durur (savaşta oyuncu okurken savaş ilerlemesin).

const MENU := "menu"
const PREP := "prep"
const BATTLE := "battle"
const CARDS := "cards"
const TREASURY := "treasury"


## İpucu daha önce görülmediyse gösterir. Döndürür: açılan pencere (gösterilmediyse null).
static func show_once(host: Node, id: String) -> Overlay:
	if Profile.tips_seen.has(id):
		return null
	var overlay := Overlay.new(300.0, true, 12)
	var box := overlay.content
	box.add_child(UiKit.label(_title(id), 13, UiKit.COLOR_GOLD))
	for line in _lines(id):
		box.add_child(UiKit.wrapped("• " + line, 10))
	var bottom := UiKit.hbox()
	bottom.add_child(UiKit.spacer())
	bottom.add_child(UiKit.button(UiKit.t("Anladım"), overlay.close))
	box.add_child(bottom)
	overlay.closed.connect(Profile.mark_tip_seen.bind(id))
	host.add_child(overlay)
	return overlay


static func _title(id: String) -> String:
	match id:
		MENU:
			return UiKit.t("Fetih'e hoş geldin")
		PREP:
			return UiKit.t("Hazırlık")
		BATTLE:
			return UiKit.t("Savaş")
		CARDS:
			return UiKit.t("Ganimet")
		TREASURY:
			return UiKit.t("Hazine")
	return ""


static func _lines(id: String) -> PackedStringArray:
	match id:
		MENU:
			return [
				UiKit.t("Bir krallık seç ve 20 savaşlık fethe çık. Her 5. savaşta bir boss bekler."),
				UiKit.t("Savaşları ordun kendi yapar; senin işin orduyu kurmak ve büyütmek."),
				UiKit.t("Kilitli krallıklar, koşu içinde boss'larını yenip fethi tamamlayınca açılır."),
			]
		PREP:
			return [
				UiKit.t("Bölükleri sürükleyip bırakarak yerlerini değiştir. Üst sıra ön cephedir."),
				UiKit.t("Sağda sıradaki rakibin ordusu var: rolleri incele, karşılığını öne koy."),
				UiKit.t("Canların üstte yazar. Kaybedilen savaş bir can götürür ve tekrar oynanmaz."),
			]
		BATTLE:
			return [
				UiKit.t("Savaş kendi kendine oynar. Sağ üstten hızlandırabilirsin."),
				UiKit.t("Kamera savaşı kendisi takip eder. WASD, sağ tuşla sürükleme ya da fare tekerleği elle kontrol eder; F otomatik takibe döner."),
				UiKit.t("Esc: duraklat ve ayarlar."),
			]
		CARDS:
			return [
				UiKit.t("Kartlar az önce savaştığın krallıktan gelir. Seçtiğin kart hemen uygulanır."),
				UiKit.t("Yeni birlik, bölük yükseltmesi ya da koşu boyu süren bir ferman alabilirsin."),
				UiKit.t("En fazla 5 bölük olur; bölükler en çok 5. seviyeye çıkar."),
			]
		TREASURY:
			return [
				UiKit.t("Koşulardan kazandığın Şan ile kalıcı geliştirmeler al."),
				UiKit.t("Geliştirmeler bundan sonraki bütün koşularda geçerlidir."),
			]
	return []
