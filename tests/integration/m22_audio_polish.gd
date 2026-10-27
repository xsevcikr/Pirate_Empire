extends SceneTree
## M22 in the running world: the music layer follows the situation, actions make their sounds, barks duck the music,
## the first hour's scripted income reaches the pacing targets, and eight ships run inside the frame budget.

const FRAME_BUDGET_MS: float = 16.6
const SHIPS: int = 8

var _fails: Array[String] = []
var _frames: int = 0
var _step: int = 0
var _wait: int = 0
var _times: Array[float] = []
var _last_us: int = 0
var _extra: Array[Ship] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _initialize() -> void:
	for s in [0, 1, 2, 3]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.SLOT_PATH % s))
	Session.begin_new("Test", 1, 1)
	Session.enter_world(self)


func _process(_delta: float) -> bool:
	_frames += 1
	if current_scene == null or current_scene.name != "World" or _frames < 4:
		return false
	var w: Node = current_scene
	var audio: Node = Svc.node("Audio")
	if audio == null or w.world_audio == null:
		_check(false, "the world has an audio conductor and the Audio autoload runs")
		return _finish()
	audio.muted = true
	if _wait > 0:
		_wait -= 1
		return false
	match _step:
		0:
			_pacing()
			_step = 1
			_wait = 40
		1:
			_check(audio.current_track() == AudioData.track_for(w.world_audio.ctx), "sailing: %s plays %s" % [audio.current_track(), AudioData.track_for(w.world_audio.ctx)])
			_check(audio.current_track().begins_with("region_") or audio.current_track() == "layer_explore", "open water plays the region or explore theme")
			w.open_port()
			_step = 2
			_wait = 60
		2:
			_check(audio.current_track() == "layer_port", "in port: " + audio.current_track())
			w.get_node("PortLayer").queue_free()
			paused = false
			_step = 3
			_wait = 60
		3:
			_check(audio.current_track() != "layer_port", "leaving port ends the port music")
			w.wind.speed_kn = 40.0
			_step = 4
			_wait = 60
		4:
			_check(audio.current_track() == "layer_storm", "a storm: " + audio.current_track())
			_check(audio.ambience_db("rain") > -40.0 and audio.ambience_db("waves_rough") > -40.0, "rain and rough waves rise in a storm")
			w.wind.speed_kn = 12.0
			var f: Ship = w._make_ship(load("res://data/ships/sloop.tres"), w.ship.position + Vector3(900, 0.5, 0), 90.0, "pirate")
			f.ai = ShipAI.new()
			f.ai.ship = f
			f.add_child(f.ai)
			_extra.append(f)
			_step = 5
			_wait = 60
		5:
			_check(audio.current_track() == "layer_tension", "a hostile sail: " + audio.current_track())
			_extra[0].global_position = w.ship.global_position + Vector3(400, 0, 0)
			_extra[0].ai.state = AiLogic.State.ENGAGE
			_step = 6
			_wait = 60
		6:
			_check(audio.current_track() == "layer_combat", "an enemy engaging: " + audio.current_track())
			w.ship.broadside.fire(0)
			w.ship.broadside.fire(1)
			_step = 7
			_wait = 120
		7:
			var shot: bool = false
			for id in ["cannon_swivel", "cannon_6pdr", "cannon_12pdr"]:
				shot = shot or int(audio.played.get(id, 0)) > 0
			_check(shot, "firing the guns makes a report")
			_check(int(audio.played.get("splash", 0)) + int(audio.played.get("wood_impact", 0)) > 0, "shot landing makes a sound")
			audio.bark("victory")
			_check(audio.ducked(), "a bark ducks the music")
			Svc.node("EventBus").trade_made.emit("sell", "rum", 1.0, 5)
			_check(int(audio.played.get("coin", 0)) > 0, "a trade jingles")
			_step = 8
		8:
			var dir: RivalDirector = w.rivals
			for i in 16:
				dir._spawn("sloop", "pirate", w.ship.global_position + Vector3(3000 + 40 * i, 0, 0), {"gold": [10, 20]})
			dir.cull()
			_check(dir._ambient.size() <= RivalDirector.MAX_AMBIENT_SHIPS, "event ships are capped (%d)" % dir._ambient.size())
			w.ship.global_position = Vector3(20000, 0.5, 0)
			dir.cull()
			_check(dir._ambient.is_empty(), "ships left far behind are taken off the sea")
			w.ship.global_position = Vector3(0, 0.5, 420)
			for f in _extra:
				if is_instance_valid(f):
					f.queue_free()
			_extra.clear()
			for i in SHIPS:
				var s: Ship = w._make_ship(load("res://data/ships/sloop.tres"), w.ship.position + Vector3(300 + 120 * i, 0.5, -200 + 90 * (i % 3)), 90.0, "pirate")
				s.ai = ShipAI.new()
				s.ai.ship = s
				s.add_child(s.ai)
				_extra.append(s)
			_step = 9
			_wait = 30
			_last_us = 0
		9:
			var now: int = Time.get_ticks_usec()
			if _last_us != 0:
				_times.append(float(now - _last_us) / 1000.0)
			_last_us = now
			if _times.size() >= 300:
				_times.sort()
				var avg: float = 0.0
				for t in _times:
					avg += t
				avg /= _times.size()
				print("M22 frame time with %d ships: avg %.1f ms, p99 %.1f ms" % [SHIPS, avg, _times[int(_times.size() * 0.99)]])
				_check(avg < FRAME_BUDGET_MS, "average frame %.1f ms is inside %.1f ms" % [avg, FRAME_BUDGET_MS])
				return _finish()
	return false


