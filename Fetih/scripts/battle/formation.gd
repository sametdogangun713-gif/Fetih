class_name Formation
## Bölük konumları. Her ordu kendi yerleşim bölgesinde "bölge koordinatı" kullanır:
## x = cephe boyunca (0..FIELD_WIDTH-1), y = derinlik (0 = ön, rakibe en yakın).
## Rakip ordu aynı koordinatı ayna gibi kullanır (savaş alanının öbür ucunda).
## Otomatik dizilim 3x3 ızgarayı kullanır (cell_to_deploy); oyuncu bölüğü serbestçe taşıyabilir.

const ROW_SPACING := 1.0  ## Izgara satırları arası (karo).
const COL_SPACING := 1.6  ## Izgara sütunları arası (karo).
const DEPLOY_DEPTH := 2.9  ## Bölge derinliği: ızgara sıraları 0, 1, 2 bunun içinde.
const MIN_GAP := 1.0  ## İki bölük merkezi arası en az mesafe (formasyon ~1 karo yayılır).
const FRONT_Y := float(Battlefield.FIELD_DEPTH - Battlefield.DEPLOY_ROWS)


static func cell_to_deploy(cell: Vector2i, grid_size: Vector2i) -> Vector2:
	var center_x := (Battlefield.FIELD_WIDTH - 1) / 2.0
	return Vector2(center_x + (cell.x - (grid_size.x - 1) / 2.0) * COL_SPACING, cell.y * ROW_SPACING)


static func deploy_to_field(pos: Vector2, team: SquadState.Team) -> Vector2:
	var y := FRONT_Y + pos.y
	if team == SquadState.Team.ENEMY:
		y = (Battlefield.FIELD_DEPTH - 1) - y
	return Vector2(pos.x, y)


## Oyuncu tarafı: savaş alanı koordinatı -> bölge koordinatı (sürükleme için).
static func field_to_deploy(p: Vector2) -> Vector2:
	return Vector2(p.x, p.y - FRONT_Y)


static func clamp_deploy(pos: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, 0.0, Battlefield.FIELD_WIDTH - 1), clampf(pos.y, 0.0, DEPLOY_DEPTH))


## pos boşsa kendisi; değilse en yakın boş nokta (halkalarla aranır, deterministik).
static func nearest_free(pos: Vector2, others: Array[Vector2]) -> Vector2:
	pos = clamp_deploy(pos)
	if _is_free(pos, others):
		return pos
	for ring in range(1, 40):
		var radius := ring * 0.25
		var steps := 8 * ring
		for i in steps:
			var p := clamp_deploy(pos + Vector2.from_angle(TAU * i / steps) * radius)
			if _is_free(p, others):
				return p
	return pos


static func _is_free(pos: Vector2, others: Array[Vector2]) -> bool:
	for o in others:
		if pos.distance_to(o) < MIN_GAP - 0.001:
			return false
	return true
