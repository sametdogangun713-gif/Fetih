extends SceneTree
## Geçici ses efektlerini ve müzikleri koddan sentezler (chiptune tarzı), .wav olarak kaydeder.
## Gerçek sesler gelince aynı adla assets/audio/ altına konur; Audio autoload'u onları çalar.
##
## Çalıştırma (WAV'lar sonra Godot'a içe aktarılmalı):
##   godot --headless --path Fetih -s res://tools/build_audio.gd
##   godot --headless --path Fetih --import

const RATE := 22050
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"

enum Wave { SINE, SQUARE, TRIANGLE, SAW, NOISE }

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 1453  # aynı seed = aynı dosyalar
	_build_sfx()
	_build_music()
	quit()


# --- Ses efektleri ---

func _build_sfx() -> void:
	var s: PackedFloat32Array

	s = _tone(0.045, 1300, 900, Wave.SQUARE, 0.25, 0.002, 2.0)
	_save_sfx("click", s)

	s = _tone(0.07, 660, 660, Wave.TRIANGLE, 0.4)
	_mix(s, _tone(0.12, 990, 990, Wave.TRIANGLE, 0.4), 0.06)
	_save_sfx("card", s)

	# Kılıç: metalik çınlama + kısa gürültü + gövdeye vuruş.
	s = _noise(0.07, 0.35, 7000, 3000, 3.0)
	_mix(s, _tone(0.09, 1800, 1400, Wave.SQUARE, 0.08, 0.001, 2.0))
	_mix(s, _tone(0.08, 190, 80, Wave.SINE, 0.5))
	_save_sfx("hit", s)

	s = _tone(0.28, 130, 45, Wave.SINE, 0.8, 0.002, 1.5)
	_mix(s, _noise(0.22, 0.5, 900, 200, 2.0))
	_save_sfx("hit_heavy", s)

	s = _noise(0.13, 0.25, 3500, 700, 1.0)
	_mix(s, _tone(0.07, 320, 260, Wave.TRIANGLE, 0.35))
	_save_sfx("arrow", s)

	s = _noise(0.04, 0.35, 2600, 1200, 2.0)
	_mix(s, _tone(0.05, 320, 140, Wave.SINE, 0.4))
	_save_sfx("arrow_hit", s)

	s = _tone(0.28, 380, 950, Wave.SINE, 0.35, 0.02, 1.0, 9.0)
	_mix(s, _tone(0.28, 760, 1900, Wave.TRIANGLE, 0.12, 0.02, 1.0, 9.0))
	_save_sfx("magic", s)

	s = _noise(0.22, 0.35, 2400, 400, 1.5)
	_mix(s, _tone(0.25, 1000, 220, Wave.SINE, 0.35, 0.001, 1.2, 14.0))
	_save_sfx("magic_hit", s)

	s = _tone(0.5, 95, 38, Wave.SINE, 0.9, 0.002, 1.5)
	_mix(s, _noise(0.45, 0.7, 1500, 150, 1.5))
	_save_sfx("cannon", s)

	s = _noise(0.65, 0.8, 1800, 90, 1.3)
	_mix(s, _tone(0.6, 75, 28, Wave.SINE, 0.9, 0.002, 1.2))
	_save_sfx("explosion", s)

	# Asker düşüşü: kısa, boğuk "hık" + yere düşme.
	s = _lowpass(_tone(0.12, 230, 110, Wave.SAW, 0.3, 0.005, 1.5), 1100)
	_mix(s, _noise(0.06, 0.25, 600, 300, 2.0), 0.05)
	_save_sfx("death", s)

	s = _tone(0.45, 160, 45, Wave.SINE, 0.7, 0.002, 1.3)
	_mix(s, _noise(0.4, 0.45, 700, 120, 1.5))
	for i in 3:
		_mix(s, _tone(0.09, [440.0, 330.0, 220.0][i], [430.0, 320.0, 200.0][i], Wave.SQUARE, 0.12), i * 0.08)
	_save_sfx("squad_down", s)

	s = PackedFloat32Array()
	var arp := [330.0, 440.0, 554.0, 659.0, 880.0]
	for i in arp.size():
		_mix(s, _tone(0.3, arp[i], arp[i], Wave.TRIANGLE, 0.3, 0.005, 2.0), i * 0.065)
	_mix(s, _tone(0.6, 220, 440, Wave.SINE, 0.2, 0.05, 1.0, 6.0))
	_save_sfx("revive", s)

	s = _tone(0.16, 650, 140, Wave.SINE, 0.6, 0.002, 1.0, 22.0)
	_mix(s, _noise(0.1, 0.3, 900, 400, 2.0))
	_save_sfx("split", s)

	s = _lowpass(_tone(0.9, 110, 65, Wave.SAW, 0.6, 0.06, 1.2, 7.0), 1400)
	_mix(s, _lowpass(_tone(0.9, 82, 50, Wave.SQUARE, 0.35, 0.06, 1.2, 5.0), 900))
	_mix(s, _noise(0.8, 0.3, 800, 200, 1.0))
	_save_sfx("boss_roar", s)

	# Savaş borusu: kuint aralıklı iki boru sesi.
	s = _lowpass(_tone(0.7, 196, 200, Wave.SAW, 0.45, 0.06, 0.8, 5.0), 1300)
	_mix(s, _lowpass(_tone(0.7, 294, 300, Wave.SAW, 0.3, 0.06, 0.8, 5.0), 1300))
	_save_sfx("horn", s)

	s = PackedFloat32Array()
	var fanfare := [[523.0, 0.0, 0.12], [659.0, 0.12, 0.12], [784.0, 0.24, 0.12], [1047.0, 0.36, 0.6]]
	for n in fanfare:
		_mix(s, _tone(n[2], n[0], n[0], Wave.SQUARE, 0.22, 0.005, 1.0), n[1])
		_mix(s, _tone(n[2], n[0] / 2.0, n[0] / 2.0, Wave.TRIANGLE, 0.35, 0.005, 1.0), n[1])
	_save_sfx("victory", s)

	s = PackedFloat32Array()
	var lament := [[392.0, 0.0, 0.3], [311.0, 0.3, 0.3], [262.0, 0.6, 0.8]]
	for n in lament:
		_mix(s, _tone(n[2], n[0], n[0] * 0.98, Wave.TRIANGLE, 0.45, 0.01, 1.0, 5.0), n[1])
		_mix(s, _tone(n[2], n[0] / 2.0, n[0] / 2.0, Wave.SQUARE, 0.1, 0.01, 1.0), n[1])
	_save_sfx("defeat", s)


