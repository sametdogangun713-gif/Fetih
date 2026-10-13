extends SceneTree
## Denge testi: her birliği her birliğe karşı eşit bütçeyle, ekran olmadan savaştırır.
##
## Çalıştırma (proje klasöründen):
##   powershell -File tools/run_balance_test.ps1
## veya doğrudan:
##   godot --headless --path Fetih -s res://tools/balance_test.gd -- --seeds=10 --budget=100
##
## Rapor: tools/reports/balance_latest.md
##
## Puan (skor): bir savaşta kazananın kalan can oranı (+ ise satırdaki birlik kazandı).
## Örnek: +0.40 = satırdaki birlik ortalama canının %40'ı ile kazanıyor.

const REPORT_PATH := "res://tools/reports/balance_latest.md"
## Oyundaki gibi: bölükler 3x3 ızgaraya rollerine göre dizilir (ArmyGenerator.auto_arrange),
## sonra Formation ile savaş alanına yerleşir. Böylece başlangıç mesafeleri gerçek oyunla aynıdır.
const GRID_SIZE := Vector2i(3, 3)
const SQUADS_PER_SIDE := 2
const FIELD_RECT := Rect2(0, 0, Battlefield.FIELD_WIDTH - 1, Battlefield.FIELD_DEPTH - 1)

## Bu aralığın dışındaki genel kazanma oranı "dengesiz" sayılır.
const FAIR_MIN := 0.35
const FAIR_MAX := 0.65
## Karşılık eşleşmesinde avantajlı tarafın en az bu oranla kazanması beklenir.
const COUNTER_MIN := 0.65

var seeds := 10
var budget := 100.0
var units: Array[UnitData] = []
var win_rate := []  ## [i][j]: i'nin j'ye karşı kazanma oranı
var score := []  ## [i][j]: ortalama puan
var avg_time := []  ## [i][j]: ortalama savaş süresi
var battle_count := 0


func _init() -> void:
	_parse_args()
	units = UnitCatalog.all()
	print("Denge testi: %d birlik, eşleşme başına %d seed x 2 taraf, bölük bütçesi %d" % [
			units.size(), seeds, budget])
	var started := Time.get_ticks_msec()
	_run_all()
	var report := _build_report()
	_save_report(report)
	print(report)
	print("Toplam %d savaş, %.1f sn. Rapor: %s" % [
			battle_count, (Time.get_ticks_msec() - started) / 1000.0, REPORT_PATH])
	units.clear()
	UnitCatalog.clear_cache()
	quit()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--budget="):
			budget = arg.get_slice("=", 1).to_float()


func _run_all() -> void:
	var n := units.size()
	for i in n:
		win_rate.append([])
		score.append([])
		avg_time.append([])
		for j in n:
			win_rate[i].append(0.5)
			score[i].append(0.0)
			avg_time[i].append(0.0)
	for i in n:
		for j in range(i + 1, n):
			var result := _matchup(units[i], units[j])
			win_rate[i][j] = result[0]
			win_rate[j][i] = 1.0 - result[0]
			score[i][j] = result[1]
			score[j][i] = -result[1]
			avg_time[i][j] = result[2]
			avg_time[j][i] = result[2]


## a ile b'yi seeds x 2 kez savaştırır (her iki tarafta da). [a kazanma oranı, a puanı, ort. süre]
func _matchup(a: UnitData, b: UnitData) -> Array:
	var wins := 0
	var total_score := 0.0
	var total_time := 0.0
	var battles := 0
	for seed_value in range(1, seeds + 1):
		for a_is_player in [true, false]:
			var player := a if a_is_player else b
			var enemy := b if a_is_player else a
			var result := _fight(player, enemy, seed_value)
			var a_won: bool = (result[0] == SquadState.Team.PLAYER) == a_is_player
			if a_won:
				wins += 1
			total_score += result[1] if a_won else -result[1]
			total_time += result[2]
			battles += 1
	battle_count += battles
	return [float(wins) / battles, total_score / battles, total_time / battles]


## Tek savaş. [kazanan takım, kazananın kalan can oranı, süre]
func _fight(player: UnitData, enemy: UnitData, seed_value: int) -> Array:
	var sim := BattleSimulation.new(seed_value, FIELD_RECT)
	_deploy(sim, player, SquadState.Team.PLAYER)
	_deploy(sim, enemy, SquadState.Team.ENEMY)
	while not sim.finished:
		sim.step()

	var remaining := 0.0
	var starting := 0.0
	for squad in sim.squads:
		if squad.team == sim.winner:
			remaining += squad.hp_pool
			starting += squad.unit.hp * squad.max_count
	var result := [sim.winner, remaining / starting, sim.elapsed]
	sim.dispose()
	return result


