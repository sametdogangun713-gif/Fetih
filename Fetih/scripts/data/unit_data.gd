class_name UnitData
extends Resource
## Bir birlik türünün değişmeyen verileri. Her birlik türü data/units/ altında bir .tres dosyasıdır.
## Denge ayarı kodda değil, bu dosyalardaki sayılarda yapılır.

@export var id: StringName  ## Örnek: &"elf_archer"
@export var kingdom: StringName  ## Örnek: &"elves"
@export var role: StringName  ## Örnek: &"archer"
@export var display_name: String  ## Örnek: "Elf Okçusu"

@export_group("Savaş")
@export var hp: float = 10.0  ## Tek askerin canı.
@export var damage: float = 3.0  ## Tek askerin bir vuruştaki hasarı.
@export var attack_speed: float = 1.0  ## Saniyedeki saldırı sayısı.
## Karo cinsinden, iki bölüğün kenarları arası mesafe. Yakın dövüş ~0.25, okçu ~5.
@export var attack_range: float = 0.25
@export var move_speed: float = 1.0  ## Saniyede kaç karo yürür.
@export var armor: float = 0.0  ## Gelen her vuruştan düşülen hasar.

@export_group("Görünüm")
@export var placeholder_color: Color = Color.WHITE  ## Gerçek sprite gelene kadar asker rengi.


func is_ranged() -> bool:
	return attack_range > 1.5
