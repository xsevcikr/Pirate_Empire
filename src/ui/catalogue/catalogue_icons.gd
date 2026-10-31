class_name CatalogueIcons
extends RefCounted
## Card pictures. Each icon is a PNG rendered once by tools/gen_catalogue_icons.gd from a Kenney model
## ("pirate/cannon") or from a few primitives ("proc/flintlock") for things the kits do not have.
## A missing PNG falls back to a coloured badge, so a new item works before its icon is rendered.

const DIR: String = "res://assets/icons/catalogue/"
const SIZE: int = 160


static func path_of(icon: String) -> String:
	return DIR + icon.replace("/", "__") + ".png"


static func texture(icon: String) -> Texture2D:
	if icon == "":
		return null
	var p: String = path_of(icon)
	if not ResourceLoader.exists(p):
		return null
	return load(p) as Texture2D


## Every icon any catalogue in the game can show. Add new sources here so the icon tool renders them.
static func all() -> PackedStringArray:
	var out: PackedStringArray = []
	for src: CatalogueSource in [ShipyardCatalogue.new(), OutfitterCatalogue.new(), LagoonCatalogue.new()]:
		for icon: String in src.icon_list():
			if not out.has(icon):
				out.append(icon)
	for icon: String in CollectionData.icon_list():  # the collection book's cards use the same pictures
		if not out.has(icon):
			out.append(icon)
	return out


## A small model built from primitives in Kenney's flat colours, for icons named "proc/<name>".
static func proc_model(name: String) -> Node3D:
	var root := Node3D.new()
	var wood := Color(0.55, 0.33, 0.2)
	var iron := Color(0.32, 0.34, 0.4)
	var brass := Color(0.95, 0.72, 0.3)
	match name:
		"flintlock":
			_part(root, _cyl(0.05, 0.05, 0.55), iron, Vector3(0.12, 0.12, 0), Vector3(0, 0, 90))
			_part(root, _box(Vector3(0.3, 0.08, 0.1)), wood, Vector3(0.0, 0.05, 0), Vector3.ZERO)
			_part(root, _box(Vector3(0.12, 0.3, 0.1)), wood, Vector3(-0.14, -0.08, 0), Vector3(0, 0, -25))
			_part(root, _box(Vector3(0.06, 0.06, 0.12)), brass, Vector3(-0.02, 0.16, 0), Vector3.ZERO)
		"musket":
			_part(root, _cyl(0.035, 0.035, 1.1), iron, Vector3(0.25, 0.06, 0), Vector3(0, 0, 90))
			_part(root, _box(Vector3(0.75, 0.08, 0.08)), wood, Vector3(-0.05, 0.0, 0), Vector3.ZERO)
			_part(root, _box(Vector3(0.28, 0.16, 0.08)), wood, Vector3(-0.48, -0.05, 0), Vector3(0, 0, -12))
			_part(root, _box(Vector3(0.05, 0.05, 0.1)), brass, Vector3(-0.2, 0.08, 0), Vector3.ZERO)
		"blunderbuss":
			_part(root, _cyl(0.12, 0.05, 0.55), brass, Vector3(0.22, 0.08, 0), Vector3(0, 0, -90))
			_part(root, _box(Vector3(0.4, 0.1, 0.1)), wood, Vector3(-0.15, 0.03, 0), Vector3.ZERO)
			_part(root, _box(Vector3(0.24, 0.18, 0.1)), wood, Vector3(-0.4, -0.04, 0), Vector3(0, 0, -15))
		"grenado":
			_part(root, _sphere(0.2), Color(0.2, 0.2, 0.26), Vector3.ZERO, Vector3.ZERO)
			_part(root, _cyl(0.06, 0.06, 0.08), brass, Vector3(0, 0.21, 0), Vector3.ZERO)
			_part(root, _cyl(0.015, 0.015, 0.18), Color(0.9, 0.85, 0.7), Vector3(0.04, 0.3, 0), Vector3(0, 0, -30))
			_part(root, _sphere(0.04), Color(1.0, 0.55, 0.15), Vector3(0.09, 0.38, 0), Vector3.ZERO, 1.5)
		"dagger":
			_part(root, _box(Vector3(0.42, 0.07, 0.02)), Color(0.82, 0.85, 0.92), Vector3(0.18, 0, 0), Vector3.ZERO)
			_part(root, _box(Vector3(0.04, 0.2, 0.06)), brass, Vector3(-0.04, 0, 0), Vector3.ZERO)
			_part(root, _cyl(0.035, 0.035, 0.18), wood, Vector3(-0.15, 0, 0), Vector3(0, 0, 90))
		"chain_shot":
			_part(root, _sphere(0.14), iron, Vector3(-0.28, 0, 0), Vector3.ZERO)
			_part(root, _sphere(0.14), iron, Vector3(0.28, 0, 0), Vector3.ZERO)
			for i in 5:
				_part(root, _torus(0.04, 0.012), Color(0.45, 0.46, 0.5), Vector3(-0.16 + i * 0.08, 0, 0), Vector3(90 if i % 2 == 0 else 0, 0, 0))
		"heated_shot":
			_part(root, _sphere(0.2), Color(0.85, 0.25, 0.1), Vector3.ZERO, Vector3.ZERO, 0.35)
			for i in 3:
				_part(root, _sphere(0.07 - i * 0.015), Color(1.0, 0.6, 0.15), Vector3(-0.1 + i * 0.1, 0.24 + i * 0.07, 0.05), Vector3.ZERO, 0.6)
		"axe":
			_part(root, _cyl(0.035, 0.035, 0.85), wood, Vector3(0, 0, 0), Vector3(0, 0, -30))
			var head := PrismMesh.new()
			head.size = Vector3(0.34, 0.26, 0.05)
			_part(root, head, Color(0.78, 0.81, 0.9), Vector3(0.33, 0.28, 0), Vector3(0, 0, 60))
			_part(root, _box(Vector3(0.09, 0.12, 0.07)), iron, Vector3(0.2, 0.35, 0), Vector3(0, 0, -30))
		"sail":
			_part(root, _cyl(0.03, 0.04, 1.3), wood, Vector3(0, 0, 0), Vector3.ZERO)
			_part(root, _cyl(0.02, 0.02, 0.8), wood, Vector3(0, 0.42, 0.04), Vector3(0, 0, 90))
			_part(root, _cyl(0.02, 0.02, 0.9), wood, Vector3(0, -0.25, 0.04), Vector3(0, 0, 90))
			var sail := BoxMesh.new()
			sail.size = Vector3(0.8, 0.62, 0.03)
			_part(root, sail, Color(0.97, 0.95, 0.88), Vector3(0, 0.1, 0.08), Vector3(8, 0, 0))
			_part(root, _box(Vector3(0.22, 0.14, 0.01)), Color(0.15, 0.15, 0.2), Vector3(0.11, 0.62, 0), Vector3.ZERO)
		_:
			if name.begins_with("shell_"):
				_shell(root, name)
			elif name.begins_with("flag_"):
				_flag(root, CollectionData.entry(name))
			elif name == "parrot":
				var p := ParrotModel.new()
				p.build()
				p.rotation_degrees.y = 160.0  # face the icon camera
				root.add_child(p)
	return root


