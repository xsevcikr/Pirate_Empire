class_name RailFishing
extends Node3D
## Fishing from the ship's rail while auto drive sails her (AutoDrive puts the captain on deck as a DeckWalker).
## At the rail E casts a line (DeckFishing), E again on the bite lands the fish as food for the crew; walking away
## reels the line in. Lives as a child of the walker, so it goes when he goes back to the wheel.

const RAIL_REACH_M: float = 1.1  ## within this of the deck's edge he can reach over the rail
const LINE_OUT_M: float = 4.5  ## how far from the side the float lands

var walker: DeckWalker
var sea_life: SeaLife
var state: Dictionary = {}  ## a save state for tests; in the game the fish go into the Session's stores
var fishing := DeckFishing.new()
var last_catch: String = ""

var _rod: MeshInstance3D
var _line: MeshInstance3D
var _line_mesh: ImmediateMesh
var _bobber: MeshInstance3D
var _bite_mark: Label3D
var _fish_on_deck: MeshInstance3D
var _fish_side: float = 1.0
var _fish_z: float = 0.0
var _cast_from: Vector2 = Vector2.ZERO
var _show_t: float = 0.0  ## > 0 keeps the catch on show (the screenshot tool holds it)
var _ui: CanvasLayer
var _prompt: Label


func _ready() -> void:
	name = "RailFishing"
	_build()


func _exit_tree() -> void:
	for n: Node in [_line, _bobber, _bite_mark, _fish_on_deck, _ui]:  # the world-space pieces live outside the ship
		if n != null and is_instance_valid(n):
			n.queue_free()


func ship() -> Ship:
	return walker.ship if walker != null else null


func captain_pos() -> Vector2:
	return walker.fighter.pos if walker != null and walker.fighter != null else Vector2.ZERO


## The deck's edge on his side of the ship at his station (ship-local x), found by walking out from him.
func edge_x(p: Vector2, side: float) -> float:
	var x: float = p.x
	for i in 80:
		var nx: float = x + side * 0.1
		if walker.cell_height(Vector2(nx, p.y)) == INF:
			return x
		x = nx
	return x


func at_rail() -> bool:
	if walker == null or walker.fighter == null:
		return false
	var p: Vector2 = captain_pos()
	var side: float = signf(p.x) if absf(p.x) > 0.01 else 1.0
	return absf(edge_x(p, side) - p.x) <= RAIL_REACH_M


## E on deck: cast at the rail, or pull in a bite.
func use() -> bool:
	if fishing.phase == DeckFishing.Phase.BITE:
		if fishing.pull():
			_landed()
		return true
	if fishing.is_out():
		_toast(Loc.t("walk.wait_bite"))
		return true
	if at_rail():
		cast()
		return true
	return false


func cast() -> void:
	var p: Vector2 = captain_pos()
	_fish_side = signf(p.x) if absf(p.x) > 0.01 else 1.0
	_fish_z = p.y
	_cast_from = p
	walker.fighter.dir = Vector2(_fish_side, 0.0)
	fishing.cast()
	_line.visible = true
	_bobber.visible = true
	Sfx.play("splash", bobber_world())


func _landed() -> void:
	last_catch = fishing.fish
	var food: int = DeckFishing.food_for(fishing.fish)
	var st: Dictionary = state if not state.is_empty() else (Session.state if Session.has_state() else {})
	if not st.is_empty():
		food = DeckFishing.land(st, fishing.fish)
	_toast(Loc.t("walk.caught") % [Loc.t("fish." + fishing.fish), food])
	Sfx.play("ui_confirm")
	Sfx.play("splash", bobber_world())
	if sea_life != null and is_instance_valid(sea_life):
		var p: Vector2 = captain_pos()
		sea_life.on_fish_caught(ship().to_global(Vector3(p.x - _fish_side * 0.8, walker.height_at(p) + 0.3, p.y)))


func bobber_world() -> Vector3:
	var s: Ship = ship()
	var local := Vector3(_fish_side * (walker.half_beam + 0.4 + LINE_OUT_M), 0.0, _fish_z)
	var p: Vector3 = s.to_global(local)
	p.y = s.ocean.height_at(p.x, p.z) if s.ocean != null else 0.0
	return p


func _hide_line() -> void:
	if _line == null:
		return
	_line.visible = false
	_bobber.visible = false
	_bite_mark.visible = false


# ---- per frame --------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if walker == null or get_tree().paused:
		return
	if event.is_action_pressed("deck_use") and not event.is_echo():
		if use():
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if walker == null or walker.fighter == null:
		return
	if fishing.is_out() and captain_pos().distance_to(_cast_from) > 0.6:
		fishing.stop()  # walking away reels the line in
		_hide_line()
	_show_t = maxf(_show_t - delta, 0.0)
	if fishing.tick(delta):
		match fishing.phase:
			DeckFishing.Phase.BITE:
				Sfx.play("splash", bobber_world())
			DeckFishing.Phase.MISSED:
				_toast(Loc.t("walk.got_away"))


