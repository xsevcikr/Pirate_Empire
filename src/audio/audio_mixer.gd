extends Node
## The game's mixer (autoload "Audio"): buses with their own sliders, music that crossfades over two seconds, pooled
## positional and flat sound effects, looped ambience and barks that duck the music. Everything it plays is chosen
## by AudioData; other code only calls Sfx.play(), Sfx.bark() and Sfx.music().

var music_track: String = ""
var override_track: String = ""  ## set while a screen (the tavern) wants its own music
var _a := AudioStreamPlayer.new()
var _b := AudioStreamPlayer.new()
var _front: AudioStreamPlayer  ## the player that holds the current track
var _fade_t: float = AudioData.CROSSFADE_S
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _voice := AudioStreamPlayer.new()
var _ambience: Dictionary = {}  ## id -> AudioStreamPlayer
var _cooldowns: Dictionary = {}  ## sfx id -> seconds left
var _bark_cd: Dictionary = {}
var _duck_left: float = 0.0
var _duck_db: float = 0.0
var _rng := RandomNumberGenerator.new()
var _streams: Dictionary = {}
var played: Dictionary = {}  ## id -> count, for tests and the soak report
var _gull_in: float = 8.0
var _thunder_in: float = 30.0
var muted: bool = false  ## tests and headless runs can switch the players off but keep the bookkeeping


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 4242
	_preload_music()
	_ensure_buses()
	for p in [_a, _b]:
		p.bus = "Music"
		add_child(p)
	_front = _a
	_voice.bus = "Voice"
	add_child(_voice)
	for i in AudioData.SFX_POOL:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.max_distance = AudioData.SFX_MAX_DIST_M
		p3.unit_size = 25.0
		add_child(p3)
		_pool3d.append(p3)
	for i in 8:
		var p2 := AudioStreamPlayer.new()
		p2.bus = "SFX"
		add_child(p2)
		_pool2d.append(p2)
	for id: String in AudioData.AMBIENCE:
		var amb := AudioStreamPlayer.new()
		amb.bus = "Ambience"
		amb.stream = _loop(AudioData.ambience_path(id))
		amb.volume_db = -80.0
		add_child(amb)
		_ambience[id] = amb
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.sfx.connect(play_sfx)
		bus.bark.connect(bark)
		bus.music_request.connect(set_override)
	apply_volumes()


static func _ensure_buses() -> void:
	for n in AudioData.BUSES:
		if AudioServer.get_bus_index(n) < 0:
			AudioServer.add_bus()
			var i: int = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, "Master")


func apply_volumes() -> void:
	var st: Node = Svc.node("Settings")
	if st == null:
		return
	for n: String in AudioData.BUSES:
		var v: float = float(st.get("%s_volume" % n.to_lower()))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(n), linear_to_db(maxf(v, 0.0001)))


## The music tracks are a minute or more each: decoding one when the ship crosses into a new sea would stall a frame,
## so they all load on worker threads from the start and are picked up from there.
func _preload_music() -> void:
	for track: String in AudioData.all_music():
		var path: String = AudioData.music_path(track)
		if ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path, "", true)


func _load(path: String) -> AudioStream:
	if not _streams.has(path):
		var threaded: bool = ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
		if threaded:
			_streams[path] = ResourceLoader.load_threaded_get(path)
		else:
			_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]


func _loop(path: String) -> AudioStream:
	var s: AudioStream = _load(path)
	if s is AudioStreamOggVorbis:
		s = (s as AudioStreamOggVorbis).duplicate()
		(s as AudioStreamOggVorbis).loop = true
	return s


# ---- music -------------------------------------------------------------------------------------------------

func set_override(track: String) -> void:
	override_track = track
	set_music(track if track != "" else music_track)


## Crossfade to a track (does nothing if it is already the current one).
func set_music(track: String) -> void:
	var want: String = override_track if override_track != "" else track
	if track != "" and override_track == "":
		music_track = track
	if want == "" or want == _current_name():
		return
	var back: AudioStreamPlayer = _b if _front == _a else _a
	back.stream = _loop(AudioData.music_path(want))
	back.set_meta("track", want)
	back.volume_db = -80.0
	if back.stream != null and not muted:
		back.play()
	_front = back
	_fade_t = 0.0
	played["music:" + want] = int(played.get("music:" + want, 0)) + 1


func _current_name() -> String:
	return str(_front.get_meta("track", ""))


func current_track() -> String:
	return _current_name()


# ---- effects -----------------------------------------------------------------------------------------------