## Seashells for the collection book, in the shell's own colour.
static func _shell(root: Node3D, name: String) -> void:
	var c: Color = CollectionData.entry(name).get("colour", Color(1, 0.8, 0.7))
	var rim: Color = c.darkened(0.25)
	match name:
		"shell_scallop":
			for i in 7:
				var rib := _box(Vector3(0.09, 0.03, 0.5))
				var a: float = -60.0 + i * 20.0
				_part(root, rib, c if i % 2 == 0 else rim, Vector3(sin(deg_to_rad(a)) * 0.22, 0, -cos(deg_to_rad(a)) * 0.22 + 0.1), Vector3(0, -a, 0))
			_part(root, _box(Vector3(0.2, 0.05, 0.12)), rim, Vector3(0, 0, 0.3), Vector3.ZERO)
		"shell_spiral":
			for i in 5:
				_part(root, _sphere(0.22 - i * 0.04), c if i % 2 == 0 else rim, Vector3(0, i * 0.12, 0), Vector3.ZERO)
		"shell_conch":
			var body := _cyl(0.05, 0.28, 0.6)
			_part(root, body, c, Vector3(0, 0, 0), Vector3(0, 0, 70))
			_part(root, _sphere(0.2), rim, Vector3(0.1, 0.05, 0), Vector3.ZERO)
			for i in 4:
				_part(root, _cyl(0.0, 0.05, 0.12), Color(1, 0.95, 0.9), Vector3(-0.05 + i * 0.1, 0.22, 0), Vector3.ZERO)
		"shell_starfish":
			for i in 5:
				var a: float = i * 72.0
				_part(root, _box(Vector3(0.12, 0.06, 0.36)), c, Vector3(sin(deg_to_rad(a)) * 0.18, 0, -cos(deg_to_rad(a)) * 0.18), Vector3(0, -a, 0))
			_part(root, _cyl(0.12, 0.12, 0.07), c, Vector3.ZERO, Vector3.ZERO)
			for i in 5:
				var a: float = i * 72.0
				_part(root, _sphere(0.03), Color(1, 0.95, 0.85), Vector3(sin(deg_to_rad(a)) * 0.2, 0.04, -cos(deg_to_rad(a)) * 0.2), Vector3.ZERO)
		"shell_sand_dollar":
			_part(root, _cyl(0.3, 0.3, 0.05), c, Vector3.ZERO, Vector3.ZERO)
			for i in 5:
				var a: float = i * 72.0
				_part(root, _box(Vector3(0.04, 0.02, 0.14)), rim, Vector3(sin(deg_to_rad(a)) * 0.12, 0.03, -cos(deg_to_rad(a)) * 0.12), Vector3(0, -a, 0))
		"shell_pearl":
			var top := _sphere(0.3)
			_part(root, top, Color(0.55, 0.5, 0.6), Vector3(0, 0.05, 0.12), Vector3(-60, 0, 0)).scale = Vector3(1, 0.25, 1)
			_part(root, _sphere(0.3), Color(0.55, 0.5, 0.6), Vector3(0, -0.05, 0), Vector3.ZERO).scale = Vector3(1, 0.25, 1)
			_part(root, _sphere(0.13), c, Vector3(0, 0.08, -0.02), Vector3.ZERO, 0.25)


