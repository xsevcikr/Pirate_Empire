class_name LagoonBuildMode
extends Node3D
## Build mode over the lagoon: a camera above the island looking in from the harbour, the plot grid drawn on the
## ground, and a panel of buildings. Pick a building, point at a free plot (mouse or arrow keys) and a see-through
## copy shows where it goes; click or Enter builds it, R turns it. Clicking a building selects it to upgrade, turn,
## repair or pull down. Esc or Done goes back ashore.

signal finished

const CAM_BACK_M: float = 120.0
const CAM_UP_M: float = 115.0

var lagoon: LagoonScene
var cursor: Vector2i = Vector2i(1, 0)
var selected_type: String = ""
var rot: int = 0
var zoom: float = 1.0
var _cam: Camera3D
var _prev_cam: Camera3D
var _grid: MeshInstance3D
var _cursor_mesh: MeshInstance3D
var _ghost: Node3D
var _ghost_key: String = ""
var _ui: CanvasLayer
var _info: Label
var _gold: Label
var _actions: HBoxContainer
var _ghost_mat: StandardMaterial3D
var _hidden: Array[CanvasLayer] = []


func _ready() -> void:
	name = "LagoonBuildMode"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prev_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.far = 4000.0
	add_child(_cam)
	_cam.make_current()
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.albedo_color = Color(0.45, 1.0, 0.6, 0.7)
	_grid = MeshInstance3D.new()
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cursor_mesh = MeshInstance3D.new()
	_cursor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cursor_mesh.mesh = _quad(LagoonData.CELL_M * 0.96)
	_cursor_mesh.material_override = _overlay_mat(Color(1, 0.85, 0.2, 0.55))
	if lagoon != null:
		lagoon.add_child(_grid)
		lagoon.add_child(_cursor_mesh)
	_build_ui()
	_hide_hud()
	refresh()


## The sailing HUD and prompts step aside while building.
func _hide_hud() -> void:
	if get_parent() == null:
		return
	for n in get_parent().get_children():
		if n is CanvasLayer and (n as CanvasLayer).visible and (n as CanvasLayer).layer < 50:
			(n as CanvasLayer).visible = false
			_hidden.append(n)


func _exit_tree() -> void:
	for n in [_grid, _cursor_mesh, _ghost]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	if _prev_cam != null and is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	for l in _hidden:
		if is_instance_valid(l):
			l.visible = true


func state() -> Dictionary:
	return Session.state


## Redraw the grid, the cursor, the ghost and the panel after anything changed.
func refresh() -> void:
	if lagoon != null:
		lagoon.sync()
		_grid.mesh = _grid_mesh()
	_place_camera()
	_update_cursor()
	_update_panel()


func _place_camera() -> void:
	if lagoon == null:
		return
	var c: Vector2 = LagoonData.pad_center()
	var f: Vector2 = LagoonData.harbour_dir()
	var centre: Vector3 = lagoon.to_global(Vector3(c.x, LagoonData.PAD_H_M, c.y))
	var back: Vector3 = Vector3(f.x, 0.0, f.y) * CAM_BACK_M * zoom
	_cam.global_position = centre + back + Vector3.UP * CAM_UP_M * zoom
	_cam.look_at(centre - Vector3(f.x, 0.0, f.y) * 8.0, Vector3.UP)


# ---- grid and cursor -------------------------------------------------------------------------

func _overlay_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	return m


