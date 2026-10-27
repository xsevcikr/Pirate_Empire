class_name DockDistrict
extends Node3D
## The walkable dock district of a port: a street of buildings in the faction's style, signs over each door, and
## a captain you walk with WASD. Standing at a door and pressing E opens that screen; the pier end returns to the ship.

signal door_used(kind: String)
signal left

const ORIGIN: Vector3 = Vector3(0.0, 600.0, 0.0)
const WALK_SPEED_MS: float = 5.5
const STREET_HALF_WIDTH_M: float = 9.0
const STREET_LENGTH_M: float = 70.0
const DOOR_REACH_M: float = 4.2
const CAM_BACK_M: float = 9.0
const CAM_UP_M: float = 5.5

var port_id: String = PortData.START_PORT
var active: bool = true
var captain: Node3D
var camera: Camera3D
var doors: Array[Dictionary] = []  ## {kind, pos Vector3, key}
var prompt: Label
var _prev_camera: Camera3D
var _walk_t: float = 0.0
var _prompt_kind: String = ""


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = ORIGIN


func _ready() -> void:
	var port: Dictionary = PortData.PORTS[port_id]
	var style: Dictionary = IslandData.style(port["faction"])
	_build_ground(style)
	var kinds: Array[String] = ["market", "shipyard", "tavern", "outfitter", "quests"]
	if Finance.has_bank(port_id):
		kinds.append("bank")
	for i in kinds.size():
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var z: float = -STREET_LENGTH_M * 0.5 + 8.0 + float(i / 2) * 20.0
		_building(kinds[i], Vector3(side * (STREET_HALF_WIDTH_M + 6.0), 0.0, z), side, style)
	_build_pier(style)
	_build_town(style)
	_build_sky_and_sea()
	captain = _make_captain()
	captain.position = Vector3(0.0, 0.0, STREET_LENGTH_M * 0.5 - 6.0)
	add_child(captain)
	camera = Camera3D.new()
	camera.fov = 65.0
	add_child(camera)
	var vp: Viewport = get_viewport()
	_prev_camera = vp.get_camera_3d() if vp != null else null
	camera.make_current()
	var layer := CanvasLayer.new()
	layer.layer = 54
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	prompt = Label.new()
	prompt.add_theme_font_size_override("font_size", 26)
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	prompt.add_theme_constant_override("outline_size", 8)
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_top = -170.0
	prompt.offset_left = -400.0
	prompt.offset_right = 400.0
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(prompt)
	var title := Label.new()
	title.text = "%s - %s" % [port["name"], Loc.t("dock.district")]
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.position = Vector2(32, 24)
	layer.add_child(title)
	_place_camera(1.0)


func _exit_tree() -> void:
	if _prev_camera != null and is_instance_valid(_prev_camera) and _prev_camera.is_inside_tree():
		_prev_camera.make_current()


# ---- stage ----------------------------------------------------------------------------------------

func _mat(c: Color, _rough: float = 0.9) -> ShaderMaterial:
	return Kenney.flat(c)


