class_name WorldMarkers
extends CanvasLayer
## Things drawn over the 3D world: a nameplate over each ship that is close (fades out with distance, gone past
## NAMEPLATE_RANGE_M), and floating numbers that rise and fade: damage on a hit, "+50 gold" when gold comes in.
## Your own fleet gets a hull bar; an enemy only shows what the eye can see (her masts), as the ship card does.
## Each plate has an icon for its side (anchor, skull, chest), so friend and foe read without colour.

const NAMEPLATE_RANGE_M: float = 220.0
const NAMEPLATE_FADE_M: float = 160.0
const SCAN_EVERY_S: float = 0.5
const FLOAT_LIFE_S: float = 1.6
const FLOAT_RISE_PX: float = 90.0
const MAX_FLOATERS: int = 24

var world: Node  ## anything with a `ship` (the player's Ship)

var _plates: Dictionary = {}  ## ship instance id -> {"ship", "root", "name", "bar", "masts"}
var _ships: Array[Ship] = []
var _scan_t: float = 0.0
var _floaters: Array[Dictionary] = []
var _last_gold: int = -1
var _hooked: Dictionary = {}


func _ready() -> void:
	layer = 4
	name = "WorldMarkers"


func _player() -> Ship:
	if world == null or not is_instance_valid(world):
		return null
	var s: Variant = world.get("ship")
	return s as Ship if s is Ship and is_instance_valid(s) else null


func _process(delta: float) -> void:
	var me: Ship = _player()
	if me == null:
		return
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = SCAN_EVERY_S
		_scan()
	_watch_gold(me)
	var cam: Camera3D = get_viewport().get_camera_3d()
	_update_plates(me, cam)
	_update_floaters(delta, cam)


func _scan() -> void:
	_ships.clear()
	if not is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group("ships"):
		var s: Ship = n as Ship
		if s == null or not is_instance_valid(s):
			continue
		_ships.append(s)
		var id: int = s.get_instance_id()
		if not _hooked.has(id):
			_hooked[id] = true
			s.hit_taken.connect(_on_hit.bind(s))
	for id: int in _plates.keys():
		var p: Dictionary = _plates[id]
		if not is_instance_valid(p["ship"]):
			(p["root"] as Control).queue_free()
			_plates.erase(id)


## The plate's side: "friend" (you and ships sailing with you), "foe", or "neutral" (merchants and the rest).
static func side_of(me_faction: String, other_faction: String) -> String:
	if other_faction == me_faction or other_faction == "player":
		return "friend"
	if other_faction == "merchant":
		return "neutral"
	return "foe" if FactionRel.hostile(me_faction, other_faction) else "neutral"


static func side_icon(side: String) -> String:
	return {"friend": "anchor", "foe": "skull", "neutral": "pirate/chest"}.get(side, "info")


static func side_color(side: String) -> Color:
	return {"friend": UiKit.FRIEND, "foe": UiKit.FOE}.get(side, UiKit.NEUTRAL)


## Alpha of a plate at a distance: full near, fading out, gone past the range.
static func plate_alpha(dist: float) -> float:
	if dist >= NAMEPLATE_RANGE_M:
		return 0.0
	return 1.0 - smoothstep(NAMEPLATE_FADE_M, NAMEPLATE_RANGE_M, dist)


func _update_plates(me: Ship, cam: Camera3D) -> void:
	var seen: Dictionary = {}
	for s: Ship in _ships:
		if not is_instance_valid(s) or s == me or s.damage == null or s.damage.sunk or s.stats == null:
			continue
		var d: float = s.global_position.distance_to(me.global_position)
		var a: float = plate_alpha(d)
		if a <= 0.01 or cam == null:
			continue
		var top: Vector3 = s.global_position + Vector3.UP * (s.stats.length_m * 0.55 + 3.0)
		if cam.is_position_behind(top):
			continue
		var id: int = s.get_instance_id()
		seen[id] = true
		var p: Dictionary = _plates.get(id, {})
		if p.is_empty():
			p = _make_plate(s, side_of(me.faction, s.faction))
			_plates[id] = p
		var root: Control = p["root"]
		root.visible = true
		root.modulate.a = a
		var at: Vector2 = cam.unproject_position(top)
		root.position = at - Vector2(root.size.x * 0.5, root.size.y)
		if p["bar"] != null:
			var bar: ProgressBar = p["bar"]
			bar.value = s.damage.hull_fraction() * 100.0
		if p["masts"] != null:
			var standing: int = s.damage.mast_down.count(false)
			(p["masts"] as Label).text = Loc.t("hud.plate_masts") % [standing, s.stats.mast_count] + ("   " + Loc.t("hud.plate_fire") if s.damage.fires_burning() > 0 else "")
	for id: int in _plates.keys():
		if not seen.has(id):
			(_plates[id]["root"] as Control).visible = false