func _process(_delta: float) -> void:
	if walker == null or walker.fighter == null:
		return
	var p: Vector2 = captain_pos()
	walker.fighter.aiming = fishing.is_out()
	_rod.visible = fishing.is_out()
	if fishing.is_out():
		_rod.position = Vector3(p.x + _fish_side * 0.35, walker.height_at(p) + 1.25, p.y)
		_rod.rotation = Vector3(0, 0, -_fish_side * 0.9)
		var tip: Vector3 = walker.to_global(_rod.position + Vector3(_fish_side * 1.0, 0.75, 0))
		var bob: Vector3 = bobber_world()
		var t: float = float(Time.get_ticks_msec()) * 0.001
		var hauled: bool = fishing.phase == DeckFishing.Phase.CAUGHT or _show_t > 0.0
		if fishing.phase == DeckFishing.Phase.BITE:
			bob.y -= 0.12 + absf(sin(t * 14.0)) * 0.25
		else:
			bob.y += sin(t * 2.5) * 0.04
		if hauled:  # the catch hangs from the rod tip, wriggling, for everyone to see
			bob = tip + Vector3(0, -1.1, 0)
		_bobber.global_position = bob
		_bobber.visible = not hauled
		_bite_mark.visible = fishing.phase == DeckFishing.Phase.BITE
		_bite_mark.global_position = bob + Vector3(0, 1.6 + absf(sin(t * 6.0)) * 0.3, 0)
		_line_mesh.clear_surfaces()
		_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		_line_mesh.surface_add_vertex(tip)
		_line_mesh.surface_add_vertex(bob + Vector3(0, 0.12, 0))
		_line_mesh.surface_end()
		_fish_on_deck.visible = hauled
		if hauled:
			var size: float = {"sardine": 1.3, "bass": 1.8, "tuna": 2.6, "marlin": 3.4}.get(last_catch, 1.5)
			var wriggle: float = sin(t * 18.0) * 0.5
			_fish_on_deck.global_transform = Transform3D(
				Basis(Vector3.UP, ship().rotation.y + PI * 0.5 + wriggle) * Basis(Vector3.RIGHT, PI * 0.5) * Basis().scaled(Vector3.ONE * size),
				bob - Vector3(0, 0.25 * size, 0))
	else:
		_fish_on_deck.visible = false
	_refresh_prompt()


## Holds the last catch on show (for the screenshot tool).
func show_catch(seconds: float) -> void:
	_show_t = seconds


# ---- building -----------------------------------------------------------------------------------------

func _build() -> void:
	_rod = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.015
	cyl.bottom_radius = 0.035
	cyl.height = 2.2
	cyl.radial_segments = 5
	cyl.rings = 1
	_rod.mesh = cyl
	_rod.material_override = Kenney.flat(Color(0.55, 0.36, 0.2))
	_rod.visible = false
	add_child(_rod)
	var world_root: Node = ship().get_parent() if ship() != null and ship().get_parent() != null else self
	_fish_on_deck = MeshInstance3D.new()
	_fish_on_deck.mesh = SeaLifeArt.catch_fish()
	_fish_on_deck.visible = false
	_fish_on_deck.top_level = true
	world_root.add_child(_fish_on_deck)
	_line_mesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.95, 0.95, 0.9)
	_line.material_override = lm
	_line.top_level = true
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(_line)
	_bobber = MeshInstance3D.new()
	_bobber.mesh = SeaLifeArt.bobber()
	_bobber.rotation.x = PI * 0.5
	_bobber.top_level = true
	world_root.add_child(_bobber)
	_bite_mark = Label3D.new()
	_bite_mark.text = "!"
	_bite_mark.font_size = 160
	_bite_mark.outline_size = 36
	_bite_mark.modulate = Color(1.0, 0.85, 0.2)
	_bite_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bite_mark.no_depth_test = true
	_bite_mark.top_level = true
	world_root.add_child(_bite_mark)
	_hide_line()
	_ui = CanvasLayer.new()
	_ui.layer = 6
	world_root.add_child(_ui)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -500.0
	_prompt.offset_right = 500.0
	_prompt.offset_top = -300.0
	_prompt.offset_bottom = -262.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 26)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 7)
	_ui.add_child(_prompt)


## The line of help over the order bar: what E does where he stands.
func _refresh_prompt() -> void:
	if _prompt == null:
		return
	var text: String = ""
	_prompt.add_theme_color_override("font_color", Color(1, 1, 1))
	match fishing.phase:
		DeckFishing.Phase.WAITING:
			text = Loc.t("walk.wait_bite")
		DeckFishing.Phase.BITE:
			text = Loc.t("walk.bite")
			_prompt.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		DeckFishing.Phase.IDLE:
			if at_rail():
				text = Loc.t("walk.prompt_fish")
	_prompt.text = text


func _toast(text: String) -> void:
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.toast.emit(text)
