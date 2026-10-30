extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/gen_catalogue_icons.gd [-- kit/model ...]
## Renders every catalogue card picture (CatalogueIcons.all(), or just the icons named) to a transparent PNG in
## assets/icons/catalogue/. Run it again after adding an item with a new icon, then commit the PNGs.

const VIEW_DIR: Vector3 = Vector3(1.0, 0.75, 1.25)

var _queue: PackedStringArray = []
var _stage: Node3D
var _cam: Camera3D
var _model: Node3D
var _wait: int = 0
var _current: String = ""


func _initialize() -> void:
	_queue = OS.get_cmdline_user_args()
	if _queue.is_empty():
		_queue = CatalogueIcons.all()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CatalogueIcons.DIR))
	root.size = Vector2i(CatalogueIcons.SIZE * 2, CatalogueIcons.SIZE * 2)
	root.transparent_bg = true
	_stage = Node3D.new()
	root.add_child(_stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.72)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.0
	sun.rotation_degrees = Vector3(-50, 35, 0)
	_stage.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_stage.add_child(_cam)
	_cam.make_current()


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if _current != "":
		var img: Image = _trim(root.get_texture().get_image())
		img.save_png(ProjectSettings.globalize_path(CatalogueIcons.path_of(_current)))
		print("icon ", _current)
		_model.queue_free()
		_current = ""
	if _queue.is_empty():
		quit(0)
		return true
	_current = _queue[0]
	_queue.remove_at(0)
	var parts: PackedStringArray = _current.split("/")
	_model = CatalogueIcons.proc_model(parts[1]) if parts[0] == "proc" else Kenney.spawn(parts[0], parts[1])
	_stage.add_child(_model)
	_frame.call_deferred()
	_wait = 4
	return false


func _frame() -> void:
	var box := AABB()
	var first: bool = true
	var meshes: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in Kenney.meshes_of(_model, meshes):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var c: Vector3 = box.get_center()
	_cam.size = box.size.length() * 0.92
	_cam.look_at_from_position(c + VIEW_DIR.normalized() * (box.size.length() + 4.0), c, Vector3.UP)
	_cam.near = 0.05
	_cam.far = box.size.length() * 4.0 + 20.0


## Crops to the drawn pixels and scales back up, so a tall mast or a thin sword still fills the card picture.
func _trim(img: Image) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return img
	var part: Image = img.get_region(used)
	var room: float = CatalogueIcons.SIZE - 10.0
	var k: float = room / maxf(used.size.x, used.size.y)
	part.resize(maxi(1, roundi(used.size.x * k)), maxi(1, roundi(used.size.y * k)), Image.INTERPOLATE_LANCZOS)
	var out := Image.create(CatalogueIcons.SIZE, CatalogueIcons.SIZE, false, Image.FORMAT_RGBA8)
	out.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), (Vector2i(CatalogueIcons.SIZE, CatalogueIcons.SIZE) - part.get_size()) / 2)
	return out