func _make_plate(s: Ship, side: String) -> Dictionary:
	var root := VBoxContainer.new()
	root.set_meta("kind", "nameplate")
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 2)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	row.add_child(UiKit.icon(side_icon(side), 28))
	var title: String = s.display_label if s.display_label != "" else s.stats.display_name
	var name_l: Label = UiKit.label(title, UiKit.SIZE_SMALL, side_color(side), true)
	row.add_child(name_l)
	var bar: ProgressBar = null
	var masts: Label = null
	if side == "friend":
		bar = UiKit.bar(UiKit.FRIEND, 14)
		bar.custom_minimum_size = Vector2(140, 14)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		root.add_child(bar)
	else:
		masts = UiKit.label("", 17, Color.WHITE, false)
		masts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(masts)
	add_child(root)
	root.reset_size()
	return {"ship": s, "root": root, "name": name_l, "bar": bar, "masts": masts}


func plates_shown() -> int:
	var n: int = 0
	for id: int in _plates.keys():
		if (_plates[id]["root"] as Control).visible:
			n += 1
	return n


# ------------------------------------------------------------------ floating numbers


func _on_hit(result: Dictionary, s: Ship) -> void:
	if not is_instance_valid(s):
		return
	var me: Ship = _player()
	if me != null and s != me and s.global_position.distance_to(me.global_position) > NAMEPLATE_RANGE_M * 2.0:
		return  # a fight far away is not yours
	var hull: float = float(result.get("hull", 0.0))
	var jitter := Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
	var at: Vector3 = s.global_position + Vector3.UP * (s.stats.length_m * 0.4 + 3.0) + jitter
	if hull >= 1.0:
		spawn(at, "-%d" % roundi(hull), UiKit.FOE if s != me else Color(1.0, 0.45, 0.4), "", 30 if hull >= 60.0 else 24)
	var killed: int = int(result.get("killed", 0))
	if killed > 0:
		spawn(at + Vector3.UP * 3.0, Loc.t("hud.float_crew") % killed, Color.WHITE, "characters/character-a", 20)


func _watch_gold(me: Ship) -> void:
	if not Session.has_state():
		return
	var g: int = int(Session.state.get("gold", 0))
	if _last_gold >= 0 and g > _last_gold:
		spawn(me.global_position + Vector3.UP * (me.stats.length_m * 0.5 + 4.0), Loc.t("hud.float_gold") % (g - _last_gold), UiKit.GOLD, "dungeon/coin", 30)
	_last_gold = g


## A number or word that rises from a point in the world and fades.
func spawn(world_pos: Vector3, text: String, color: Color, icon_name: String = "", size: int = 24) -> void:
	while _floaters.size() >= MAX_FLOATERS:
		var old: Dictionary = _floaters.pop_front()
		(old["node"] as Control).queue_free()
	var node: Control
	if icon_name != "":
		node = UiKit.chip(icon_name, text, size, color)
	else:
		node = UiKit.label(text, size, color, true)
	node.set_meta("kind", "floater")
	node.visible = false
	add_child(node)
	_floaters.append({"node": node, "pos": world_pos, "age": 0.0})


func floaters_alive() -> int:
	return _floaters.size()


func _update_floaters(delta: float, cam: Camera3D) -> void:
	for i in range(_floaters.size() - 1, -1, -1):
		var f: Dictionary = _floaters[i]
		f["age"] = float(f["age"]) + delta
		var node: Control = f["node"]
		var t: float = float(f["age"]) / FLOAT_LIFE_S
		if t >= 1.0:
			node.queue_free()
			_floaters.remove_at(i)
			continue
		if cam == null or cam.is_position_behind(f["pos"]):
			node.visible = false
			continue
		node.visible = true
		var at: Vector2 = cam.unproject_position(f["pos"])
		var pop: float = 1.0 + 0.35 * (1.0 - smoothstep(0.0, 0.15, t))  # a little bounce as it appears
		node.scale = Vector2(pop, pop)
		node.position = at - node.size * 0.5 * pop - Vector2(0, FLOAT_RISE_PX * ease(t, 0.5))
		node.modulate.a = 1.0 - smoothstep(0.6, 1.0, t)
