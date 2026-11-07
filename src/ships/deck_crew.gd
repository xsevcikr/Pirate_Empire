class_name DeckCrew
extends Node3D
## The people you can see on a ship at sea: the captain at the helm and a share of the crew at their stations,
## some of them walking a beat between the rail and the mast. Every ship carries them, ours and the others, so a
## navy frigate shows marines and a pirate sloop shows cutthroats. Other ships only put people on deck while the
## camera is close enough to make them out, to keep big battles inside the frame budget.

const MAX_PLAYER_HANDS: int = 9
const MAX_AI_HANDS: int = 6
const AI_SHOW_M: float = 320.0  ## other ships show their people within this range of the camera
const LOD_EVERY_S: float = 0.5
const SPAWN_PER_FRAME: int = 2  ## figures load a character model each; stage them across frames
const FIGURE_SCALE: float = 1.15  ## a touch larger than life, so they read from the chase camera
## Who crews another ship, by its faction; the list repeats when the ship has more hands than names.
const AI_CREW: Dictionary = {
	"navy": ["marine", "sailor", "marine", "officer", "sailor", "marine"],
	"merchant": ["sailor", "sailor", "brawler", "sailor", "sailor", "sailor"],
	"pirate": ["brawler", "sailor", "brute", "sailor", "brawler", "sailor"],
}
const PLAYER_CREW: Array[String] = ["seasoned", "green", "swordsman", "gunner", "green", "seasoned", "bosun", "green", "musketeer"]

var ship: Ship
var deck_y: float = 0.0
var half_beam: float = 1.0
var _captain: DeckFighterView
var _hands: Array[DeckFighterView] = []
var _beats: Array[Dictionary] = []  ## per hand: {a, b, speed, t} - a walk between two deck points, or none
var _lod_t: float = 0.0
var _shown: bool = true
var _time: float = 0.0


func setup(owner_ship: Ship, deck_height: float, half_width: float) -> void:
	ship = owner_ship
	deck_y = deck_height
	half_beam = half_width
	name = "DeckCrew"
	position = Vector3(0.0, deck_y, 0.0)
	set_meta("kind", "deck_crew")


func is_player_ship() -> bool:
	return ship != null and ship.ai == null


## How many hands stand on deck for `crew_count` men aboard.
static func hands_for(crew_count: int, player: bool) -> int:
	var cap: int = MAX_PLAYER_HANDS if player else MAX_AI_HANDS
	if crew_count <= 0:
		return 0
	return mini(maxi(ceili(float(crew_count) / (2.0 if player else 4.0)), 1), cap)


## Crew kind for the `i`th hand of a ship of `faction`.
static func ai_kind(faction: String, i: int) -> String:
	var list: Array = AI_CREW.get(faction, AI_CREW["pirate"])
	return str(list[i % list.size()])


## Deck station for hand `i` of `n`, in ship space on the deck: x across (starboard +), y along (bow -).
static func station(i: int, length_m: float, half_w: float) -> Vector2:
	var side: float = 1.0 if i % 2 == 0 else -1.0
	var rows: int = 5
	var row: int = (i / 2) % rows
	var along: float = lerpf(-0.3, 0.2, float(row) / float(rows - 1)) * length_m
	var across: float = side * half_w * (0.55 if (i / 2) % 2 == 0 else 0.25)
	return Vector2(across, along)


func _process(delta: float) -> void:
	if ship == null or not is_instance_valid(ship) or ship.damage == null:
		return
	_time += delta
	if ship.damage.sunk:
		visible = false
		return
	_lod_t -= delta
	if _lod_t <= 0.0:
		_lod_t = LOD_EVERY_S
		_shown = _wants_shown()
	visible = _shown
	if not _shown:
		return
	_sync_count()
	_walk(delta)


func _wants_shown() -> bool:
	if is_player_ship():
		return true
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return true
	return cam.global_position.distance_to(ship.global_position) <= AI_SHOW_M + ship.stats.length_m


func _sync_count() -> void:
	var budget: int = SPAWN_PER_FRAME
	if _captain == null:
		_captain = _spawn(_captain_state(), Vector2(0.0, ship.stats.length_m * 0.2), Vector2(0.0, -1.0))  # at the helm, just forward of the quarterdeck
		budget -= 1
	var want: int = hands_for(ship.crew.count if ship.crew != null else 0, is_player_ship())
	while _hands.size() > want:
		var gone: DeckFighterView = _hands.pop_back()
		_beats.pop_back()
		gone.queue_free()
	while _hands.size() < want and budget > 0:
		budget -= 1
		var i: int = _hands.size()
		var f: FighterState = _hand_state(i)
		var at: Vector2 = station(i, ship.stats.length_m, half_beam)
		var facing := Vector2(signf(at.x) * 0.4, -1.0 if i % 3 == 0 else 0.5).normalized()
		_hands.append(_spawn(f, at, facing))
		var beat: Dictionary = {}
		if i % 3 == 1:  # every third hand walks a beat between the rail and the centreline
			beat = {"a": at, "b": Vector2(at.x * 0.15, at.y + ship.stats.length_m * 0.08), "speed": 1.1 + 0.2 * float(i % 2), "t": float(i)}
		_beats.append(beat)


func _captain_state() -> FighterState:
	var f: FighterState
	if is_player_ship():
		f = FighterState.make_player(1, "cutlass", "flintlock", 1)
		f.display_name = ""
	else:
		f = FighterState.make_enemy("captain" if ship.faction != "navy" else "officer")
	f.id = ship.get_instance_id() % 997
	return f


func _hand_state(i: int) -> FighterState:
	var f: FighterState
	if is_player_ship():
		f = FighterState.make_crew(PLAYER_CREW[i % PLAYER_CREW.size()])
		f.melee = "cutlass"
	else:
		f = FighterState.make_enemy(ai_kind(ship.faction, i))
	f.id = 100 + i * 3 + (ship.get_instance_id() % 7)
	return f


func _spawn(f: FighterState, at: Vector2, facing: Vector2) -> DeckFighterView:
	f.pos = at
	f.dir = facing
	var v := DeckFighterView.new()
	v.fighter = f
	v.show_label = false
	v.pose_idle_only = true
	v.set_meta("kind", "deck_figure")
	add_child(v)  # its _ready sets the scale for its kind; we enlarge on top of that
	v.scale *= FIGURE_SCALE * clampf(ship.stats.beam_m / 7.0, 0.85, 1.0)
	return v


## Walkers pace between their two points and turn at each end; the view picks walk or idle from the speed.
func _walk(delta: float) -> void:
	for i in _hands.size():
		var beat: Dictionary = _beats[i]
		if beat.is_empty():
			continue
		var a: Vector2 = beat["a"]
		var b: Vector2 = beat["b"]
		var span: float = maxf(a.distance_to(b), 0.1)
		beat["t"] = float(beat["t"]) + delta * float(beat["speed"]) / span
		# pingpong with a short pause at each end
		var cycle: float = fposmod(float(beat["t"]), 2.6)
		var k: float = clampf(cycle, 0.0, 1.0) if cycle < 1.3 else 1.0 - clampf(cycle - 1.3, 0.0, 1.0)
		var f: FighterState = _hands[i].fighter
		var next: Vector2 = a.lerp(b, k)
		if next.distance_to(f.pos) > 0.0005:
			f.dir = (next - f.pos).normalized()
		f.pos = next


func hand_count() -> int:
	return _hands.size()


func has_captain() -> bool:
	return _captain != null