# --- Müzik ---
# Basit sıralayıcı: her parça akor dizisi + bas + arpej + ezgi + davul. Ezgi, akorun köküne
# göre seed'li üretilen bir motifin tekrarıdır; döngü sonunda taşan notalar başa sarılır.

const MINOR := [0, 2, 3, 5, 7, 8, 10]


func _build_music() -> void:
	# Ana menü: sakin, la minör.
	_save_music("menu", _compose({
		bpm = 88, root = 57, chords = [0, 5, 2, 6, 0, 5, 3, 4, 0, 5, 2, 6, 3, 4, 0, 0],
		bass = "whole", arp = 0.06, lead = 0.12, lead_wave = Wave.TRIANGLE, drums = "soft",
		rhythm = [1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0],
	}))
	# Savaş: hızlı, re minör.
	_save_music("battle", _compose({
		bpm = 132, root = 50, chords = [0, 5, 6, 0, 0, 5, 3, 4, 0, 5, 6, 0, 3, 5, 4, 4],
		bass = "eighths", arp = 0.05, lead = 0.1, lead_wave = Wave.SQUARE, drums = "march",
		rhythm = [1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0],
	}))
	# Boss: daha ağır ve hızlı, mi minör, bas on altılık.
	_save_music("boss", _compose({
		bpm = 148, root = 52, chords = [0, 1, 0, 6, 0, 1, 5, 4, 0, 1, 0, 6, 5, 6, 4, 4],
		bass = "sixteenths", arp = 0.04, lead = 0.11, lead_wave = Wave.SAW, drums = "heavy",
		rhythm = [1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0],
	}))