## A flag on a short pole: the cloth in the flag's colour with a simple mark.
static func _flag(root: Node3D, f: Dictionary) -> void:
	var wood := Color(0.55, 0.33, 0.2)
	_part(root, _cyl(0.025, 0.03, 1.2), wood, Vector3(0, 0, 0), Vector3.ZERO)
	_part(root, _sphere(0.05), Color(0.95, 0.72, 0.3), Vector3(0, 0.62, 0), Vector3.ZERO)
	_part(root, _box(Vector3(0.7, 0.45, 0.03)), f.get("cloth", Color.WHITE), Vector3(0.37, 0.3, 0), Vector3.ZERO)
	var mark: Color = f.get("mark", Color.WHITE)
	match str(f.get("id", "")):
		"flag_pirate", "flag_golden_skull", "flag_red_jack":
			_part(root, _sphere(0.1), mark, Vector3(0.37, 0.34, 0.03), Vector3.ZERO).scale = Vector3(1, 1, 0.3)
			_part(root, _box(Vector3(0.32, 0.04, 0.02)), mark, Vector3(0.37, 0.2, 0.03), Vector3(0, 0, 30))
			_part(root, _box(Vector3(0.32, 0.04, 0.02)), mark, Vector3(0.37, 0.2, 0.03), Vector3(0, 0, -30))
		"flag_navy":
			_part(root, _box(Vector3(0.7, 0.07, 0.02)), mark, Vector3(0.37, 0.3, 0.03), Vector3.ZERO)
			_part(root, _box(Vector3(0.07, 0.45, 0.02)), mark, Vector3(0.3, 0.3, 0.03), Vector3.ZERO)
		"flag_rainbow":
			var bands: Array[Color] = [Color(0.9, 0.2, 0.2), Color(1.0, 0.6, 0.1), Color(1.0, 0.9, 0.2), Color(0.3, 0.75, 0.3), Color(0.25, 0.45, 0.9)]
			for i in bands.size():
				_part(root, _box(Vector3(0.7, 0.09, 0.02)), bands[i], Vector3(0.37, 0.48 - i * 0.09, 0.03), Vector3.ZERO)
		_:
			_part(root, _sphere(0.11), mark, Vector3(0.37, 0.3, 0.03), Vector3.ZERO).scale = Vector3(1, 1, 0.3)


static func _part(root: Node3D, mesh: Mesh, c: Color, at: Vector3, rot_deg: Vector3, emit: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Kenney.flat(c, emit, true)
	mi.position = at
	mi.rotation_degrees = rot_deg
	root.add_child(mi)
	return mi


static func _box(size: Vector3) -> Mesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _cyl(top: float, bottom: float, h: float) -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 10
	return m


static func _sphere(r: float) -> Mesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	return m


static func _torus(r: float, t: float) -> Mesh:
	var m := TorusMesh.new()
	m.inner_radius = r - t
	m.outer_radius = r + t
	m.rings = 10
	m.ring_segments = 6
	return m
