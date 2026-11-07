extends SceneTree
## Sea life and rail fishing in the running world: with auto drive on (AutoDrive, K) the captain walks to the rail,
## fishes and the catch goes into the stores; dolphins, a whale, flying fish and gulls all show up; taking the helm
## back puts the fishing gear away.

var _fails: Array[String] = []
var _step: int = 0
var _wait: int = 0
var _frames: int = 0
var _world: Node
var _ship: Ship
var _drive: AutoDrive
var _life: SeaLife
var _food0: float = 0.0


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
			_drive = _world.get("auto_drive")
			_life = _world.get("sea_life")
			_check(_drive != null, "the world has auto drive")
			_check(_life != null, "the world has sea life")
			_ship.global_position = Vector3(600.0, 0.3, 1400.0)  # open water
			_ship.rotation = Vector3.ZERO
			_ship.sail_level = 2
			Session.state["course"] = []
			_go(1, 120)
		1:
			_check(_drive.engage(), "auto drive takes the wheel in open water")
			_check(_drive.fishing != null and _drive.fishing.is_inside_tree(), "fishing gear comes on deck with the captain")
			_check(_drive.fishing.sea_life == _life, "a catch is shown to the sea life")
			_go(2, 10)
		2:
			var f: RailFishing = _drive.fishing
			var w: DeckWalker = _drive.walker
			# in the middle of the deck there is no rail to fish from
			w.fighter.pos = w.start_spot(Vector2(0.0, 0.0))
			_check(not f.at_rail() or absf(w.fighter.pos.x) > 0.5, "no fishing from the middle of the deck")
			# to the starboard rail amidships and fish
			var edge: float = f.edge_x(Vector2(0.0, w.fighter.pos.y), 1.0)
			w.fighter.pos = Vector2(edge - 0.2, w.fighter.pos.y)
			_check(f.at_rail(), "at the rail")
			_food0 = float(Session.state["supplies"]["food"])
			f.use()
			_check(f.fishing.phase == DeckFishing.Phase.WAITING, "E at the rail casts a line")
			f.fishing.tick(DeckFishing.WAIT_MAX_S + 0.1)
			_check(f.fishing.phase == DeckFishing.Phase.BITE, "a bite")
			f.use()
			_check(f.fishing.phase == DeckFishing.Phase.CAUGHT, "E on the bite lands the fish")
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
			_drive.take_helm()
			_check(_drive.fishing == null, "taking the helm back puts the rod away")
			_go(4, 2)
		4:
			_check(_world.find_child("RailFishing", true, false) == null, "no fishing gear left behind")
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
