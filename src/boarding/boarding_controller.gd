class_name BoardingController
extends Node
## Runs a boarding between two ships: grapple, pull together, crew fight, then the fate of the prize.

signal finished(player_won: bool)

enum Stance { FULL_ASSAULT, BALANCED, HOLD_BACK }
const STANCE_FRACTION: Dictionary = {Stance.FULL_ASSAULT: 0.8, Stance.BALANCED: 0.6, Stance.HOLD_BACK: 0.3}

var attacker: Ship
var target: Ship
var stance: Stance = Stance.BALANCED
var grapple: Grapple = Grapple.new()
var sim: BoardingSim
var seed_value: int = 1
var active: bool = false
var player_won: bool = false
var _start_gap: float = 20.0


func relative_speed_kn() -> float:
	return (attacker.linear_velocity - target.linear_velocity).length() * 1.944


func angle_off_beam_deg() -> float:
	var to_t: Vector3 = target.global_position - attacker.global_position
	var right: Vector3 = attacker.global_transform.basis.x
	var a: float = rad_to_deg(acos(clampf(absf(to_t.normalized().dot(right)), 0.0, 1.0)))
	return a


func can_start() -> bool:
	return Grapple.can_grapple(attacker.global_position.distance_to(target.global_position), relative_speed_kn(), angle_off_beam_deg())


## Feed the grapple button each physics frame. Once hooks are thrown the ships are pulled together.
func process_grapple(held: bool, delta: float) -> void:
	if active or not can_start():
		return
	if held:
		if grapple.hold(delta):
			_start_gap = attacker.global_position.distance_to(target.global_position)
	else:
		grapple.release()


func _physics_process(delta: float) -> void:
	if attacker == null or target == null:
		return
	if not grapple.lines.is_empty() and not active:
		grapple.tick(delta)
		if grapple.is_locked():
			_begin_fight()
	elif active:
		sim.tick(delta)
		if sim.outcome != BoardingSim.Outcome.ONGOING:
			_end_fight()


func _begin_fight() -> void:
	active = true
	var a_n: int = int(round(attacker.crew.count * STANCE_FRACTION[stance]))
	var d_n: int = int(round(target.crew.count * (1.0 + target.stats.boarding_defense)))
	sim = BoardingSim.new(BoardingSide.new(a_n, attacker.crew.quality, attacker.crew.morale), BoardingSide.new(d_n, target.crew.quality, target.crew.morale), seed_value)


func _end_fight() -> void:
	active = false
	player_won = sim.outcome == BoardingSim.Outcome.ATTACKER_WINS
	attacker.crew.count = maxi(int(round(sim.attacker.pool)) + (attacker.crew.count - int(round(attacker.crew.count * STANCE_FRACTION[stance]))), 1)
	if player_won:
		target.crew.count = maxi(int(round(sim.defender.pool)), 0)
		target.surrender()
	finished.emit(player_won)