func _quad(size: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h: float = size * 0.5
	for v in [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(-h, 0, h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]:
		st.set_color(Color.WHITE)
		st.add_vertex(v)
	return st.commit()


## Every plot of the biggest lagoon: open and free (green), built (blue), not yet open at this rank (grey).
func _grid_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s: Dictionary = state()
	var rank: int = Lagoon.rank_of(s)
	var right: Vector2 = LagoonData.cell_right()
	var fwd: Vector2 = LagoonData.harbour_dir()
	var h: float = LagoonData.CELL_M * 0.45
	for c in LagoonData.cells(LagoonData.RANKS.size() - 1):
		var col: Color = Color(0.5, 0.5, 0.55, 0.18)
		if LagoonData.cell_open(rank, c):
			col = Color(0.35, 0.95, 0.5, 0.3) if Lagoon.building_at(s, c).is_empty() else Color(0.35, 0.6, 1.0, 0.25)
		var p: Vector2 = LagoonData.cell_local(c)
		var y: float = LagoonData.PAD_H_M + 0.12
		var corners: Array[Vector3] = []
		for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var q: Vector2 = p + right * (k.x * h) + fwd * (k.y * h)
			corners.append(Vector3(q.x, y, q.y))
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.add_vertex(corners[idx])
	var m: ArrayMesh = st.commit()
	_grid.material_override = _overlay_mat(Color.WHITE)
	return m


func _update_cursor() -> void:
	if lagoon == null:
		return
	var p: Vector2 = LagoonData.cell_local(cursor)
	_cursor_mesh.position = Vector3(p.x, LagoonData.PAD_H_M + 0.2, p.y)
	_cursor_mesh.rotation_degrees.y = LagoonData.facing_yaw()
	var ok: bool = _cursor_ok()
	(_cursor_mesh.material_override as StandardMaterial3D).albedo_color = Color(1, 0.85, 0.2, 0.6) if ok else Color(1, 0.3, 0.25, 0.55)
	_update_ghost()


func _cursor_ok() -> bool:
	if selected_type != "":
		return Lagoon.place_problem(state(), selected_type, cursor) == ""
	return LagoonData.cell_open(Lagoon.rank_of(state()), cursor)


## A see-through copy of the chosen building on a free plot under the cursor.
func _update_ghost() -> void:
	var want: String = ""
	if selected_type != "" and Lagoon.building_at(state(), cursor).is_empty() and LagoonData.cell_open(Lagoon.rank_of(state()), cursor):
		want = "%s/%d" % [selected_type, rot]
	if want != _ghost_key:
		if _ghost != null and is_instance_valid(_ghost):
			_ghost.queue_free()
		_ghost = null
		_ghost_key = want
		if want != "" and lagoon != null:
			_ghost = LagoonArt.building(selected_type, 1, 1)
			_ghost.set_meta("kind", "lagoon_ghost")
			for mi in Kenney.meshes_of(_ghost):
				mi.material_override = _ghost_mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lagoon.add_child(_ghost)
	if _ghost != null:
		_ghost.position = lagoon.cell_pos(cursor)
		_ghost.rotation_degrees.y = LagoonData.facing_yaw() + 90.0 * rot
		_ghost_mat.albedo_color = Color(0.45, 1.0, 0.6, 0.7) if Lagoon.place_problem(state(), selected_type, cursor) == "" else Color(1.0, 0.4, 0.35, 0.7)


# ---- the panel -------------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 53
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(330, 0)
	_ui.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title := Label.new()
	title.text = Loc.t("lagoon.build_title")
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	_gold = Label.new()
	box.add_child(_gold)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for t in LagoonData.ORDER:
		var b := Button.new()
		b.name = "Pick_" + t
		b.text = "%s  %d g" % [Loc.t("lagoon.b_" + t), LagoonData.cost(t, 1)]
		b.tooltip_text = Loc.t("lagoon.d_" + t)
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(pick.bind(t))
		list.add_child(b)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(320, 0)
	box.add_child(_info)
	_actions = HBoxContainer.new()
	box.add_child(_actions)
	var done := Button.new()
	done.text = Loc.t("lagoon.done")
	done.pressed.connect(finish)
	box.add_child(done)
	var hint := Label.new()
	hint.text = Loc.t("lagoon.build_hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(320, 0)
	hint.add_theme_font_size_override("font_size", 13)
	box.add_child(hint)


func _update_panel() -> void:
	if _info == null:
		return
	var s: Dictionary = state()
	_gold.text = Loc.t("lagoon.gold") % int(s["gold"])
	for t in LagoonData.ORDER:
		var b: Button = _ui.find_child("Pick_" + t, true, false)
		if b != null:
			b.set_pressed_no_signal(t == selected_type)
			b.disabled = LagoonData.cost(t, 1) > int(s["gold"])
	for c in _actions.get_children():
		c.queue_free()
	var bld: Dictionary = Lagoon.building_at(s, cursor)
	if selected_type != "":
		var problem: String = Lagoon.place_problem(s, selected_type, cursor)
		_info.text = "%s\n%s" % [Loc.t("lagoon.d_" + selected_type), Loc.t("lagoon.place_" + (problem if problem != "" else "ok"))]
		return
	if bld.is_empty():
		_info.text = Loc.t("lagoon.pick_hint") if LagoonData.cell_open(Lagoon.rank_of(s), cursor) else Loc.t("lagoon.place_closed")
		return
	var t2: String = bld["t"]
	_info.text = "%s  %s %d/%d%s\n%s" % [Loc.t("lagoon.b_" + t2), Loc.t("port.tier"), int(bld["lv"]), LagoonData.levels(t2), ("  " + Loc.t("lagoon.raided")) if bool(bld["dmg"]) else "", _stats_text(t2, int(bld["lv"]))]
	var up: int = Lagoon.upgrade_cost(s, cursor)
	if up > 0:
		_action(Loc.t("lagoon.upgrade_cost") % up, upgrade_selected, up <= int(s["gold"]) and not bool(bld["dmg"]))
	var rep: int = Lagoon.repair_cost(s, cursor)
	if rep > 0:
		_action(Loc.t("lagoon.repair_cost") % rep, repair_selected, rep <= int(s["gold"]))
	_action(Loc.t("lagoon.rotate"), rotate_selected, true)
	_action(Loc.t("lagoon.demolish"), demolish_selected, true)


func _stats_text(t: String, lv: int) -> String:
	var parts: Array[String] = []
	for key in ["beds", "income", "morale", "defence", "storage", "food", "heal", "repair"]:
		var v: float = LagoonData.stat(t, lv, key)
		if v > 0.0:
			parts.append(Loc.t("lagoon.stat_" + key) % int(v))
	return ", ".join(parts)


func _action(text: String, cb: Callable, enabled: bool) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.pressed.connect(cb)
	_actions.add_child(b)


# ---- actions (also called by tests) ------------------------------------------------------------

func pick(type: String) -> void:
	selected_type = "" if selected_type == type else type
	Sfx.play("ui_click")
	_update_cursor()
	_update_panel()


func move_cursor(c: Vector2i) -> void:
	var e: int = int(LagoonData.RANKS[LagoonData.RANKS.size() - 1]["extent"])
	cursor = Vector2i(clampi(c.x, -e, e), clampi(c.y, -e, e))
	_update_cursor()
	_update_panel()


## Build the chosen building on the cursor's plot, or select the building that is there.
func confirm() -> bool:
	if selected_type == "":
		_update_panel()
		return false
	if not Lagoon.place(state(), selected_type, cursor, rot):
		return false
	Sfx.play("coin")
	_bump()
	if LagoonData.cost(selected_type, 1) > int(state()["gold"]):
		selected_type = ""
	refresh()
	return true


func upgrade_selected() -> void:
	if Lagoon.upgrade(state(), cursor):
		Sfx.play("level_up")
		_bump()
	refresh()


func repair_selected() -> void:
	if Lagoon.repair(state(), cursor):
		Sfx.play("coin")
	refresh()


func rotate_selected() -> void:
	Lagoon.rotate(state(), cursor)
	refresh()


func demolish_selected() -> void:
	if Lagoon.demolish(state(), cursor) > 0:
		Sfx.play("chest")
	refresh()


## The new building or level pops up from the ground once it has been built.
func _bump() -> void:
	if lagoon == null:
		return
	lagoon.sync()
	lagoon.flush()
	var n: Node3D = lagoon.node_for("b%d,%d" % [cursor.x, cursor.y])
	if n != null:
		n.scale = Vector3(1.0, 0.05, 1.0)
		var tw: Tween = n.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "scale", Vector3.ONE, 0.45)


func finish() -> void:
	finished.emit()
	queue_free()


# ---- input -----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var c: Variant = _cell_under_mouse((event as InputEventMouseMotion).position)
		if c != null and c != cursor:
			move_cursor(c)
		return
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				var c2: Variant = _cell_under_mouse(mb.position)
				if c2 != null:
					move_cursor(c2)
					confirm()
			MOUSE_BUTTON_RIGHT:
				selected_type = ""
				_update_cursor()
				_update_panel()
			MOUSE_BUTTON_WHEEL_UP:
				zoom = clampf(zoom - 0.08, 0.45, 1.6)
				_place_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom = clampf(zoom + 0.08, 0.45, 1.6)
				_place_camera()
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey and event.pressed):
		return
	var k: InputEventKey = event
	var handled: bool = true
	match k.keycode:
		KEY_LEFT, KEY_A: move_cursor(cursor + Vector2i(-1, 0))
		KEY_RIGHT, KEY_D: move_cursor(cursor + Vector2i(1, 0))
		KEY_UP, KEY_W: move_cursor(cursor + Vector2i(0, 1))
		KEY_DOWN, KEY_S: move_cursor(cursor + Vector2i(0, -1))
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: confirm()
		KEY_R:
			if selected_type != "":
				rot = (rot + 1) % 4
				_update_cursor()
			else:
				rotate_selected()
		KEY_U: upgrade_selected()
		KEY_X, KEY_DELETE: demolish_selected()
		KEY_ESCAPE:
			if selected_type != "":
				pick(selected_type)
			else:
				finish()
		_: handled = false
	if handled:
		get_viewport().set_input_as_handled()


## The plot under a screen point: the ray from the camera meets the levelled ground.
func _cell_under_mouse(at: Vector2) -> Variant:
	if lagoon == null:
		return null
	var from: Vector3 = _cam.project_ray_origin(at)
	var dir: Vector3 = _cam.project_ray_normal(at)
	var plane_y: float = lagoon.to_global(Vector3(0, LagoonData.PAD_H_M, 0)).y
	if absf(dir.y) < 0.001:
		return null
	var t: float = (plane_y - from.y) / dir.y
	if t < 0.0:
		return null
	var hit: Vector3 = lagoon.to_local(from + dir * t)
	var c: Vector2i = LagoonData.cell_at(Vector2(hit.x, hit.z))
	var e: int = int(LagoonData.RANKS[LagoonData.RANKS.size() - 1]["extent"])
	if absi(c.x) > e or absi(c.y) > e:
		return null
	return c
