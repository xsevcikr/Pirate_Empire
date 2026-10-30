class_name BoardingController
extends Node
## Runs a boarding between two ships: grapple, pull together, crew fight, then the fate of the prize.

signal finished(player_won: bool)
signal deck_started(deck: DeckCombat)

enum Stance { FULL_ASSAULT, BALANCED, HOLD_BACK }
## The captain on deck is worth this many ordinary men in the crew-pool fight (PLAYER_KILL_VALUE precedent).
const CAPTAIN_FIGHT_VALUE: float = 4.0
const STANCE_FRACTION: Dictionary = {Stance.FULL_ASSAULT: 0.8, Stance.BALANCED: 0.6, Stance.HOLD_BACK: 0.3}

var attacker: Ship
var target: Ship
var stance: Stance = Stance.BALANCED
var grapple: Grapple = Grapple.new()
var sim: BoardingSim
var seed_value: int = 1
var active: bool = false
var player_won: bool = false
var _defenders_at_start: int = 0
## Fight the boarding as a real-time deck battle (M14) instead of the crew-pool abstraction. With `deck_driven`
## false the captain plays himself through DeckBridge.autopilot; a DeckFightScene sets it true and ticks the deck.
var use_deck: bool = false
var deck_driven: bool = false
var deck: DeckCombat
var deck_result: Dictionary = {}
var game_state: Dictionary = {}
var _start_gap: float = 20.0
var _committed: int = 0


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
	elif active and deck != null:
		if not deck_driven:
			DeckBridge.autopilot(deck, delta)
			deck.tick(delta)
	elif active:
		sim.tick(delta)
		if sim.outcome != BoardingSim.Outcome.ONGOING:
			_end_fight()


func _begin_fight() -> void:
	active = true
	if use_deck:
		_begin_deck_fight()
		return
	var a_n: int = int(round(attacker.crew.count * STANCE_FRACTION[stance]))
	var d_n: int = int(round(target.crew.count * (1.0 + target.stats.boarding_defense)))
	_committed = a_n
	_defenders_at_start = d_n
	var attack_side := BoardingSide.new(a_n, attacker.crew.quality * Progression.stat(Session.state, "boarding_strength_mult"), attacker.crew.morale)
	attack_side.pool += attacker.crew.captain_hands * CAPTAIN_FIGHT_VALUE
	attack_side.start = attack_side.pool
	sim = BoardingSim.new(attack_side, BoardingSide.new(d_n, target.crew.quality, target.crew.morale), seed_value)


func _begin_deck_fight() -> void:
	_committed = int(round(attacker.crew.count * STANCE_FRACTION[stance]))
	var d_n: int = int(round(target.crew.count * (1.0 + target.stats.boarding_defense)))
	_defenders_at_start = d_n
	deck = DeckBridge.build(_committed, attacker.crew.quality * Progression.stat(game_state, "boarding_strength_mult"), attacker.crew.morale, str(target.get_meta("deck_faction", target.faction)), d_n, target.crew.quality,
		target.crew.morale, game_state, seed_value)
	deck.finished.connect(_on_deck_finished)
	sim = deck.sim
	deck_started.emit(deck)


func _on_deck_finished(result: Dictionary) -> void:
	active = false
	player_won = bool(result["player_won"])
	deck_result = result
	var reserve: int = attacker.crew.count - _committed
	attacker.crew.count = maxi(int(result["crew_left"]) + reserve, 1)  # the captain is not counted in the crew
	if not game_state.is_empty():
		CaptainHealth.after_fight(game_state, result)
	attacker.damage.patch_hull(float(result.get("hull_repaired", 0.0)))
	if player_won:
		target.crew.count = maxi(int(result["enemy_left"]), 0)
		target.surrender()
	_announce(player_won, int(result.get("parries", 0)))
	if not deck_driven:
		finished.emit(player_won)


## Tells progression how the fight went; "outnumbered" is five or more defenders against fewer attackers.
func _announce(won: bool, parries: int) -> void:
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.boarding_resolved.emit(won, parries, _defenders_at_start >= 5 and _defenders_at_start > _committed)


## A DeckFightScene calls this once its result banner is gone.
func complete_deck_fight() -> void:
	finished.emit(player_won)


func _end_fight() -> void:
	active = false
	player_won = sim.outcome == BoardingSim.Outcome.ATTACKER_WINS
	var captain_pool: float = attacker.crew.captain_hands * CAPTAIN_FIGHT_VALUE
	var committed: int = int(round(attacker.crew.count * STANCE_FRACTION[stance]))
	var reserve: int = attacker.crew.count - committed
	if captain_pool > 0.0:
		var left_fraction: float = clampf(sim.attacker.pool / maxf(sim.attacker.start, 0.001), 0.0, 1.0)
		attacker.crew.count = int(round(committed * left_fraction)) + reserve
	else:
		attacker.crew.count = maxi(int(round(sim.attacker.pool)) + reserve, 1)
	if player_won:
		target.crew.count = maxi(int(round(sim.defender.pool)), 0)
		target.surrender()
	_announce(player_won, 0)
	finished.emit(player_won)
