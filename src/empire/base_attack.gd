class_name BaseAttack
extends RefCounted
## A rival assault on a base. The base holds if its defence rating covers the threat; otherwise it falls after 4 minutes.

const WARNING_S: float = 180.0
const FALL_TIME_S: float = 240.0
const GOODS_LOSS: float = 0.30

var base: Base
var threat: float = 100.0
var elapsed_s: float = 0.0
var warned: bool = false
var resolved: bool = false
var base_fell: bool = false
var defended: bool = false


func _init(b: Base, t: float) -> void:
	base = b
	threat = t


## Attackers choose targets whose defence is below their threat.
static func will_attack(b: Base, t: float) -> bool:
	return b.defence_rating() < t


func tick(delta: float, rng: RandomNumberGenerator) -> void:
	if resolved:
		return
	elapsed_s += delta
	if elapsed_s >= WARNING_S:
		warned = true
	if base.defence_rating() >= threat:
		defended = true
		resolved = true
		return
	if elapsed_s >= WARNING_S + FALL_TIME_S:
		resolved = true
		base_fell = true
		base.fallen = true
		base.stored_goods *= 1.0 - GOODS_LOSS
		base.damage_random_building(rng)
