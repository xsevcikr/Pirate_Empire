class_name TownWalker
extends Node3D
## A townsperson who lives in the street: walks between places (the well, a stall, a door, the church), stops and
## stands, and when two meet at the same place they turn to face each other as if talking. Guards pace a beat.
## The man's own state is a FighterState, shown by DeckFighterView, so he walks, breathes and turns like any crew.

const SPEED_MS: float = 1.25
const WAIT_MIN_S: float = 2.0
const WAIT_MAX_S: float = 7.0

var fighter := FighterState.new()
var places: Array[Vector3] = []
var rng := RandomNumberGenerator.new()
var _target: Vector3
var _wait: float = 0.0
var _view: DeckFighterView
var talking_to: TownWalker = null
## Street towns: every walk goes to the square first and out along one street, so nobody cuts through a house.
var hub_routing: bool = false
var hub: Vector3 = Vector3.ZERO
var _via_hub: bool = false
var _face: Vector2 = Vector2.ZERO  ## someone (the captain) this one turns to while it talks
var _bubble: Label3D
var _bubble_t: float = 0.0


func setup(kind: String, id: int, spots: Array[Vector3], seed_v: int) -> void:
	fighter.id = id
	fighter.kind = kind
	fighter.melee = "halberd" if kind == "guard" else "none"
	fighter.ranged = ""
	places = spots
	rng.seed = seed_v
	var p: Vector3 = spots[rng.randi_range(0, spots.size() - 1)]
	fighter.pos = Vector2(p.x + rng.randf_range(-1.5, 1.5), p.z + rng.randf_range(-1.5, 1.5))
	_target = p
	_wait = rng.randf_range(0.0, 3.0)


func _ready() -> void:
	_view = DeckFighterView.new()
	_view.fighter = fighter
	_view.show_label = false
	_view.pose_idle_only = true
	add_child(_view)


func pos3() -> Vector3:
	return Vector3(fighter.pos.x, 0.0, fighter.pos.y)


func _process(delta: float) -> void:
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0 and _bubble != null:
			_bubble.visible = false
	if _wait > 0.0:
		_wait -= delta
		fighter.move_intent = Vector2.ZERO
		var look: Vector2 = _face
		if talking_to != null and is_instance_valid(talking_to):
			look = talking_to.fighter.pos
		var to: Vector2 = look - fighter.pos
		if look != Vector2.ZERO and to.length() > 0.1:
			fighter.dir = fighter.dir.lerp(to.normalized(), clampf(delta * 4.0, 0.0, 1.0)).normalized()
		if _wait <= 0.0:
			talking_to = null
			_face = Vector2.ZERO
			_target = next_target()
		return
	var to_t: Vector2 = Vector2(_target.x, _target.z) - fighter.pos
	if to_t.length() < 0.35:
		_wait = rng.randf_range(WAIT_MIN_S, WAIT_MAX_S)
		return
	var dir: Vector2 = to_t.normalized()
	fighter.dir = fighter.dir.lerp(dir, clampf(delta * 6.0, 0.0, 1.0)).normalized()
	fighter.pos += dir * SPEED_MS * delta


## Where to walk next: any of the places, or with hub routing the square and a place by turns.
func next_target() -> Vector3:
	var jitter := Vector3(rng.randf_range(-2.0, 2.0), 0.0, rng.randf_range(-2.0, 2.0))
	if hub_routing:
		_via_hub = not _via_hub
		if _via_hub:
			return hub + jitter
		return places[rng.randi_range(0, places.size() - 1)]
	return places[rng.randi_range(0, places.size() - 1)] + jitter


## The captain spoke to this one: it stops, turns to `at` and says `line` in a bubble over its head.
func greet(at: Vector2, line: String) -> void:
	_face = at
	talking_to = null
	_wait = maxf(_wait, 4.0)
	if _bubble == null:
		_bubble = Label3D.new()
		_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bubble.font_size = 48
		_bubble.pixel_size = 0.01
		_bubble.outline_size = 12
		_bubble.width = 600.0
		_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_bubble.no_depth_test = true
		add_child(_bubble)
	_bubble.text = line
	_bubble.position = Vector3(fighter.pos.x, 2.6, fighter.pos.y)
	_bubble.visible = true
	_bubble_t = 4.0


func is_talking() -> bool:
	return _bubble != null and _bubble.visible


## Two walkers who stand within three metres of each other start talking.
static func pair_up(walkers: Array[TownWalker]) -> int:
	var pairs: int = 0
	for a in walkers:
		if a._wait <= 0.0 or a.talking_to != null:
			continue
		for b in walkers:
			if b != a and b._wait > 0.0 and b.talking_to == null and a.fighter.pos.distance_to(b.fighter.pos) < 3.0:
				a.talking_to = b
				b.talking_to = a
				pairs += 1
				break
	return pairs
