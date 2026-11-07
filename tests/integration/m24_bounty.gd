extends SceneTree
## Bounties and infamy in the running world: a navy ship struck, sunk and a prize taken puts a price on the player,
## the wanted badge shows the stars, hunters come astern, four stars shut the navy's harbour, the wanted board opens
## and pays the navy's reward for a pirate sunk, and the crew sings a shanty at sea.
##   godot --headless --path . --fixed-fps 60 -s res://tests/integration/m24_bounty.gd

var _fails: Array[String] = []
var _frames: int = 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _initialize() -> void:
	for s in [0, 1, 2, 3]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.SLOT_PATH % s))
	Session.begin_new("Test", 1, 1)
	Session.enter_world(self)


func _ship(w: Node, faction: String, rep: String, dx: float) -> Ship:
	var p: Vector3 = w.ship.global_position
	var s: Ship = w._make_ship(load("res://data/ships/sloop.tres"), Vector3(p.x + dx, 0.5, p.z + 300.0), 0.0, faction)
	s.set_meta("rep_faction", rep)
	return s


func _process(_delta: float) -> bool:
	_frames += 1
	if current_scene == null or current_scene.name != "World" or _frames < 4:
		return false
	var w: Node = current_scene
	var st: Dictionary = Session.state
	_check(w.bounties != null, "world has a bounty director")
	_check(w.overlay.get_node_or_null("WantedBadge") is WantedBadge, "the HUD has the wanted badge")
	# a navy sloop: struck once (attack), then sunk by the player
	var navy: Ship = _ship(w, "navy", "navy", 0.0)
	var at: Vector3 = navy.global_position + Vector3(0, 1, 0)
	navy.receive_cannonball(at, Vector3.LEFT, Vector3.RIGHT, "6pdr", "round", 120.0, w.ship)
	navy.receive_cannonball(at, Vector3.LEFT, Vector3.RIGHT, "6pdr", "round", 120.0, w.ship)
	_check(Bounty.value(st, "navy") == Bounty.CRIME["attack"], "striking a navy ship costs one attack, got %s" % Bounty.value(st, "navy"))
	navy._on_sank()
	_check(Bounty.value(st, "navy") == Bounty.CRIME["attack"] + Bounty.CRIME["sink"], "sinking it adds the sink")
	# a merchant prize taken and kept
	var trader: Ship = _ship(w, "merchant", "merchant", 200.0)
	var layer := CanvasLayer.new()
	w.add_child(layer)
	w.prizes._busy = true
	w.prizes._on_fate(CaptureFate.Fate.STRIP_AND_SINK, trader, {"gold": 0, "cargo": {}, "supplies": {}, "map_fragment": ""}, layer)
	_check(Bounty.value(st, "merchant") == Bounty.CRIME["capture"], "taking a merchant prize puts the merchants' price on you")
	# a pirate sunk: the navy owes a reward
	var pirate: Ship = _ship(w, "pirate", "pirate", -200.0)
	pirate.last_attacker = w.ship
	pirate._on_sank()
	_check(int(st["bounty_claims"]) >= Bounty.PIRATE_REWARD_RANGE.x, "the navy owes for the pirate")
	# two stars: the badge shows them and a wave of two hunters comes astern
	Bounty.set_value(st, "navy", 160.0)
	var badge: WantedBadge = w.overlay.get_node("WantedBadge")
	badge.show_state(st)
	_check(badge.stars == 2 and badge.faction == "navy", "the badge shows two navy stars")
	var now: float = 500.0
	_check(w.bounties.hour_tick(now).is_empty(), "the first wave gives a head start")
	var wave: Array[Ship] = w.bounties.hour_tick(now + float(Bounty.hunters(2)["interval_h"]))
	_check(wave.size() == 2, "two hunters, got %d" % wave.size())
	for h in wave:
		_check(h.get_meta("hunter", false) and h.law_faction() == "navy" and w.prizes.targets.has(h), "a hunter is a navy prize")
		_check(FactionRel.aggressive_toward(h.faction, "player"), "hunters attack")
		_check(h.global_position.distance_to(w.ship.global_position) < 2000.0, "hunters come close")
	# four stars shut Port Regal; a clean record lets the ship in and the wanted board opens
	var dock: Vector2 = PortData.PORTS["albion"]["dock"]
	w.ship.global_position = Vector3(dock.x, w.ship.global_position.y, dock.y)
	w.ship.linear_velocity = Vector3.ZERO
	Bounty.set_value(st, "navy", 470.0)
	w.open_port()
	_check(w.get_node_or_null("PortLayer") == null, "four stars: Port Regal turns the ship away")
	Bounty.set_value(st, "navy", 0.0)
	w.open_port()
	var port: Node = w.get_node_or_null("PortLayer")
	_check(port != null, "a clean ship docks")
	if port != null:
		var menu: PortMenu = port.get_child(0) as PortMenu
		var board := WantedBoardScreen.new()
		menu._open(board)
		var gold0: int = int(st["gold"])
		var owed: int = int(st["bounty_claims"])
		board._collect()
		_check(int(st["gold"]) == gold0 + owed and int(st["bounty_claims"]) == 0, "the board pays the navy's reward")
		board.close()
		menu.close()
	# the crew sings at sea
	st["morale"] = 60.0
	w.world_audio.ctx = {}
	var song: String = w.world_audio.sing()
	_check(AudioData.SHANTIES.has(song), "the crew sings a shanty")
	var audio: Node = root.get_node("Audio")
	_check(str(audio.override_track) == "shanty_" + song, "the shanty takes over the music")
	w.world_audio.stop_singing()
	_check(str(audio.override_track) == "", "and gives it back")
	return _finish()


func _finish() -> bool:
	if _fails.is_empty():
		print("M24 BOUNTY: PASS")
		quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		quit(1)
	return true
