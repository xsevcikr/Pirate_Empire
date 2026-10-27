class_name BoardingSim
extends RefCounted
## Crew-pool abstraction of a deck fight. Each side is a pool of men; every STEP_S seconds each side
## inflicts casualties proportional to its fighters (Lanchester square law) with random variance.

const STEP_S: float = 2.0
const CASUALTY_RATE: float = 0.045
const VARIANCE: float = 0.9
const PLAYER_KILL_VALUE: float = 3.0
const MORALE_BREAK: float = 20.0
const CAPTAIN_BREAK_MORALE_DROP: float = 0.5
const TIME_LIMIT_S: float = 120.0

enum Outcome { ONGOING, ATTACKER_WINS, DEFENDER_WINS }

var attacker: BoardingSide
var defender: BoardingSide
var time_s: float = 0.0
var outcome: Outcome = Outcome.ONGOING
var surrendered: bool = false
var _acc: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var player_kills: int = 0


func _init(a: BoardingSide, d: BoardingSide, seed_value: int = 1) -> void:
	attacker = a
	defender = d
	_rng.seed = seed_value


## Player cut down `n` enemies on the deck; each is worth extra men from their pool.
func player_kill(n: int = 1) -> void:
	player_kills += n
	defender.pool = maxf(defender.pool - PLAYER_KILL_VALUE * n, 0.0)


func tick(delta: float) -> Outcome:
	if outcome != Outcome.ONGOING:
		return outcome
	time_s += delta
	_acc += delta
	while _acc >= STEP_S and outcome == Outcome.ONGOING:
		_acc -= STEP_S
		_step()
	return outcome


func _roll() -> float:
	return 1.0 + _rng.randf_range(-VARIANCE, VARIANCE)


func _step() -> void:
	var da: float = minf(CASUALTY_RATE * attacker.power() * _roll(), defender.pool)
	var dd: float = minf(CASUALTY_RATE * defender.power() * _roll(), attacker.pool)
	defender.pool -= da
	attacker.pool -= dd
	_morale_hit(defender, da)
	_morale_hit(attacker, dd)
	_resolve()


func _morale_hit(s: BoardingSide, casualties: float) -> void:
	s.morale = maxf(s.morale - casualties / maxf(s.start, 1.0) * 40.0, 0.0)


func _resolve() -> void:
	if defender.pool < 0.5:
		outcome = Outcome.ATTACKER_WINS
	elif attacker.pool < 0.5:
		outcome = Outcome.DEFENDER_WINS
	elif defender.morale < MORALE_BREAK and defender.pool < attacker.pool:
		outcome = Outcome.ATTACKER_WINS
		surrendered = true
	elif attacker.morale < MORALE_BREAK and attacker.pool < defender.pool:
		outcome = Outcome.DEFENDER_WINS
		surrendered = true
	elif time_s >= TIME_LIMIT_S:
		outcome = Outcome.ATTACKER_WINS if attacker.power() >= defender.power() else Outcome.DEFENDER_WINS
		surrendered = true


## Defeating the enemy captain drops the remaining crew's morale by 50%.
func captain_defeated() -> void:
	defender.captain_alive = false
	defender.morale *= (1.0 - CAPTAIN_BREAK_MORALE_DROP)
	_resolve()
