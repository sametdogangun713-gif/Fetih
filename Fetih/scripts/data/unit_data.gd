class_name UnitData
extends Resource
## Bir birlik türünün değişmeyen verileri. Her birlik türü data/units/ altında bir .tres dosyasıdır.
## Denge ayarı kodda değil, bu dosyalardaki sayılarda yapılır.

@export var id: StringName  ## Örnek: &"elf_archer"
@export var kingdom: StringName  ## Örnek: &"elves"
@export var role: StringName  ## RoleRules sabitlerinden biri. Örnek: &"archer"
@export var display_name: String  ## Örnek: "Elf Okçusu"
## Bir askerin güç puanı. Bütçe bu sayıya bölünerek asker sayısı bulunur
## (100 puanlık bölük, maliyeti 5 olan birlikten 20 asker eder).
@export var cost: float = 5.0

@export_group("Savaş")
@export var hp: float = 10.0  ## Tek askerin canı.
@export var damage: float = 3.0  ## Tek askerin bir vuruştaki hasarı.
@export var attack_speed: float = 1.0  ## Saniyedeki saldırı sayısı.
## Karo cinsinden, iki bölüğün kenarları arası mesafe. Yakın dövüş ~0.25, okçu ~5.
@export var attack_range: float = 0.25
@export var move_speed: float = 1.0  ## Saniyede kaç karo yürür.
## Hasarı armor / (armor + 5) oranında azaltır: 1 zırh = %17, 3 = %38, 5 = %50.
@export var armor: float = 0.0

@export_group("Özel")
@export var ignores_armor := false  ## Büyü: hedefin zırhını yok sayar.
## 0'dan büyükse, hedefin bu kadar yakınındaki diğer düşman bölüklerine de yarım hasar verir (karo).
@export var splash_radius := 0.0
## 1'den büyükse, en az 2 karo koşup yaptığı ilk vuruş bu kat güçlüdür (hücum).
@export var charge_multiplier := 1.0
@export var prefers_ranged_targets := false  ## Önce okçu ve büyücüleri hedefler.

@export_group("Görünüm")
@export var placeholder_color: Color = Color.WHITE  ## Gerçek sprite gelene kadar asker rengi.


func is_ranged() -> bool:
	return attack_range > 1.5
