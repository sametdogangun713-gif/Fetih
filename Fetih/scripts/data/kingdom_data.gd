class_name KingdomData
extends Resource
## Bir krallığın verileri. Her krallık data/kingdoms/ altında bir .tres dosyasıdır.
## Birlikleri ayrıca tutulmaz: UnitCatalog.units_of(id) ile bulunur.

@export var id: StringName  ## Örnek: &"elves"
@export var display_name: String  ## Örnek: "Elfler"
@export_multiline var description: String
@export var specialty_role: StringName  ## Krallığın en iyi olduğu rol (RoleRules sabitlerinden).
## Uzmanlık bir mekanikse (Diriliş, Bölünme...) arayüzde rol adı yerine bu yazar.
@export var specialty_label: String = ""
@export var color: Color = Color.WHITE  ## Arayüzde krallık adının rengi.
## false ise kilitli başlar: koşuda boss'unu yenip (mühür) fethi tamamlayınca açılır.
@export var starts_unlocked := true
## Koşu başında verilen bölükler; her biri 100 puanlık bir bölük olur.
@export var starting_units: Array[UnitData] = []
## Krallık özelliği: koşuya bu fermanlarla başlanır (9 Kings'teki kral yetenekleri gibi).
@export var starting_passives: Array[PassiveData] = []
## Krallığın boss'u (boss savaşlarında ordusunun başında savaşır).
@export var boss: UnitData