func _box(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(color)
	mi.position = at
	add_child(mi)
	return mi


func _build_ground(style: Dictionary) -> void:
	_box(Vector3(STREET_HALF_WIDTH_M * 2.0 + 36.0, 1.0, STREET_LENGTH_M + 24.0), Vector3(0, -0.5, 0), Color(0.38, 0.8, 0.55))
	_box(Vector3(STREET_HALF_WIDTH_M * 2.0, 0.1, STREET_LENGTH_M + 24.0), Vector3(0, 0.02, 0), Color(0.95, 0.75, 0.6))


func _building(kind: String, at: Vector3, side: float, style: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash() + port_id.hash()
	var size := Vector3(9.0, 6.0 + float(kind.length() % 3), 12.0)
	var floors: int = 2 + (kind.length() % 2)
	TownBuilder.house(self, Vector3(at.x, 0.0, at.z), (-90.0 if side > 0.0 else 90.0), 12.0, 9.0, floors, style["roof"], rng)
	var door_pos: Vector3 = at + Vector3(-side * (size.x * 0.5 + 0.05), 1.4, 0)
	var sign := Label3D.new()
	sign.text = Loc.t("dock.sign_" + kind)
	sign.font_size = 72
	sign.pixel_size = 0.012
	sign.outline_size = 14
	sign.position = at + Vector3(-side * (size.x * 0.5 + 1.2), 4.6, 0)
	sign.rotation.y = -PI * 0.5 * side
	add_child(sign)
	var stand: Vector3 = at + Vector3(-side * (size.x * 0.5 + 2.2), 0, 0)
	doors.append({"kind": kind, "pos": stand})
	var lamp := OmniLight3D.new()
	lamp.position = stand + Vector3(0, 3.5, 0)
	lamp.omni_range = 12.0
	lamp.light_color = Color(1.0, 0.78, 0.45)
	add_child(lamp)
	_lantern_post(stand + Vector3(0, 0, 1.6))


func _lantern_post(at: Vector3) -> void:
	_box(Vector3(0.12, 3.2, 0.12), at + Vector3(0, 1.6, 0), Color(0.31, 0.32, 0.38))
	_box(Vector3(0.6, 0.06, 0.06), at + Vector3(0.28, 3.1, 0), Color(0.31, 0.32, 0.38))
	var glow: ShaderMaterial = Kenney.flat(Color(1.0, 0.75, 0.27), 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = DeckArt.box(Vector3(0.22, 0.3, 0.22))
	mi.material_override = glow
	mi.position = at + Vector3(0.5, 2.9, 0)
	add_child(mi)


## The town around the street: a cobbled floor, a square with a well and stalls, a church, rows of houses behind the
## shop fronts, walls and a castle at the far end, and townsfolk who walk about.
func _build_town(style: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = port_id.hash() * 7 + 3
	TownBuilder.cobbles(self, STREET_HALF_WIDTH_M, STREET_LENGTH_M * 0.5 + 12.0, rng)
	TownBuilder.street_clutter(self, STREET_HALF_WIDTH_M, STREET_LENGTH_M * 0.5, rng)
	TownBuilder.well(self, Vector3(0.0, 0.0, 2.0))
	for i in 4:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		TownBuilder.stall(self, Vector3(side * 5.4, 0.0, -2.0 + 6.0 * float(i / 2) - (6.0 if i < 2 else 0.0)), -90.0 * side, rng)
	TownBuilder.church(self, Vector3(-30.0, 0.0, -12.0), 90.0)
	for k in 10:  # rows of houses behind the shop fronts
		var sd: float = -1.0 if k % 2 == 0 else 1.0
		var z: float = -STREET_LENGTH_M * 0.5 + 6.0 + float(k / 2) * 14.0
		TownBuilder.house(self, Vector3(sd * (STREET_HALF_WIDTH_M + 24.0), 0.0, z), -90.0 * sd, 11.0, rng.randf_range(8.0, 11.0), rng.randi_range(2, 3), style["roof"], rng)
	var far_z: float = -STREET_LENGTH_M * 0.5 - 14.0
	TownBuilder.castle(self, Vector3(0.0, 0.0, far_z - 18.0), style["flag"])
	TownBuilder.wall_run(self, Vector3(-30.0, 0.0, far_z + 4.0), Vector3(-14.0, 0.0, far_z - 8.0))
	TownBuilder.wall_run(self, Vector3(30.0, 0.0, far_z + 4.0), Vector3(14.0, 0.0, far_z - 8.0))
	TownBuilder.round_tower(self, Vector3(-30.0, 0.0, far_z + 4.0), 3.2, 12.0, style["flag"])
	TownBuilder.round_tower(self, Vector3(30.0, 0.0, far_z + 4.0), 3.2, 12.0, style["flag"])
	for sd in [-1.0, 1.0]:
		TownBuilder.wall_run(self, Vector3(sd * 38.0, 0.0, far_z + 4.0), Vector3(sd * 38.0, 0.0, STREET_LENGTH_M * 0.5))
	_spawn_people(rng, style)


var walkers: Array[TownWalker] = []
var _pair_t: float = 0.0


func _spawn_people(rng: RandomNumberGenerator, style: Dictionary) -> void:
	var spots: Array[Vector3] = [Vector3(0, 0, 2), Vector3(-5, 0, -4), Vector3(5, 0, -4), Vector3(-6, 0, 12), Vector3(6, 0, 12), Vector3(0, 0, -18), Vector3(-7, 0, -22), Vector3(7, 0, -26), Vector3(0, 0, 22)]
	var kinds: Array[String] = ["peasant", "peasant", "merchant", "townswoman", "townswoman", "peasant", "merchant", "townswoman", "guard", "guard", "peasant", "townswoman"]
	for i in kinds.size():
		var w := TownWalker.new()
		w.setup(kinds[i], 11 + i * 17, spots, port_id.hash() + i * 31)
		add_child(w)
		walkers.append(w)


func _build_pier(style: Dictionary) -> void:
	var z: float = STREET_LENGTH_M * 0.5 + 4.0
	_box(Vector3(5.0, 0.5, 14.0), Vector3(0, 0.0, z + 4.0), Color(0.69, 0.38, 0.25))
	_box(Vector3(0.4, 6.0, 0.4), Vector3(0, 3.0, z + 10.5), Color(0.69, 0.38, 0.25))
	_box(Vector3(0.1, 1.6, 2.6), Vector3(0, 5.2, z + 11.8), style["flag"])
	var sign := Label3D.new()
	sign.text = Loc.t("dock.sign_pier")
	sign.font_size = 64
	sign.pixel_size = 0.012
	sign.outline_size = 12
	sign.position = Vector3(0, 3.2, z + 10.0)
	sign.rotation.y = PI
	add_child(sign)
	doors.append({"kind": "pier", "pos": Vector3(0, 0, z + 5.0)})


func _build_sky_and_sea() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	Look.apply_sun(sun, 90.0)
	add_child(sun)
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	Look.apply_environment(env)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var ocean := Ocean.new()
	ocean.model = WaveModel.new(2.0, Vector2(1, 0))
	ocean.position = Vector3(0, -1.6, 0)
	add_child(ocean)


var _captain_f := FighterState.new()


## The captain is a logical node that the walking code moves; the visible man is a Kenney character that follows it.
func _make_captain() -> Node3D:
	var n := Node3D.new()
	_captain_f.id = 1
	_captain_f.kind = "captain_player"
	_captain_f.melee = "none"
	var v := DeckFighterView.new()
	v.fighter = _captain_f
	v.show_label = false
	v.pose_idle_only = true
	add_child(v)
	return n


# ---- walking ----------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_pair_t += delta
	if _pair_t > 1.5:
		_pair_t = 0.0
		TownWalker.pair_up(walkers)
	if not active:
		return
	var move: Vector2 = read_move()
	step(move, delta)
	if move.length() > 0.1:
		Sfx.play("step_wood")
	_place_camera(delta)
	_update_prompt()
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("deck_use"):
		use_nearest()
	elif Input.is_action_just_pressed("pause"):
		leave()


func read_move() -> Vector2:
	return Vector2(
		Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left"),
		Input.get_action_strength("sail_down") - Input.get_action_strength("sail_up"))


## Walk the captain; x is across the street, y along it (towards the pier is positive). Stays inside the street.
func step(move: Vector2, delta: float) -> void:
	if move.length() > 0.1:
		var dir: Vector2 = move.normalized()
		var p: Vector3 = captain.position + Vector3(dir.x, 0.0, dir.y) * WALK_SPEED_MS * delta
		var pier_open: bool = p.z > STREET_LENGTH_M * 0.5 - 1.0
		p.x = clampf(p.x, -(STREET_HALF_WIDTH_M - 0.8) if not pier_open else -2.2, (STREET_HALF_WIDTH_M - 0.8) if not pier_open else 2.2)
		p.z = clampf(p.z, -STREET_LENGTH_M * 0.5, STREET_LENGTH_M * 0.5 + 10.0)
		captain.rotation.y = lerp_angle(captain.rotation.y, atan2(dir.x, dir.y), clampf(delta * 12.0, 0.0, 1.0))
		captain.position = p
		_captain_f.dir = dir
		_walk_t += delta * 9.0
		captain.position.y = 0.0
	_captain_f.move_intent = move
	_captain_f.pos = Vector2(captain.position.x, captain.position.z)


## The door the captain stands at, or "".
func nearest_door() -> String:
	var best: String = ""
	var best_d: float = DOOR_REACH_M
	for d in doors:
		var dist: float = Vector2(captain.position.x, captain.position.z).distance_to(Vector2((d["pos"] as Vector3).x, (d["pos"] as Vector3).z))
		if dist < best_d:
			best_d = dist
			best = d["kind"]
	return best


func use_nearest() -> void:
	var kind: String = nearest_door()
	if kind == "pier":
		leave()
	elif kind != "":
		active = false
		door_used.emit(kind)


func leave() -> void:
	left.emit()
	queue_free()


func _update_prompt() -> void:
	var kind: String = nearest_door()
	if kind != _prompt_kind:
		_prompt_kind = kind
		prompt.text = "" if kind == "" else Loc.t("dock.use") % Loc.t("dock.sign_" + kind)


func _place_camera(delta: float) -> void:
	if not camera.is_inside_tree():
		return
	var focus: Vector3 = captain.position + Vector3(0, 1.4, 0)
	var want: Vector3 = focus + Vector3(0.0, CAM_UP_M, CAM_BACK_M)
	camera.position = camera.position.lerp(want, clampf(delta * 5.0, 0.0, 1.0))
	camera.look_at(global_position + focus + Vector3(0, 0, -4.0), Vector3.UP)
