class_name CardOffer
extends RefCounted
## Savaştan sonra sunulan bir kart. Üç tür:
## - UNIT: savaşılan krallıktan birlik ("20 Elf Okçusu"). Orduda aynı birlik varsa o bölüğe takviye olur.
## - UPGRADE: ordundaki bir bölüğe Saldırı / Savunma / Takviye seviyesi.
## - PASSIVE: savaşılan krallığın fermanı; koşu boyunca kalıcı ordu bonusu.

enum Kind { UNIT, UPGRADE, PASSIVE }

var kind: Kind
var unit: UnitData  ## UNIT
var target: ArmySquad  ## UPGRADE
var upgrade: ArmySquad.Upgrade  ## UPGRADE
var passive: PassiveData  ## PASSIVE


static func unit_card(p_unit: UnitData) -> CardOffer:
	var card := CardOffer.new()
	card.kind = Kind.UNIT
	card.unit = p_unit
	return card


static func upgrade_card(p_target: ArmySquad, p_upgrade: ArmySquad.Upgrade) -> CardOffer:
	var card := CardOffer.new()
	card.kind = Kind.UPGRADE
	card.target = p_target
	card.upgrade = p_upgrade
	return card


static func passive_card(p_passive: PassiveData) -> CardOffer:
	var card := CardOffer.new()
	card.kind = Kind.PASSIVE
	card.passive = p_passive
	return card
