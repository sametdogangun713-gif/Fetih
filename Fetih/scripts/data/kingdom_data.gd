class_name KingdomData
extends Resource
## Bir krallığın verileri. Her krallık data/kingdoms/ altında bir .tres dosyasıdır.
## Birlikleri ayrıca tutulmaz: UnitCatalog.units_of(id) ile bulunur.

@export var id: StringName  ## Örnek: &"elves"
@export var display_name: String  ## Örnek: "Elfler"
@export_multiline var description: String
@export var specialty_role: StringName  ## Krallığın en iyi olduğu rol (RoleRules sabitlerinden).
@export var color: Color = Color.WHITE  ## Arayüzde krallık adının rengi.
## Koşu başında verilen bölükler; her biri 100 puanlık bir bölük olur.
@export var starting_units: Array[UnitData] = []
