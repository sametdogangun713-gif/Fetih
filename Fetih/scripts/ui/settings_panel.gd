class_name SettingsPanel
extends Overlay
## Ayarlar penceresi: sekmeler (Ses / Görüntü / Oyun / Dil), her satır solda ad, sağda sabit genişlikte kontrol.
## Ana menüden açılınca parşömen (menü) teması ve Dil sekmesi, ağaç durmaz; duraklatma menüsünden koyu tema,
## dil yok, oyun durur.
## Her değişiklik anında uygulanır ve Settings tarafından kaydedilir; "Kaydet" düğmesi yok.
## Dil sadece ana menüde değişir: ekranlar koddan kurulduğu için dil değişince ekran yeniden yüklenir.
## Godot: TabBar sadece sekme başlıklarını çizer; sayfalar ayrı Control'ler, seçilen görünür olur.

const CONTROL_WIDTH := 170.0
const ROW_HEIGHT := 24.0
const PAGE_HEIGHT := 150.0

var _host: Node
var _allow_language := false
var _tabs: TabBar
var _pages: Array[Control] = []
var _sliders := {}  ## bus -> HSlider


## host: pencerenin ekleneceği düğüm. allow_language: menüden açıldı (dil sekmesi + menü teması).
static func open(host: Node, allow_language := false) -> SettingsPanel:
	var panel := SettingsPanel.new(allow_language)
	panel._host = host
	host.add_child(panel)
	return panel


func _init(allow_language := false) -> void:
	super(340.0, not allow_language, 20, allow_language)  # menüde durduracak oyun yok
	_allow_language = allow_language
	_build()


func tab_count() -> int:
	return _tabs.tab_count


func select_tab(index: int) -> void:
	_tabs.current_tab = index
	_show_page(index)


func tab_content() -> Control:
	return _pages[_tabs.current_tab]


func slider_for(bus: StringName) -> HSlider:
	return _sliders.get(bus)


func is_menu_theme() -> bool:
	return menu_theme


func _build() -> void:
	var title := UiKit.label(UiKit.t("AYARLAR"), 18, UiKit.COLOR_GOLD if not menu_theme else UiKit.COLOR_INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_tabs = TabBar.new()
	_tabs.tab_alignment = TabBar.ALIGNMENT_CENTER
	_tabs.clip_tabs = false
	content.add_child(_tabs)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, PAGE_HEIGHT)
	content.add_child(holder)
	_add_page(holder, UiKit.t("Ses"), _sound_page())
	_add_page(holder, UiKit.t("Görüntü"), _display_page())
	_add_page(holder, UiKit.t("Oyun"), _game_page())
	if _allow_language:
		_add_page(holder, UiKit.t("Dil"), _language_page())
	_tabs.tab_changed.connect(_show_page)
	focus_target = _tabs
	_show_page(0)
	var close_button := UiKit.button(UiKit.t("Kapat"), close)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.custom_minimum_size.x = 110
	content.add_child(close_button)


func _add_page(holder: Control, tab_name: String, page: VBoxContainer) -> void:
	_tabs.add_tab(tab_name)
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.visible = false
	holder.add_child(page)
	_pages.append(page)


