class_name Formation
## Ordu ızgarasındaki kareyi savaş alanındaki başlangıç noktasına çevirir.
## Izgaranın üst satırı (y = 0) ön cephedir: rakibe en yakın satır.
## Rakip ordu aynı ızgarayı ayna gibi kullanır (savaş alanının öbür ucunda).

const ROW_SPACING := 1.0  ## Satırlar arası mesafe (karo).
const COL_SPACING := 1.6  ## Sütunlar arası mesafe (karo).


static func grid_to_field(cell: Vector2i, grid_size: Vector2i, team: SquadState.Team) -> Vector2:
	var center_x := (Battlefield.FIELD_WIDTH - 1) / 2.0
	var front_y := float(Battlefield.FIELD_DEPTH - Battlefield.DEPLOY_ROWS)
	var x := center_x + (cell.x - (grid_size.x - 1) / 2.0) * COL_SPACING
	var y := front_y + cell.y * ROW_SPACING
	if team == SquadState.Team.ENEMY:
		y = (Battlefield.FIELD_DEPTH - 1) - y
	return Vector2(x, y)
