class_name RoleRules
## Roller ve aralarındaki karşılık tablosu (taş-kağıt-makas).
## Her rol bir rolü yener; avantajlı taraf o role COUNTER_BONUS kadar fazla hasar verir.

const WARRIOR := &"warrior"
const SPEARMAN := &"spearman"
const TANK := &"tank"
const ARCHER := &"archer"
const MAGE := &"mage"
const CAVALRY := &"cavalry"

## Raporlarda ve listelerde kullanılan sıra.
const ROLE_ORDER: Array[StringName] = [WARRIOR, SPEARMAN, TANK, ARCHER, MAGE, CAVALRY]

const ROLE_NAMES := {
	WARRIOR: "Savaşçı",
	SPEARMAN: "Mızrakçı",
	TANK: "Tank",
	ARCHER: "Okçu",
	MAGE: "Büyücü",
	CAVALRY: "Süvari",
}

## anahtar rol -> yendiği rol
const COUNTERS := {
	SPEARMAN: CAVALRY,  # hızlı gelen süvari mızrağa çarpar
	CAVALRY: ARCHER,  # arka sıraya dalar
	ARCHER: MAGE,  # büyücünün canı az, menzili kısa
	MAGE: TANK,  # büyü zırhı deler
	TANK: WARRIOR,  # savaşçı zırhta tıkanır
	WARRIOR: SPEARMAN,  # yakın dövüşte mızrak hantal
}

const COUNTER_BONUS := 1.25


static func has_advantage(attacker_role: StringName, target_role: StringName) -> bool:
	return COUNTERS.get(attacker_role) == target_role