## The scripted income of the first hour, run with the real functions, against the targets of spec section 3.
func _pacing() -> void:
	var s: Dictionary = SaveGame.new_state()
	var port: String = PortData.START_PORT
	var m: Market = PortService.market_of(s, port)
	# 3-8 min: the lugger's loot at its middle value and the crate of fish, then sold at the market
	s["gold"] = int(s["gold"]) + 75
	s["cargo"]["fish"] = 10.0
	PortService.sell_good(s, m, "fish", 10)
	# 8-12 min: four deckhands and a food top-up
	for i in 4:
		_check(PortService.hire(s, "green", port), "can hire deckhand %d" % i)
	_check(PortService.buy_supply(s, m, "food", 4), "can buy food")
	var after_hire: int = int(s["gold"])
	_check(after_hire >= 0, "the first sales pay for four deckhands")
	# 12-25 min: the quest board raid, its reward and its loot (the crew keeps its share of the loot)
	var job: Dictionary = QuestData.JOBS["gallows_raid"]
	var loot_gold: float = (float(job["loot"]["gold"][0]) + float(job["loot"]["gold"][1])) * 0.5
	s["gold"] = int(s["gold"]) + int(job["reward"]) + int(Loot.captain_share(loot_gold))
	s["cargo"]["sugar"] = float(job["loot"]["cargo"]["sugar"])
	PortService.sell_good(s, m, "sugar", 12)
	_check(String(job["loot"]["map_fragment"]) != "", "the raid's loot holds the first map fragment")
	s["map_fragments"].append(job["loot"]["map_fragment"])
	# 40-60 min: a Sloop with the cutter traded in
	var cost: int = PortService.ship_cost(s, "sloop")
	_check(cost == 1400, "a Sloop costs 1,400 with the cutter traded in, not %d" % cost)
	var gap: int = maxi(cost - int(s["gold"]), 0)
	var crew_after: int = int(s["crew"])
	print("M22 first hour: %d gold after the scripted jobs, Sloop needs %d more, crew %d" % [int(s["gold"]), gap, crew_after])
	# the rest comes from ordinary play (more prizes, trade); the scripted jobs must leave a gap one or two prizes can close
	_check(gap <= 900, "the Sloop is within reach of two ordinary prizes (gap %d)" % gap)
	# Mad Molly appears once the first fragment is in the chest
	_check(RivalState.available(s, "molly"), "Mad Molly Thorne can be met after the first fragment")
	var sloop: ShipStats = PortService.ship_stats("sloop")
	_check(sloop.crew_max >= 12, "a Sloop holds the target crew of 8 to 12")


func _finish() -> bool:
	if _fails.is_empty():
		print("M22 AUDIO POLISH: PASS")
		quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		quit(1)
	return true