func _show_page(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
	if index < _pages.size():
		UiKit.fade_in(_pages[index], 0.0, 0.15)


func _page() -> VBoxContainer:
	var page := UiKit.vbox(4)
	return page


## Satır: solda ad (genişler), sağda sabit genişlikte kontrol; hepsi aynı yükseklikte.
func _row(page: VBoxContainer, text: String, control: Control) -> void:
	var row := UiKit.hbox(8)
	row.custom_minimum_size.y = ROW_HEIGHT
	var label := UiKit.label(text, 11, UiKit.COLOR_INK if menu_theme else UiKit.COLOR_TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	control.custom_minimum_size.x = CONTROL_WIDTH
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	page.add_child(row)


func _sound_page() -> VBoxContainer:
	var page := _page()
	_row(page, UiKit.t("Ana ses"), _volume_slider(&"Master"))
	_row(page, UiKit.t("Müzik"), _volume_slider(&"Music"))
	_row(page, UiKit.t("Efektler"), _volume_slider(&"SFX"))
	return page


func _display_page() -> VBoxContainer:
	var page := _page()
	var fullscreen := _check(Settings.fullscreen)
	_row(page, UiKit.t("Tam ekran"), fullscreen)
	var sizes := OptionButton.new()
	sizes.focus_mode = Control.FOCUS_NONE
	var scales := Settings.available_scales()
	for s in scales:
		sizes.add_item("%dx%d" % [Settings.BASE_SIZE.x * s, Settings.BASE_SIZE.y * s], s)
	sizes.select(maxi(scales.find(Settings.window_scale), 0))
	sizes.disabled = Settings.fullscreen
	sizes.item_selected.connect(func(index: int) -> void:
		Settings.set_window_scale(sizes.get_item_id(index)))
	_row(page, UiKit.t("Pencere boyutu"), sizes)
	fullscreen.toggled.connect(func(on: bool) -> void:
		Settings.set_fullscreen(on)
		sizes.disabled = on)
	return page


func _game_page() -> VBoxContainer:
	var page := _page()
	var speed := OptionButton.new()
	speed.focus_mode = Control.FOCUS_NONE
	for s in Settings.SPEEDS:
		speed.add_item("x%d" % s, s)
	speed.select(maxi(Settings.SPEEDS.find(Settings.battle_speed), 0))
	speed.item_selected.connect(func(index: int) -> void:
		Settings.set_battle_speed(speed.get_item_id(index)))
	_row(page, UiKit.t("Savaş hızı (başlangıç)"), speed)
	var shake := _check(Settings.screen_shake)
	shake.toggled.connect(Settings.set_screen_shake)
	_row(page, UiKit.t("Ekran sarsıntısı"), shake)
	var flash := _check(Settings.flash_effects)
	flash.toggled.connect(Settings.set_flash_effects)
	_row(page, UiKit.t("Vuruş flaşı"), flash)
	var numbers := _check(Settings.damage_numbers)
	numbers.toggled.connect(Settings.set_damage_numbers)
	_row(page, UiKit.t("Hasar sayıları"), numbers)
	var hitstop := _check(Settings.hit_stop)
	hitstop.toggled.connect(Settings.set_hit_stop)
	_row(page, UiKit.t("Vuruş duraklaması"), hitstop)
	var tips := UiKit.button_ghost(UiKit.t("İpuçlarını yeniden göster"), func() -> void: Profile.reset_tips())
	tips.pressed.connect(func() -> void:
		tips.disabled = true
		tips.text = UiKit.t("İpuçları yeniden gösterilecek"))
	page.add_child(tips)
	return page


func _language_page() -> VBoxContainer:
	var page := _page()
	var lang := OptionButton.new()
	lang.focus_mode = Control.FOCUS_NONE
	lang.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # dil adları kendi dilinde kalsın
	lang.add_item("Türkçe")
	lang.add_item("English")
	lang.select(Settings.LANGUAGES.find(Settings.current_language()))
	lang.item_selected.connect(func(index: int) -> void:
		Settings.set_language(Settings.LANGUAGES[index])
		# Yazılar koddan kurulduğu için ekran yeni dille baştan kurulur.
		close()  # durdurduğu oyunu devam ettirir; yoksa yeni ekran donuk açılır
		_host.get_tree().reload_current_scene())
	_row(page, UiKit.t("Dil / Language"), lang)
	return page


## 0-100 kaydırıcı ve yanında yüzde; başlangıç değeri gerçek ayardan (sinyalsiz). Bırakınca örnek ses çalar.
func _volume_slider(bus: StringName) -> Control:
	var row := UiKit.hbox(6)
	var slider := HSlider.new()
	slider.focus_mode = Control.FOCUS_NONE
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.set_value_no_signal(roundi(float(Settings.volumes.get(bus, 1.0)) * 100))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var percent := UiKit.label(UiKit.t("%%%d") % slider.value, 10, UiKit.COLOR_INK if menu_theme else UiKit.COLOR_MUTED)
	percent.custom_minimum_size.x = 32
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(value: float) -> void:
		Settings.set_volume(bus, value / 100.0)
		percent.text = UiKit.t("%%%d") % value)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		Audio.play("hit" if bus != &"Music" else "card"))
	row.add_child(slider)
	row.add_child(percent)
	_sliders[bus] = slider
	return row


static func _check(on: bool) -> CheckButton:
	var check := CheckButton.new()
	check.focus_mode = Control.FOCUS_NONE
	check.button_pressed = on
	check.size_flags_horizontal = Control.SIZE_SHRINK_END
	return check
