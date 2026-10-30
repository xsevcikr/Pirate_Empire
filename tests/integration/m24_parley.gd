extends SceneTree
## The surrender hail on real ships: a battered merchant with a small crew strikes to a big pirate crew most of the
## time, a fresh navy ship almost never does, and a ship that refused will not hear a second hail.

var _ocean := WaveModel.new(2.0)
var _wind := WindModel.new()
var _fails: Array[String] = []


func _spawn(pos: Vector3, faction: String) -> Ship:
	var s := Ship.new()
	s.stats = load("res://data/ships/sloop.tres")
	s.ocean = _ocean
	s.wind = _wind
	s.faction = faction
	s.position = pos
	root.add_child(s)
	s.sail_level = 0
	return s


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _initialize() -> void:
	await process_frame
	var state: Dictionary = SaveGame.new_state()
	state["fame"] = 800
	var player: Ship = _spawn(Vector3(0, 0.3, 0), "player")
	await process_frame
	player.crew.count = 40
	var struck_merchant: int = 0
	var struck_navy: int = 0
	for i in 40:
		var m: Ship = _spawn(Vector3(30, 0.3, 40.0 * i), "merchant")
		var n: Ship = _spawn(Vector3(-30, 0.3, 40.0 * i), "navy")
		m.set_meta("rep_faction", "merchant")
		n.set_meta("rep_faction", "navy")
		await process_frame
		m.crew.count = 8
		for k in m.damage.section_count:
			m.damage.section_hp[k] = m.damage.section_max * 0.4
		n.crew.count = 40
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + i
		if Parley.hail(player, m, state, rng)["struck"]:
			struck_merchant += 1
			_check(m.has_surrendered, "a ship that struck has surrendered")
		else:
			_check(not Parley.can_hail(m), "a refusal is final")
		var before: float = n.crew.morale
		if Parley.hail(player, n, state, rng)["struck"]:
			struck_navy += 1
		else:
			_check(n.crew.morale > before or before >= 100.0, "refusing stiffens the defenders")
			_check(not Parley.hail(player, n, state, rng)["struck"] and Parley.hail(player, n, state, rng)["chance"] == 0.0, "no second hail")
		m.queue_free()
		n.queue_free()
	_check(struck_merchant >= 28, "battered merchants struck %d of 40" % struck_merchant)
	_check(struck_navy <= 4, "fresh navy ships struck %d of 40" % struck_navy)
	var rival: Ship = _spawn(Vector3(0, 0.3, -60), "pirate")
	rival.set_meta("rival", "redbeard")
	_check(not Parley.can_hail(rival), "named rivals never strike to a hail")
	print("M24 parley: merchants struck %d/40, navy %d/40" % [struck_merchant, struck_navy])
	if _fails.is_empty():
		print("M24 parley: OK")
		quit(0)
	else:
		print("M24 parley: FAILED")
		for f in _fails:
			print("  FAIL ", f)
		quit(1)