func _compose(p: Dictionary) -> PackedFloat32Array:
	var step: float = 60.0 / p.bpm / 4.0  # on altılık nota süresi
	var bars: int = p.chords.size()
	var buffer := PackedFloat32Array()
	buffer.resize(int(bars * 16 * step * RATE))
	var root: int = p.root
	# İki ölçülük motif: her vuruşta akor kökünden kaç derece yukarıda.
	var motif: Array[int] = []
	var degree := 4
	for i in 32:
		degree = clampi(degree + [-2, -1, -1, 0, 1, 1, 2][_rng.randi_range(0, 6)], 0, 9)
		motif.append(degree)

	for bar in bars:
		var chord_degree: int = p.chords[bar]
		var chord_root := root + _scale(chord_degree)
		var bar_start := bar * 16 * step
		# Bas
		match p.bass:
			"whole":
				_add_note(buffer, bar_start, step * 15, chord_root - 12, Wave.TRIANGLE, 0.35, 0.02, 0.5)
			"eighths":
				for i in 8:
					var n := chord_root - 12 + (12 if i % 4 == 3 else 0)
					_add_note(buffer, bar_start + i * 2 * step, step * 1.6, n, Wave.TRIANGLE, 0.4, 0.005, 1.2)
			"sixteenths":
				for i in 16:
					var n := chord_root - 12 + (7 if i % 8 == 6 else 0)
					_add_note(buffer, bar_start + i * step, step * 0.9, n, Wave.SAW, 0.16, 0.003, 1.5, 700.0)
		# Arpej: akorun üç notası sırayla.
		var triad := [_scale(chord_degree), _scale(chord_degree + 2), _scale(chord_degree + 4)]
		for i in 16:
			if p.drums == "soft" and i % 2 == 1:
				continue
			var n: int = root + 12 + triad[[0, 1, 2, 1][i % 4]]
			_add_note(buffer, bar_start + i * step, step * 1.5, n, Wave.SQUARE, p.arp, 0.003, 2.5)
		# Ezgi: 4 ölçülük cümlenin son ölçüsü dinlenir, cümle sonu kök notada biter.
		if bar % 4 != 3:
			var half := (bar % 2) * 16
			for i in 16:
				if p.rhythm[i] == 0:
					continue
				var length := 1
				while i + length < 16 and p.rhythm[i + length] == 0:
					length += 1
				var n := root + 12 + _scale(chord_degree + motif[half + i])
				_add_note(buffer, bar_start + i * step, step * length * 0.9, n, p.lead_wave,
						p.lead, 0.01, 0.8, 2500.0, true)
		else:
			_add_note(buffer, bar_start, step * 8, root + 12 + _scale(chord_degree), p.lead_wave,
					p.lead, 0.01, 1.0, 2500.0, true)
		# Davullar
		for i in 16:
			var t := bar_start + i * step
			match p.drums:
				"soft":
					if i % 8 == 4:
						_add_at(buffer, t, _noise(0.05, 0.08, 6000, 4000, 2.0))
				"march":
					if i % 8 == 0:
						_add_at(buffer, t, _tone(0.15, 150, 50, Wave.SINE, 0.7, 0.001, 1.5))
					if i % 8 == 4:
						_add_at(buffer, t, _noise(0.12, 0.3, 4000, 1500, 1.5))
					if i % 2 == 0:
						_add_at(buffer, t, _noise(0.03, 0.08, 8000, 6000, 2.0))
					if bar % 4 == 3 and i >= 12:  # cümle sonunda trampet dolgusu
						_add_at(buffer, t, _noise(0.08, 0.22, 3500, 1500, 2.0))
				"heavy":
					if i % 4 == 0:
						_add_at(buffer, t, _tone(0.18, 140, 40, Wave.SINE, 0.85, 0.001, 1.5))
					if i % 8 == 4:
						_add_at(buffer, t, _noise(0.15, 0.35, 3000, 900, 1.3))
					if i % 2 == 1:
						_add_at(buffer, t, _noise(0.025, 0.07, 8000, 6000, 2.0))
					if bar % 4 == 3 and i % 2 == 0 and i >= 8:  # tom dolgusu
						_add_at(buffer, t, _tone(0.12, 220 - i * 8, 90, Wave.SINE, 0.5, 0.001, 1.5))
	return _normalize(buffer, 0.85)


## Minör gamdaki derece -> kökten yarım ses farkı (oktav taşmasını da hesaplar).
func _scale(degree: int) -> int:
	var octave := floori(degree / 7.0)
	return MINOR[degree - octave * 7] + 12 * octave


