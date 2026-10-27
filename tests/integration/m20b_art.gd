extends SceneTree
## The art pass in the running game: every ship class opens below decks; every port builds its walkable old town with
## people who walk about; the island camp is built on some islands and has a fire, huts and villagers.

var _fails: Array[String] = []
var _frames: int = 0
var _district: DockDistrict
var _ports: Array = []
var _stage: int = 0
var _isle: Island
var _seed: int = 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _initialize() -> void:
	GameInput.register()
	Session.begin_new("Test", 1, 1)
	for cls in PortData.CLASS_ORDER + PackedStringArray(["lugger", "revenant", "sovereign"]):
		var stats: ShipStats = load("res://data/ships/%s.tres" % cls)
		var state: Dictionary = SaveGame.new_state()
		state["gold"] = 3000
		state["cargo"] = {"sugar": 8.0}
		var n: Node3D = ShipInterior.build(stats, state)
		var guns: int = 0
		for c in n.get_children():
			if c.get_meta("kind", "") == "gun":
				guns += 1
		_check(guns == maxi(stats.guns_per_side, 1) * 2, "%s: %d guns" % [cls, guns])
		_check(n.get_child_count() > 40, cls + " is furnished")
		n.free()
	_ports = PortData.PORTS.keys()


func _process(_d: float) -> bool:
	_frames += 1
	if _stage == 0:
		if _district == null:
			if _ports.is_empty():
				_stage = 1
				return false
			_district = DockDistrict.new()
			_district.port_id = _ports.pop_back()
			root.add_child(_district)
			_frames = 0
		elif _frames > 3:
			_check(_district.walkers.size() >= 8, "%s: townsfolk" % _district.port_id)
			_check(_district.get_node_or_null("Castle") != null or _district.find_child("Castle", true, false) != null, "%s: castle" % _district.port_id)
			_district.queue_free()
			_district = null
		return false
	if _stage == 1:
		var found: bool = false
		if _isle == null or _frames > 3:
			if _isle != null:
				var camp: Node = _isle.get_node_or_null("Camp")
				if camp != null:
					found = true
					_check(camp.find_child("CampFire", true, false) != null or camp.get_child_count() > 8, "camp is furnished")
					var villagers: int = 0
					for c in camp.get_children():
						if c.get_meta("kind", "") == "villager":
							villagers += 1
					_check(villagers >= 3, "villagers at the camp")
				_isle.queue_free()
			_seed += 1
			if found or _seed > 30:
				_check(found, "a camp was built on one of 30 islands")
				return _finish()
			_isle = Island.make(260.0, _seed, "tropical")
			root.add_child(_isle)
			_frames = 0
	return false


func _finish() -> bool:
	if _fails.is_empty():
		print("M20B ART: PASS")
		quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		quit(1)
	return true