## Play an effect. `pos` is a Vector3 in the world, a Vector2 on the map, or null for a flat sound.
func play_sfx(id: String, pos: Variant = null) -> bool:
	if not AudioData.SFX.has(id):
		return false
	var def: Dictionary = AudioData.SFX[id]
	if float(_cooldowns.get(id, 0.0)) > 0.0:
		return false
	_cooldowns[id] = float(def.get("cd", AudioData.DEFAULT_COOLDOWN_S))
	played[id] = int(played.get(id, 0)) + 1
	var stream: AudioStream = _load(AudioData.sfx_path(id))
	if stream == null or muted:
		return true
	var pitch: float = 1.0 + _rng.randf_range(-1.0, 1.0) * float(def["pitch"])
	if pos != null and bool(def["pos"]):
		var p3: AudioStreamPlayer3D = _free3d()
		p3.stream = stream
		p3.volume_db = float(def["db"])
		p3.pitch_scale = pitch
		p3.global_position = pos if pos is Vector3 else Vector3((pos as Vector2).x, 0.0, (pos as Vector2).y)
		p3.play()
	else:
		var p2: AudioStreamPlayer = _free2d()
		p2.stream = stream
		p2.volume_db = float(def["db"])
		p2.pitch_scale = pitch
		p2.play()
	return true


func _free3d() -> AudioStreamPlayer3D:
	for p in _pool3d:
		if not p.playing:
			return p
	return _pool3d[0]


func _free2d() -> AudioStreamPlayer:
	for p in _pool2d:
		if not p.playing:
			return p
	return _pool2d[0]


# ---- voices ------------------------------------------------------------------------------------------------

## A short voice line: picks a line and voice, shows the subtitle and ducks the music under it.
func bark(situation: String, arg: String = "") -> bool:
	if not AudioData.BARKS.has(situation) or float(_bark_cd.get(situation, 0.0)) > 0.0:
		return false
	var def: Dictionary = AudioData.BARKS[situation]
	_bark_cd[situation] = float(def["cd"])
	var lines: Array = def["lines"]
	var key: String = str(lines[_rng.randi() % lines.size()])
	var text: String = Loc.t(key)
	var bus: Node = Svc.node("EventBus")
	var st: Node = Svc.node("Settings")
	if bus != null and (st == null or bool(st.accessibility.subtitles)):
		bus.subtitle.emit(text % arg if text.contains("%s") else text)
	played["bark:" + situation] = int(played.get("bark:" + situation, 0)) + 1
	var voices: Array = AudioData.VOICE_FILES[str(def["voice"])]
	var stream: AudioStream = _load(AudioData.voice_path(str(voices[_rng.randi() % voices.size()])))
	var length: float = stream.get_length() if stream != null else 0.6
	if stream != null and not muted:
		_voice.stream = stream
		_voice.play()
	_duck_left = length + AudioData.DUCK_TAIL_S
	return true


func ducked() -> bool:
	return _duck_left > 0.0


# ---- ambience ----------------------------------------------------------------------------------------------

## Set the loudness of the sea, wind and rain loops from the weather; start the gulls and thunder when due.
func update_ambience(sea_state: float, wind_kn: float, near_land: bool, delta: float) -> void:
	var mix_: Dictionary = AudioData.ambience_mix(sea_state, wind_kn)
	for id: String in mix_:
		var amb: AudioStreamPlayer = _ambience[id]
		var target_db: float = float(AudioData.AMBIENCE[id]["db"]) + linear_to_db(maxf(float(mix_[id]), 0.0001))
		amb.volume_db = lerpf(amb.volume_db, maxf(target_db, -80.0), clampf(delta * 1.5, 0.0, 1.0))
		if not amb.playing and not muted and amb.stream != null:
			amb.play()
	_gull_in -= delta
	if _gull_in <= 0.0:
		_gull_in = _rng.randf_range(AudioData.GULL_EVERY_S.x, AudioData.GULL_EVERY_S.y)
		if near_land:
			play_sfx("gulls")
	if sea_state >= AudioData.STORM_FROM:
		_thunder_in -= delta
		if _thunder_in <= 0.0:
			_thunder_in = _rng.randf_range(AudioData.THUNDER_EVERY_S.x, AudioData.THUNDER_EVERY_S.y)
			play_sfx("thunder")
	if sea_state >= AudioData.GROAN_SEA_STATE:
		play_sfx("hull_groan")


func ambience_db(id: String) -> float:
	return (_ambience[id] as AudioStreamPlayer).volume_db


func _process(delta: float) -> void:
	for k in _cooldowns.keys():
		_cooldowns[k] = float(_cooldowns[k]) - delta
	for k in _bark_cd.keys():
		_bark_cd[k] = float(_bark_cd[k]) - delta
	if _fade_t < AudioData.CROSSFADE_S:
		_fade_t = minf(_fade_t + delta, AudioData.CROSSFADE_S)
		var g: Array[float] = AudioData.crossfade_gains(_fade_t)
		var other: AudioStreamPlayer = _b if _front == _a else _a
		_front.volume_db = linear_to_db(maxf(g[1], 0.0001))
		other.volume_db = linear_to_db(maxf(g[0], 0.0001))
		if _fade_t >= AudioData.CROSSFADE_S:
			other.stop()
	if _duck_left > 0.0:
		_duck_left -= delta
	var want: float = AudioData.DUCK_DB if _duck_left > 0.0 else 0.0
	_duck_db = lerpf(_duck_db, want, clampf(delta * 8.0, 0.0, 1.0))
	_front.volume_db = _front.volume_db + _duck_db if _fade_t >= AudioData.CROSSFADE_S else _front.volume_db