func _add_note(buffer: PackedFloat32Array, start: float, length: float, midi: int, wave: Wave,
		volume: float, attack: float, decay: float, cutoff := 0.0, vibrato := false) -> void:
	var f := 440.0 * pow(2.0, (midi - 69) / 12.0)
	var note := _tone(length, f, f, wave, volume, attack, decay, 5.5 if vibrato else 0.0)
	if cutoff > 0.0:
		note = _lowpass(note, cutoff)
	_add_at(buffer, start, note)


## Notayı tampona ekler; tamponun sonunu aşan kısım başa sarılır (kesintisiz döngü).
func _add_at(buffer: PackedFloat32Array, start: float, sound: PackedFloat32Array) -> void:
	var offset := int(start * RATE)
	var n := buffer.size()
	for i in sound.size():
		buffer[(offset + i) % n] += sound[i]


# --- Sentez temel parçaları ---

## Frekansı f0'dan f1'e üstel kayan ton. Zarf: attack'ta yükselir, sonra (1-t)^decay ile söner.
## vibrato > 0 ise o hızda (Hz) hafif titreşim.
func _tone(duration: float, f0: float, f1: float, wave: Wave, volume: float,
		attack := 0.003, decay := 1.0, vibrato := 0.0) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := f0 * pow(f1 / f0, t)
		if vibrato > 0.0:
			f *= 1.0 + 0.012 * sin(TAU * vibrato * i / RATE)
		phase = fmod(phase + f / RATE, 1.0)
		var v := 0.0
		match wave:
			Wave.SINE:
				v = sin(TAU * phase)
			Wave.SQUARE:
				v = 1.0 if phase < 0.5 else -1.0
			Wave.TRIANGLE:
				v = 4.0 * absf(phase - 0.5) - 1.0
			Wave.SAW:
				v = 2.0 * phase - 1.0
			Wave.NOISE:
				v = _rng.randf_range(-1.0, 1.0)
		out[i] = v * volume * _envelope(float(i) / RATE, duration, attack, decay)
	return out


## Alçak geçiren süzgeçten geçmiş gürültü; kesim frekansı cut0'dan cut1'e kayar.
func _noise(duration: float, volume: float, cut0: float, cut1: float, decay := 1.0) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / n
		var k := 1.0 - exp(-TAU * lerpf(cut0, cut1, t) / RATE)
		y += k * (_rng.randf_range(-1.0, 1.0) - y)
		out[i] = y * volume * 2.0 * _envelope(float(i) / RATE, duration, 0.001, decay)
	return out


func _envelope(time: float, duration: float, attack: float, decay: float) -> float:
	var rise := minf(time / attack, 1.0) if attack > 0.0 else 1.0
	return rise * pow(maxf(1.0 - time / duration, 0.0), decay)


func _lowpass(sound: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var k := 1.0 - exp(-TAU * cutoff / RATE)
	var y := 0.0
	for i in sound.size():
		y += k * (sound[i] - y)
		sound[i] = y
	return sound


## b'yi a'ya `at` saniyeden itibaren ekler; a gerekirse uzar.
func _mix(a: PackedFloat32Array, b: PackedFloat32Array, at := 0.0) -> void:
	var offset := int(at * RATE)
	if a.size() < offset + b.size():
		a.resize(offset + b.size())
	for i in b.size():
		a[offset + i] += b[i]


func _normalize(sound: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var top := 0.0001
	for v in sound:
		top = maxf(top, absf(v))
	var gain := peak / top
	for i in sound.size():
		sound[i] *= gain
	return sound


func _save_sfx(sound_name: String, sound: PackedFloat32Array) -> void:
	_save(SFX_DIR + sound_name + ".wav", _normalize(sound, 0.8))


func _save_music(track: String, sound: PackedFloat32Array) -> void:
	_save(MUSIC_DIR + track + ".wav", sound)


func _save(path: String, sound: PackedFloat32Array) -> void:
	var bytes := PackedByteArray()
	bytes.resize(sound.size() * 2)
	for i in sound.size():
		bytes.encode_s16(i * 2, int(clampf(sound[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	var err := wav.save_to_wav(ProjectSettings.globalize_path(path))
	print("%s  %.1f sn  %s" % [path, sound.size() / float(RATE), error_string(err)])
