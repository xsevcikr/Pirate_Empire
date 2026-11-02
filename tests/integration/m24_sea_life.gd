extends SceneTree
## Sea life, autopilot and the walk on deck in the running world: the autopilot takes the wheel and brings the ship
## back to her course after she is knocked off it, the captain walks the deck (and cannot walk off it), fishes at
## the rail and the catch goes into the stores; dolphins, a whale, flying fish and gulls all show up; an enemy
## closing in sends the captain back to the wheel.

var _fails: Array[String] = []
var _step: int = 0
var _wait: int = 0
var _frames: int = 0
var _world: Node
var _ship: Ship
var _walk: DeckWalk
var _life: SeaLife
var _food0: float = 0.0
var _course: Vector2


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _initialize() -> void:
	Session.begin_new("Test", 1, 1)
	Session.enter_world(self)


func _go(step: int, wait: int = 3) -> void:
	_step = step
	_wait = wait
	_frames = 0


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	_frames += 1
	match _step:
		0:
			if current_scene == null or current_scene.name != "World":
				return false
			_world = current_scene
			_ship = _world.get("ship")
			_walk = _world.get("deck_walk")
			_life = _world.get("sea_life")
			_check(_walk != null, "the world has a deck walk")
			_check(_life != null, "the world has sea life")
			_ship.global_position = Vector3(600.0, 0.3, 1400.0)  # open water
			_ship.rotation = Vector3.ZERO
			_ship.sail_level = 2
			_go(1, 120)
		1:
			_check(_walk.leave_helm(), "the captain can leave the wheel in open water")
			_check(_walk.walking and _walk.autopilot.engaged, "walking, autopilot on")
			_check((_world.get("player_controller") as PlayerController).hands_off, "the keys no longer steer")
			_check(_world.get("rig").focus != null, "the camera follows the captain")
			_check(_ship.find_child("DeckWalkCaptain", true, false) != null, "the captain stands on deck")
			_course = _walk.autopilot.course
			# knock her 40 degrees off course
			_ship.rotate_y(deg_to_rad(40.0))
			_go(2, 1)
		2:
			if _frames < 900:
				return false
			var err: float = absf(rad_to_deg(_ship.heading().angle_to(_course)))
			_check(err < 8.0, "the autopilot brought her back on course (off by %.1f deg)" % err)
			# walking: far past the side and the bow, he stays on the planks
			_walk.captain_pos = Vector2.ZERO
			for i in 200:
				_walk.walk(Vector2(1.0, -1.0), 1.0 / 30.0)
			var p: Vector2 = _walk.captain_pos
			_check(absf(p.x) <= _walk.deck_half_width(p.y) + 0.001, "he cannot walk over the side")
			_check(absf(p.y) <= _walk.deck_half_length() + 0.001, "he cannot walk off the bow")
			# to the rail amidships and fish
			_walk.captain_pos = Vector2(_walk.deck_half_width(0.0), 0.0)
			_check(_walk.at_rail(), "at the rail")
			_food0 = float(Session.state["supplies"]["food"])
			_walk.use()
			_check(_walk.fishing.phase == DeckFishing.Phase.WAITING, "E at the rail casts a line")
			_walk.fishing.tick(DeckFishing.WAIT_MAX_S + 0.1)
			_check(_walk.fishing.phase == DeckFishing.Phase.BITE, "a bite")
			_walk.use()
			_check(_walk.fishing.phase == DeckFishing.Phase.CAUGHT, "E on the bite lands the fish")
			_check(float(Session.state["supplies"]["food"]) > _food0, "the catch went into the stores")
			# all the animals
			_life._pod_timer = 0.0
			_life._whale_timer = 0.0
			_life._school_timer = 0.0
			_ship.sail_level = 3
			_go(3, 1)
		3:
			if _frames < 240:
				return false
			var dolphins: int = 0
			for n in _life.get_children():
				if n.get_meta("kind", "") == "dolphin" and (n as Node3D).visible:
					dolphins += 1
			_check(dolphins == SeaLife.POD_SIZE, "a pod of dolphins came (%d)" % dolphins)
			_check(_life.pod_state == "coming" or _life.pod_state == "riding", "the pod rides with the ship (%s)" % _life.pod_state)
			_check(_life.whale_state != "away", "a whale surfaced")
			_check(_life.gulls_shown() >= SeaLife.GULLS_AT_SEA, "gulls circle overhead (%d)" % _life.gulls_shown())
			_life.scare_gulls()
			_check(_life._scatter_left > 0.0, "the guns scare the gulls")
			# back to the wheel with Enter
			_walk.toggle()
			_check(not _walk.walking and not _walk.autopilot.engaged, "Enter takes the wheel back")
			_check(not (_world.get("player_controller") as PlayerController).hands_off, "the keys steer again")
			_check(_world.get("rig").focus == null, "the camera is back on the ship")
			# an enemy hunting us: he cannot leave the wheel, and is called back if he already has
			var enemy: Ship = _world.call("_make_ship", load("res://data/ships/sloop.tres"), _ship.global_position + Vector3(150, 0, 0), 0.0, "navy")
			enemy.ai = ShipAI.new()
			enemy.ai.target = _ship
			_check(not _walk.leave_helm(), "no autopilot with an enemy close")
			enemy.ai.target = null
			_check(_walk.leave_helm(), "autopilot again once he lets us be")
			enemy.ai.target = _ship
			_go(4, 1)
		4:
			if _frames < 40:
				return false
			_check(not _walk.walking, "an enemy closing in sends the captain back to the wheel")
			return _finish()
	return false


func _finish() -> bool:
	if _fails.is_empty():
		print("M24 SEA LIFE: PASS")
		quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		quit(1)
	return true
