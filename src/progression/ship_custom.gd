class_name ShipCustom
extends RefCounted
## Puts the captain's choices on a ship's look: flag, sails, hull paint, figurehead, stern lanterns and the name
## on the stern. Safe to call again whenever a choice changes.


static func flag_texture(pixels: Array) -> ImageTexture:
	var img := Image.create(CustomizationData.PIXEL_SIZE, CustomizationData.PIXEL_SIZE, false, Image.FORMAT_RGBA8)
	for y in CustomizationData.PIXEL_SIZE:
		for x in CustomizationData.PIXEL_SIZE:
			img.set_pixel(x, y, CustomizationData.PIXEL_PALETTE[int(pixels[y * CustomizationData.PIXEL_SIZE + x])])
	return ImageTexture.create_from_image(img)


static func apply(ship: Ship, custom: Dictionary) -> void:
	if ship == null or ship.visuals == null or custom.is_empty():
		return
	var v: ShipVisuals = ship.visuals
	var flag: Dictionary = custom["flag"]
	var fc: Color = CustomizationData.FLAG_COLORS[int(flag["color"])]
	var mark: Color = Color.WHITE if fc.get_luminance() < 0.5 else Color(0.05, 0.05, 0.06)
	var use_pixels: bool = (flag["pixels"] as Array).size() == CustomizationData.PIXEL_SIZE * CustomizationData.PIXEL_SIZE
	var tex: ImageTexture = flag_texture(flag["pixels"]) if use_pixels else null
	for i in v.flag_materials.size():
		var m: ShaderMaterial = v.flag_materials[i]
		var main: bool = i == v.flag_materials.size() - 1  # the tallest mast carries the captain's colours
		if not main:
			continue
		m.set_shader_parameter("base_color", Vector3(fc.r, fc.g, fc.b))
		m.set_shader_parameter("mark_color", Vector3(mark.r, mark.g, mark.b))
		m.set_shader_parameter("field_color", Vector3(mark.r, mark.g, mark.b) * 0.6 + Vector3(fc.r, fc.g, fc.b) * 0.4)
		m.set_shader_parameter("skull", 1.0 if int(flag["emblem"]) <= 1 else 0.0)
		m.set_shader_parameter("layout", int(flag["layout"]))
		m.set_shader_parameter("use_pixels", use_pixels)
		if tex != null:
			m.set_shader_parameter("pixel_tex", tex)
	var sail: Dictionary = custom["sail"]
	var canvas: Color = CustomizationData.SAIL_COLORS[int(sail["color"])]
	var pattern: int = int(sail["pattern"])
	# a variant's own colours show until the captain picks something else
	var livery: bool = ShipLivery.has_livery(ship.stats.class_id)
	if livery:
		ShipLivery.paint(v)
	for m: ShaderMaterial in v.sail_materials if not livery or int(sail["color"]) != 0 or pattern != 0 else []:
		m.set_shader_parameter("custom", int(sail["color"]) != 0 or pattern != 0)
		m.set_shader_parameter("canvas_color", Vector3(canvas.r, canvas.g, canvas.b))
		m.set_shader_parameter("pattern", pattern)
		var ink: Color = Color(0.08, 0.08, 0.08) if canvas.get_luminance() > 0.35 else Color(0.9, 0.9, 0.85)
		m.set_shader_parameter("mark_color", Vector3(ink.r, ink.g, ink.b))
	var hull: Dictionary = custom["hull"]
	var paint: Color = CustomizationData.HULL_PAINT_COLORS[int(hull["paint"])]
	if v.hull_material != null and not (livery and int(hull["paint"]) == 0):
		v.hull_material.set_shader_parameter("paint", Vector3(paint.r, paint.g, paint.b))
		v.hull_material.set_shader_parameter("paint_mix", 0.0 if int(hull["paint"]) == 0 else 0.85)
	_rebuild_extras(ship, custom)


static func _mat(c: Color, emit: float = 0.0, _metal: float = 0.0) -> ShaderMaterial:
	return Kenney.flat(c, minf(emit * 0.2, 0.45))


static func _rebuild_extras(ship: Ship, custom: Dictionary) -> void:
	var old: Node = ship.visuals.root.get_node_or_null("Custom")
	if old != null:
		ship.visuals.root.remove_child(old)
		old.queue_free()
	var extras := Node3D.new()
	extras.name = "Custom"
	ship.visuals.root.add_child(extras)
	var L: float = ship.stats.length_m
	var F: float = ship.stats.freeboard_m
	var head: String = str(custom["figurehead"])
	if head != "plain":
		var fig := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.35
		sm.height = 0.7
		fig.mesh = sm
		fig.material_override = _mat(_figurehead_color(head), 0.0, 0.2)
		fig.position = Vector3(0, F * 0.9, -L * 0.5 - 0.2)
		extras.add_child(fig)
		var body := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.18
		cm.bottom_radius = 0.28
		cm.height = 1.0
		body.mesh = cm
		body.material_override = fig.material_override
		body.position = Vector3(0, F * 0.9 - 0.6, -L * 0.5 - 0.1)
		body.rotation_degrees.x = 25.0
		extras.add_child(body)
	var hull: Dictionary = custom["hull"]
	var trim_c: Color = CustomizationData.TRIM_COLORS[int(hull["trim"])]
	if bool(hull["gold_leaf"]):
		trim_c = Color(0.95, 0.78, 0.2)
	var rail := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(ship.stats.beam_m * 0.98, 0.18, 0.2)
	rail.mesh = bm
	rail.material_override = _mat(trim_c, 0.0, 0.9 if bool(hull["gold_leaf"]) else 0.0)
	rail.position = Vector3(0, F * 1.25, L * 0.37 + 0.35)
	extras.add_child(rail)
	var style: String = CustomizationData.LANTERN_STYLES[int(hull["lanterns"])]
	if style != "none":
		var lc: Color = Color(0.5, 1.0, 0.7) if style == "ghostly" else Color(1.0, 0.75, 0.35)
		for s in [-1.0, 1.0]:
			var lamp := MeshInstance3D.new()
			var lm := SphereMesh.new()
			lm.radius = 0.22
			lm.height = 0.44
			lamp.mesh = lm
			lamp.material_override = _mat(lc, 2.0)
			lamp.position = Vector3(s * ship.stats.beam_m * 0.4, F * 1.9, L * 0.4)
			extras.add_child(lamp)
	var label := Label3D.new()
	label.text = str(Session.state.get("ship_name", "")) if Session.has_state() else ""
	label.font_size = 48
	label.pixel_size = 0.012
	label.modulate = trim_c
	label.outline_size = 6
	label.position = Vector3(0, F * 1.05, L * 0.37 + 0.42)
	label.rotation_degrees.y = 0.0
	extras.add_child(label)


static func _figurehead_color(id: String) -> Color:
	var order: int = CustomizationData.FIGUREHEAD_ORDER.find(id)
	return Color.from_hsv(float(order) / 10.0, 0.5, 0.85)
