extends SceneTree
## Easy play in the running world: the parrot flies with the ship and spots hidden treasure near an island, a
## floating chest marks it and sailing up to it collects gold for the book; the goals card and the goals and
## collection screens open; on Easy the guns lay themselves for an enemy abeam; sinking gives a second chance; the
## sailing HUD no longer shows any wind.

var _fails: Array[String] = []
var _frames: int = 0
var _step: int = 0
var _wait: int = 0
var _spot: Dictionary = {}
var _out: Vector2 = Vector2.ZERO
var _gold: int = 0
var _enemy: Ship


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _initialize() -> void:
	for s in [0, 1, 2, 3]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.SLOT_PATH % s))
	Session.begin_new("Kid", 0, 1)
	Session.state["tutorial"] = "done"
	Session.state["crew"] = 6
	# start 200 m out to sea from the first island's first treasure spot
	_spot = HiddenLoot.spots()[0]
	var isl: Dictionary = PortData.gen().islands[0]
	var away: Vector2 = ((_spot["pos"] as Vector2) - (isl["pos"] as Vector2)).normalized()
	_out = (_spot["pos"] as Vector2) + away * 200.0
	Session.state["pos"] = [_out.x, _out.y]
	Session.enter_world(self)


func _process(_delta: float) -> bool:
	_frames += 1
	if current_scene == null or current_scene.name != "World" or _frames < 4:
		return false
	var w: Node = current_scene
	if _wait > 0:
		_wait -= 1
		return false
	match _step:
		0:
			var ep: EasyPlayDirector = w.easy_play
			_check(ep != null, "the easy-play director runs")
			if ep == null:
				return _finish()
			_check(ep.parrot != null and ep.parrot.is_inside_tree(), "the parrot flies with the ship")
			_check(w.goals_card != null, "the goals card is on screen")
			_check(not w.hud._label.text.to_lower().contains("wind"), "the sailing HUD shows no wind: %s" % w.hud._label.text)
			_check(Difficulty.current == Difficulty.Level.EASY, "an Easy game sets the AI to Easy")
			_check(EasyPlay.has_item(Session.state, CollectionData.ship_card(str(Session.state["ship_class"]))), "the starting ship's card is in the book")
			ep.scan(_out)
			_check(ep.markers.has(str(_spot["id"])), "the parrot spotted the treasure 200 m away")
			_check(ep.parrot.target_spot is Vector2, "the parrot flies off to circle the treasure")
			_step = 1
			_wait = 90
		1:
			var ep: EasyPlayDirector = w.easy_play
			var p: Vector3 = ep.parrot.global_position
			_check(Vector2(p.x, p.z).distance_to(_spot["pos"]) < 60.0, "the parrot is circling over the treasure (%.0f m off)" % Vector2(p.x, p.z).distance_to(_spot["pos"]))
			_gold = int(Session.state["gold"])
			var sp: Vector2 = _spot["pos"]
			w.ship.global_position = Vector3(sp.x + 5.0, 0.3, sp.y)
			w.ship.linear_velocity = Vector3.ZERO
			_step = 2
			_wait = 30
		2:
			var ep: EasyPlayDirector = w.easy_play
			_check(int(Session.state["gold"]) > _gold, "sailing up to the chest collected gold")
			_check(EasyPlay.value(Session.state, "parrot_finds") >= 1.0, "the parrot's find counts")
			_check(not ep.markers.has(str(_spot["id"])), "the chest is gone once emptied")
			_check(EasyPlay.is_done(Session.state, "parrot_find"), "the 'let the parrot find a treasure' goal is done")
			# an enemy lying 140 m abeam to starboard
			var ship: Ship = w.ship
			var right: Vector3 = ship.global_transform.basis.x
			right.y = 0.0
			var at: Vector3 = ship.global_position + right.normalized() * 140.0
			_enemy = w._make_ship(load("res://data/ships/sloop.tres"), Vector3(at.x, 0.5, at.z), ship.rotation_degrees.y, "navy")
			_enemy.last_attacker = ship
			ship.broadside.set_elevation(GunData.MAX_ELEVATION_DEG)
			_step = 3
			_wait = 10
		3:
			var ship: Ship = w.ship
			var d: float = Vector2(_enemy.global_position.x - ship.global_position.x, _enemy.global_position.z - ship.global_position.z).length()
			var want: float = ship.broadside.elevation_for_range(Broadside.Side.STARBOARD, d)
			_check(absf(ship.broadside.elevation_deg - want) < 0.6, "Easy: the guns laid themselves for the enemy (%.1f vs %.1f deg)" % [ship.broadside.elevation_deg, want])
			_enemy.queue_free()
			w.open_goals()
			_step = 4
			_wait = 5
		4:
			var layer: Node = w.get_node_or_null("MapLayer")
			_check(layer != null and layer.get_child(0) is GoalsScreen, "the goals list opens")
			if layer != null:
				var rows: int = 0
				for n in layer.find_children("*", "PanelContainer", true, false):
					if n.get_meta("kind", "") == "goal_row":
						rows += 1
				_check(rows == GoalData.LIST.size(), "every goal has a row (%d)" % rows)
				(layer.get_child(0) as MenuScreen).close()
			_step = 5
			_wait = 3
		5:
			w.open_collection()
			_step = 6
			_wait = 5
		6:
			var layer: Node = w.get_node_or_null("MapLayer")
			_check(layer != null and layer.get_child(0) is CollectionScreen, "the collection book opens")
			if layer != null:
				var cards: int = 0
				for n in layer.find_children("*", "PanelContainer", true, false):
					if n.get_meta("kind", "") == "collection_card":
						cards += 1
				_check(cards == CollectionData.SHELLS.size(), "the shell page has a card for every shell (%d)" % cards)
				(layer.get_child(0) as MenuScreen).close()
			_gold = int(Session.state["gold"])
			w.ship.damage.sank.emit()  # the real path: the one-shot hook fires once
			_step = 7
			_wait = 3
		7:
			var screens: Array = w.find_children("*", "DefeatScreen", true, false)
			_check(not screens.is_empty(), "the washed-ashore screen shows")
			_check(int(Session.state["gold"]) == _gold - floori(_gold * 0.1), "Easy loses only a tenth of the gold")
			if not screens.is_empty():
				(screens[0] as DefeatScreen).continued.emit()
			_step = 8
			_wait = 30
		8:
			var ship: Ship = w.ship
			_check(ship.stats.class_id == "cutter", "the same ship sails on")
			_check(not ship.damage.sunk, "the ship floats again")
			_check(ship.damage.hull_fraction() > 0.4, "the hull is patched up")
			return _finish()
	return false


func _finish() -> bool:
	for f in _fails:
		print("FAIL m25: " + f)
	print("m25_easy_play: %s" % ("ok" if _fails.is_empty() else "%d failures" % _fails.size()))
	Kenney.clear_caches()
	quit(1 if not _fails.is_empty() else 0)
	return true