func _deploy(sim: BattleSimulation, unit: UnitData, team: SquadState.Team) -> void:
	var army: Array[ArmySquad] = []
	for i in SQUADS_PER_SIDE:
		army.append(ArmySquad.new(unit, UnitCatalog.count_for_budget(unit, budget), ArmyGenerator.NO_CELL))
	ArmyGenerator.auto_arrange(army, GRID_SIZE)
	for squad in army:
		sim.add_squad(SquadState.new(unit, team, squad.count,
				Formation.grid_to_field(squad.cell, GRID_SIZE, team)))


func _build_report() -> String:
	var n := units.size()
	var lines: PackedStringArray = []
	lines.append("# Denge raporu")
	lines.append("")
	lines.append("- Tarih: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("- Eşleşme başına %d seed x 2 taraf, bölük bütçesi %d, taraf başına %d bölük" % [
			seeds, budget, SQUADS_PER_SIDE])
	lines.append("- Toplam %d savaş" % battle_count)
	lines.append("")

	# 1) Birlik özeti
	lines.append("## Birlikler (genel güç)")
	lines.append("")
	lines.append("Genel kazanma: tüm diğer birliklere karşı ortalama. Hedef: %%%d - %%%d." % [
			FAIR_MIN * 100, FAIR_MAX * 100])
	lines.append("")
	lines.append("| Birlik | Krallık | Rol | Asker | Genel kazanma | Ort. puan | Durum |")
	lines.append("|---|---|---|---|---|---|---|")
	for i in n:
		var unit := units[i]
		var overall := _row_average(win_rate, i)
		var status := "dengeli"
		if overall > FAIR_MAX:
			status = "**GÜÇLÜ**"
		elif overall < FAIR_MIN:
			status = "**ZAYIF**"
		lines.append("| %s | %s | %s | %d | %%%d | %+.2f | %s |" % [
				unit.display_name, unit.kingdom, RoleRules.ROLE_NAMES[unit.role],
				UnitCatalog.count_for_budget(unit, budget), roundi(overall * 100),
				_row_average(score, i), status])
	lines.append("")

	# 2) Krallık özeti
	lines.append("## Krallıklar")
	lines.append("")
	lines.append("| Krallık | Ort. genel kazanma |")
	lines.append("|---|---|")
	for kingdom in UnitCatalog.KINGDOM_ORDER:
		var total := 0.0
		var count := 0
		for i in n:
			if units[i].kingdom == kingdom:
				total += _row_average(win_rate, i)
				count += 1
		if count > 0:
			lines.append("| %s | %%%d |" % [kingdom, roundi(total / count * 100)])
	lines.append("")

	# 3) Karşılık kontrolü
	lines.append("## Karşılık kontrolü")
	lines.append("")
	lines.append("Avantajlı birliğin en az %%%d kazanması beklenir." % [COUNTER_MIN * 100])
	lines.append("")
	lines.append("| Avantajlı | Karşı | Kazanma | Durum |")
	lines.append("|---|---|---|---|")
	var counter_ok := 0
	var counter_total := 0
	for i in n:
		for j in n:
			if not RoleRules.has_advantage(units[i].role, units[j].role):
				continue
			counter_total += 1
			var ok: bool = win_rate[i][j] >= COUNTER_MIN
			if ok:
				counter_ok += 1
			lines.append("| %s | %s | %%%d | %s |" % [units[i].display_name, units[j].display_name,
					roundi(win_rate[i][j] * 100), "tamam" if ok else "**TUTMUYOR**"])
	lines.append("")
	lines.append("Tutan karşılık: %d / %d" % [counter_ok, counter_total])
	lines.append("")

	# 4) Kazanma matrisi
	lines.append("## Kazanma matrisi (satır, sütuna karşı)")
	lines.append("")
	var header := "| |"
	var divider := "|---|"
	for j in n:
		header += " %d |" % (j + 1)
		divider += "---|"
	lines.append(header)
	lines.append(divider)
	for i in n:
		var row := "| %d. %s |" % [i + 1, units[i].display_name]
		for j in n:
			row += " - |" if i == j else " %d |" % roundi(win_rate[i][j] * 100)
		lines.append(row)
	lines.append("")
	return "\n".join(lines)


func _row_average(matrix: Array, i: int) -> float:
	var total := 0.0
	for j in units.size():
		if j != i:
			total += matrix[i][j]
	return total / (units.size() - 1)


func _save_report(report: String) -> void:
	var path := ProjectSettings.globalize_path(REPORT_PATH)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(report)
	else:
		push_error("Rapor yazılamadı: " + path)
