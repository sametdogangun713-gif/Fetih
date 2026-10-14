class_name SettingsPanel
## Ayarlar penceresi. Ana menüden ve duraklatma menüsünden açılır.
## Her değişiklik anında uygulanır ve Settings tarafından kaydedilir; "Kaydet" düğmesi yok.
## Dil sadece ana menüde değişir: ekranlar koddan kurulduğu için dil değişince ekran
## yeniden yüklenir, savaşın ortasında bu savaşı baştan başlatırdı.


## host: pencerenin ekleneceği düğüm. allow_language: dil seçimi gösterilsin mi.
static func open(host: Node, allow_language := false) -> Overlay:
	var overlay := Overlay.new(320.0, true, 20)
	var box := overlay.content
	box.add_child(UiKit.label(UiKit.t("AYARLAR"), 16, UiKit.COLOR_GOLD))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)

	_row(grid, UiKit.t("Ana ses"), _volume_slider(&"Master"))
	_row(grid, UiKit.t("Müzik"), _volume_slider(&"Music"))
	_row(grid, UiKit.t("Efektler"), _volume_slider(&"SFX"))

	var fullscreen := _check(Settings.fullscreen)
	_row(grid, UiKit.t("Tam ekran"), fullscreen)
	var sizes := OptionButton.new()
	sizes.focus_mode = Control.FOCUS_NONE
	var scales := Settings.available_scales()
	for s in scales:
		sizes.add_item("%dx%d" % [Settings.BASE_SIZE.x * s, Settings.BASE_SIZE.y * s], s)
	sizes.select(maxi(scales.find(Settings.window_scale), 0))
	sizes.disabled = Settings.fullscreen
	sizes.item_selected.connect(func(index: int) -> void:
		Settings.set_window_scale(sizes.get_item_id(index)))
	_row(grid, UiKit.t("Pencere boyutu"), sizes)
	fullscreen.toggled.connect(func(on: bool) -> void:
		Settings.set_fullscreen(on)
		sizes.disabled = on)

	var speed := OptionButton.new()
	speed.focus_mode = Control.FOCUS_NONE
	for s in Settings.SPEEDS:
		speed.add_item("x%d" % s, s)
	speed.select(maxi(Settings.SPEEDS.find(Settings.battle_speed), 0))
	speed.item_selected.connect(func(index: int) -> void:
		Settings.set_battle_speed(speed.get_item_id(index)))
	_row(grid, UiKit.t("Savaş hızı (başlangıç)"), speed)

	var shake := _check(Settings.screen_shake)
	shake.toggled.connect(Settings.set_screen_shake)
	_row(grid, UiKit.t("Ekran sarsıntısı"), shake)
	var flash := _check(Settings.flash_effects)
	flash.toggled.connect(Settings.set_flash_effects)
	_row(grid, UiKit.t("Vuruş flaşı"), flash)
	var numbers := _check(Settings.damage_numbers)
	numbers.toggled.connect(Settings.set_damage_numbers)
	_row(grid, UiKit.t("Hasar sayıları"), numbers)
	var hitstop := _check(Settings.hit_stop)
	hitstop.toggled.connect(Settings.set_hit_stop)
	_row(grid, UiKit.t("Vuruş duraklaması"), hitstop)

	if allow_language:
		var lang := OptionButton.new()
		lang.focus_mode = Control.FOCUS_NONE
		lang.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # dil adları kendi dilinde kalsın
		lang.add_item("Türkçe")
		lang.add_item("English")
		lang.select(Settings.LANGUAGES.find(Settings.current_language()))
		lang.item_selected.connect(func(index: int) -> void:
			Settings.set_language(Settings.LANGUAGES[index])
			# Yazılar koddan kurulduğu için ekran yeni dille baştan kurulur.
			overlay.close()  # durdurduğu oyunu devam ettirir; yoksa yeni ekran donuk açılır
			host.get_tree().reload_current_scene())
		_row(grid, UiKit.t("Dil / Language"), lang)

	var tips := UiKit.button(UiKit.t("İpuçlarını yeniden göster"), func() -> void:
		Profile.reset_tips())
	box.add_child(tips)
	tips.pressed.connect(func() -> void:
		tips.disabled = true
		tips.text = UiKit.t("İpuçları yeniden gösterilecek"))

	var bottom := UiKit.hbox()
	bottom.add_child(UiKit.spacer())
	bottom.add_child(UiKit.button(UiKit.t("Kapat"), overlay.close))
	box.add_child(bottom)
	host.add_child(overlay)
	return overlay


static func _row(grid: GridContainer, text: String, control: Control) -> void:
	grid.add_child(UiKit.label(text, UiKit.FONT_SIZE))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


## 0-100 kaydırıcı ve yanında yüzde. Bırakınca örnek ses çalar (efekt düzeyini duymak için).
static func _volume_slider(bus: StringName) -> Control:
	var row := UiKit.hbox(6)
	var slider := HSlider.new()
	slider.focus_mode = Control.FOCUS_NONE
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = roundi(Settings.volumes[bus] * 100)
	slider.custom_minimum_size.x = 140
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var percent := UiKit.label(UiKit.t("%%%d") % slider.value, 10, UiKit.COLOR_MUTED)
	percent.custom_minimum_size.x = 30
	slider.value_changed.connect(func(value: float) -> void:
		Settings.set_volume(bus, value / 100.0)
		percent.text = UiKit.t("%%%d") % value)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		Audio.play("hit" if bus != &"Music" else "card"))
	row.add_child(slider)
	row.add_child(percent)
	return row


static func _check(on: bool) -> CheckButton:
	var check := CheckButton.new()
	check.focus_mode = Control.FOCUS_NONE
	check.button_pressed = on
	return check
