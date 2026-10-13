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
## Krallık boss'u: tek askerli dev kahraman. data/bosses/ altında durur; kart havuzuna girmez.
@export var is_boss := false
## Yanma: vuruşun verdiği hasarın bu oranı kadar ek ateş hasarı 3 saniyeye yayılarak işler.
@export var burn_ratio := 0.0
## Yavaşlatma: vurduğu bölüğün hareket ve saldırı hızı 2 saniye bu oranda düşer (0.3 = %30).
@export var slow_amount := 0.0
## Onarım: bölük saniyede en fazla toplam canının bu oranı kadar iyileşir (0.02 = %2/sn).
@export var regen_ratio := 0.0
## Diriliş: bölük ilk kez yok olunca toplam canının bu oranıyla bir kez geri kalkar.
@export var revive_ratio := 0.0
## Bölünme: bölük yok olunca yarı can ve yarı hasarlı iki küçük bölüğe ayrılır (bir kez).
@export var splits := false

@export_group("Görünüm")
## Birliğin ana rengi: koddan üretilen sprite'ı boyar, arayüzde birliği belirtir.
@export var placeholder_color: Color = Color.WHITE
## Gerçek çizim: yan yana 4 eşit kare (durma, yürüme A, yürüme B, saldırı), figür sağa bakar.
## Boşsa sprite role göre koddan üretilir (bkz. UnitSprites).
@export var sprite_sheet: Texture2D


func is_ranged() -> bool:
	return attack_range > 1.5
