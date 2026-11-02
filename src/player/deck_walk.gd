class_name DeckWalk
extends Node
## Autopilot and a stroll on deck. Enter (or the Autopilot button) hands the wheel to the autopilot, which holds the
## course and steers round islands, and puts the captain on his own deck: WASD walks him about while the ship sails
## on, the camera follows him close, and at the rail E casts a fishing line (DeckFishing) for food. Enter again, or
## E at the wheel, takes the helm back. An enemy closing in or a hit on the hull sends him straight back to the wheel.

signal walking_changed(on: bool)

const WALK_SPEED_MS: float = 3.4
const HELM_REACH_M: float = 1.8
const RAIL_REACH_M: float = 1.1
const DANGER_M: float = 450.0
const LINE_OUT_M: float = 4.5  ## how far from the side the float lands

var ship: Ship
var rig: CameraRig
var controller: PlayerController
var sea_life: SeaLife
var islands: Array = []  ## {pos: Vector2, radius: float}
var state: Dictionary = {}  ## a save state for tests; in the game the fish go into the Session's stores
var autopilot := Autopilot.new()
var fishing := DeckFishing.new()
var walking: bool = false
var captain_pos: Vector2 = Vector2.ZERO  ## ship-local: x across (starboard +), y along (stern +)
var last_catch: String = ""

var _holder: Node3D
var _captain: FighterState
var _view: DeckFighterView
var _focus: Node3D
var _helm_mark: MeshInstance3D
var _rod: MeshInstance3D
var _line: MeshInstance3D
var _line_mesh: ImmediateMesh
var _bobber: MeshInstance3D
var _bite_mark: Label3D
var _fish_on_deck: MeshInstance3D
var _fish_side: float = 1.0
var _fish_z: float = 0.0
var _show_t: float = 0.0  ## > 0 keeps the catch on show (the screenshot tool holds it)
var _step_sound: float = 0.0
var _danger_check: float = 0.0
var _ui: CanvasLayer
var _button: Button
var _prompt: Label


func _ready() -> void:
	name = "DeckWalk"
	_build_ui()
	if ship != null:
		ship.hit_taken.connect(func(_r: Dictionary) -> void:
			if walking:
				take_helm("walk.hit"))


# ---- helm and autopilot -----------------------------------------------------------------------------

func toggle() -> void:
	if walking:
		take_helm("")
	else:
		leave_helm()


## Hand the wheel to the autopilot and step onto the deck at the helm.
func leave_helm() -> bool:
	if walking or ship == null or ship.damage.sunk:
		return false
	var why: String = _danger()
	if why != "":
		_toast(Loc.t(why))
		return false
	autopilot.engage(ship.heading())
	walking = true
	if controller != null:
		controller.hands_off = true
	_spawn_captain()
	captain_pos = helm_spot()
	_captain.pos = captain_pos
	_captain.dir = Vector2(0, -1)
	if rig != null:
		rig.focus = _focus
	Sfx.play("ui_confirm")
	_toast(Loc.t("walk.on"))
	walking_changed.emit(true)
	_refresh_ui()
	return true


## Back to the wheel; `reason` is a string key for a toast ("" for none).
func take_helm(reason: String) -> void:
	if not walking:
		return
	walking = false
	autopilot.disengage()
	fishing.stop()
	if controller != null:
		controller.hands_off = false
	if ship != null:
		ship.rudder_input = 0.0
	if rig != null:
		rig.focus = null
	if _holder != null:
		_holder.queue_free()
		_holder = null
	_hide_line()
	if reason != "":
		_toast(Loc.t(reason))
	walking_changed.emit(false)
	_refresh_ui()


## Why the captain should not leave the wheel right now ("" when he may).
func _danger() -> String:
	if ship.grounding.stuck:
		return "walk.aground"
	if not is_inside_tree():
		return ""
	for n in get_tree().get_nodes_in_group("ships"):
		var s: Ship = n as Ship
		if s == null or s == ship or s.damage == null or s.damage.sunk or s.ai == null:
			continue
		if s.ai.target == ship and s.global_position.distance_to(ship.global_position) < DANGER_M:
			return "walk.enemy"
	return ""


# ---- the deck ---------------------------------------------------------------------------------------

func _deck_y() -> float:
	return ship.visuals.deck_y() if ship.visuals != null else ship.stats.freeboard_m


func _half_width() -> float:
	return ship.visuals.hull_half_width() if ship.visuals != null else ship.stats.beam_m * 0.42


## Half the deck's width at `z` along it (it narrows to the bow and the stern).
func deck_half_width(z: float) -> float:
	var u: float = clampf(absf(z) / (ship.stats.length_m * 0.5), 0.0, 1.0)
	return maxf(_half_width() * sqrt(maxf(1.0 - u * u, 0.0)) - 0.4, 0.35)


func deck_half_length() -> float:
	return ship.stats.length_m * 0.4


func helm_spot() -> Vector2:
	return Vector2(0.0, ship.stats.length_m * 0.33)


## Keep a ship-local point on the planking.
func clamp_to_deck(p: Vector2) -> Vector2:
	var z: float = clampf(p.y, -deck_half_length(), deck_half_length())
	var hw: float = deck_half_width(z)
	return Vector2(clampf(p.x, -hw, hw), z)


func at_rail() -> bool:
	return absf(captain_pos.x) >= deck_half_width(captain_pos.y) - RAIL_REACH_M


func at_helm() -> bool:
	return captain_pos.distance_to(helm_spot()) < HELM_REACH_M


## Walk him: `move` is the stick (x right, y back) seen from the camera; turned into the ship's own frame.
func walk(move: Vector2, delta: float) -> void:
	if move.length() < 0.1:
		_captain.move_intent = Vector2.ZERO
		return
	var d: Vector2 = move.normalized()
	var local: Vector2 = d
	if rig != null and rig.camera != null and rig.camera.is_inside_tree():
		var cb: Basis = rig.camera.global_transform.basis
		var world_dir: Vector3 = cb.x * d.x + cb.z * d.y
		world_dir.y = 0.0
		var l3: Vector3 = ship.global_transform.basis.inverse() * world_dir
		local = Vector2(l3.x, l3.z)
		if local.length() > 0.001:
			local = local.normalized()
	captain_pos = clamp_to_deck(captain_pos + local * WALK_SPEED_MS * delta)
	_captain.dir = local
	_captain.move_intent = local
	if fishing.is_out():
		fishing.stop()  # walking away reels the line in
		_hide_line()


# ---- fishing ----------------------------------------------------------------------------------------

## E on deck: take the helm, cast, or pull in a bite.
func use() -> void:
	if not walking:
		return
	if fishing.phase == DeckFishing.Phase.BITE:
		if fishing.pull():
			_landed()
		return
	if fishing.is_out():
		_toast(Loc.t("walk.wait_bite"))
		return
	if at_helm():
		take_helm("walk.helm")
	elif at_rail():
		cast()


func cast() -> void:
	_fish_side = signf(captain_pos.x) if absf(captain_pos.x) > 0.01 else 1.0
	_fish_z = captain_pos.y
	_captain.dir = Vector2(_fish_side, 0.0)
	fishing.cast()
	_line.visible = true
	_bobber.visible = true
	Sfx.play("splash", _bobber_world())


func _landed() -> void:
	last_catch = fishing.fish
	var food: int = DeckFishing.food_for(fishing.fish)
	var st: Dictionary = state if not state.is_empty() else _session_state()
	if not st.is_empty():
		food = DeckFishing.land(st, fishing.fish)
	_toast(Loc.t("walk.caught") % [Loc.t("fish." + fishing.fish), food])
	Sfx.play("ui_confirm")
	Sfx.play("splash", _bobber_world())
	if sea_life != null:
		sea_life.on_fish_caught(_holder.to_global(Vector3(captain_pos.x - _fish_side * 0.8, 0.3, captain_pos.y)))


func _bobber_world() -> Vector3:
	var local := Vector3(_fish_side * (deck_half_width(_fish_z) + 0.4 + LINE_OUT_M), 0.0, _fish_z)
	var p: Vector3 = ship.to_global(local)
	p.y = ship.ocean.height_at(p.x, p.z) if ship.ocean != null else 0.0
	return p


# ---- per frame --------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if ship == null:
		return
	if event.is_action_pressed("autopilot"):
		toggle()
		get_viewport().set_input_as_handled()
	elif walking and event.is_action_pressed("deck_use"):
		use()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not walking or ship == null:
		return
	if ship.damage.sunk:
		take_helm("")
		return
	var pos := Vector2(ship.global_position.x, ship.global_position.z)
	ship.rudder_input = autopilot.rudder(pos, ship.heading(), islands)
	_danger_check -= delta
	if _danger_check <= 0.0:
		_danger_check = 0.5
		var why: String = _danger()
		if why != "":
			take_helm(why)
			return
	var move := Vector2(Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left"),
		Input.get_action_strength("sail_down") - Input.get_action_strength("sail_up"))
	walk(move, delta)
	_step_sound -= delta
	if move.length() > 0.1 and _step_sound <= 0.0:
		_step_sound = 0.35
		Sfx.play("step_wood")
	if fishing.tick(delta):
		match fishing.phase:
			DeckFishing.Phase.BITE:
				Sfx.play("splash", _bobber_world())
			DeckFishing.Phase.MISSED:
				_toast(Loc.t("walk.got_away"))


func _process(_delta: float) -> void:
	if not walking or _holder == null:
		_refresh_prompt()
		return
	_holder.position = Vector3(0, _deck_y(), 0)
	_captain.pos = captain_pos
	_captain.aiming = fishing.is_out()
	_focus.position = Vector3(captain_pos.x, 0.0, captain_pos.y)
	var hs: Vector2 = helm_spot()
	_helm_mark.position = Vector3(hs.x, 0.04, hs.y)
	_helm_mark.visible = not at_helm()
	# the rod in his hands, the line out to the float
	_rod.visible = fishing.is_out()
	if fishing.is_out():
		_rod.position = Vector3(captain_pos.x + _fish_side * 0.35, 1.25, captain_pos.y)
		_rod.rotation = Vector3(0, 0, -_fish_side * 0.9)
		var tip: Vector3 = _holder.to_global(_rod.position + Vector3(_fish_side * 1.0, 0.75, 0))
		var bob: Vector3 = _bobber_world()
		var t: float = float(Time.get_ticks_msec()) * 0.001
		var hauled: bool = fishing.phase == DeckFishing.Phase.CAUGHT or _show_t > 0.0
		match fishing.phase:
			DeckFishing.Phase.BITE:
				bob.y -= 0.12 + absf(sin(t * 14.0)) * 0.25
			_:
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
				Basis(Vector3.UP, ship.rotation.y + PI * 0.5 + wriggle) * Basis(Vector3.RIGHT, PI * 0.5) * Basis().scaled(Vector3.ONE * size),
				bob - Vector3(0, 0.25 * size, 0))
	else:
		_fish_on_deck.visible = false
	_refresh_prompt()


# ---- building -----------------------------------------------------------------------------------------

func _spawn_captain() -> void:
	_holder = Node3D.new()
	_holder.name = "DeckWalkCaptain"
	_holder.position = Vector3(0, _deck_y(), 0)
	ship.add_child(_holder)
	_captain = FighterState.new()
	_captain.id = 1
	_captain.kind = "captain_player"
	_captain.is_player = true
	_captain.melee = "none"
	_view = DeckFighterView.new()
	_view.fighter = _captain
	_view.show_label = false
	_view.pose_idle_only = true
	_view.set_meta("kind", "deck_walk_captain")
	_holder.add_child(_view)
	_focus = Node3D.new()
	_holder.add_child(_focus)
	_helm_mark = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.55
	ring.outer_radius = 0.7
	_helm_mark.mesh = ring
	_helm_mark.material_override = Kenney.flat(Color(1.0, 0.82, 0.3), 0.8)
	_helm_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_holder.add_child(_helm_mark)
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
	_holder.add_child(_rod)
	_fish_on_deck = MeshInstance3D.new()
	_fish_on_deck.mesh = SeaLifeArt.catch_fish()
	_fish_on_deck.visible = false
	_fish_on_deck.top_level = true
	_holder.add_child(_fish_on_deck)
	if _line == null:
		_line_mesh = ImmediateMesh.new()
		_line = MeshInstance3D.new()
		_line.mesh = _line_mesh
		var lm := StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.albedo_color = Color(0.95, 0.95, 0.9)
		_line.material_override = lm
		_line.top_level = true
		_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ship.get_parent().add_child(_line)
		_bobber = MeshInstance3D.new()
		_bobber.mesh = SeaLifeArt.bobber()
		_bobber.rotation.x = PI * 0.5
		_bobber.top_level = true
		ship.get_parent().add_child(_bobber)
		_bite_mark = Label3D.new()
		_bite_mark.text = "!"
		_bite_mark.font_size = 160
		_bite_mark.outline_size = 36
		_bite_mark.modulate = Color(1.0, 0.85, 0.2)
		_bite_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bite_mark.no_depth_test = true
		_bite_mark.top_level = true
		ship.get_parent().add_child(_bite_mark)
	_hide_line()


func _hide_line() -> void:
	if _line == null:
		return
	_line.visible = false
	_bobber.visible = false
	_bite_mark.visible = false


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 6
	add_child(_ui)
	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.anchor_top = 0.5
	_button.anchor_bottom = 0.5
	_button.offset_left = 24.0
	_button.offset_right = 250.0
	_button.offset_top = -10.0
	_button.offset_bottom = 38.0
	_button.add_theme_font_size_override("font_size", 18)
	_button.set_meta("kind", "autopilot_button")
	_button.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		toggle())
	_ui.add_child(_button)
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
	_refresh_ui()


func _refresh_ui() -> void:
	if _button == null:
		return
	_button.text = Loc.t("walk.button_helm") if walking else Loc.t("walk.button_auto")
	_refresh_prompt()


## The line of help over the order bar: what E does where he stands.
func _refresh_prompt() -> void:
	if _prompt == null:
		return
	if not walking:
		_prompt.text = ""
		return
	var text: String = Loc.t("walk.prompt_walk")
	_prompt.add_theme_color_override("font_color", Color(1, 1, 1))
	match fishing.phase:
		DeckFishing.Phase.WAITING:
			text = Loc.t("walk.wait_bite")
		DeckFishing.Phase.BITE:
			text = Loc.t("walk.bite")
			_prompt.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		DeckFishing.Phase.CAUGHT, DeckFishing.Phase.MISSED:
			text = ""
		_:
			if at_helm():
				text = Loc.t("walk.prompt_helm")
			elif at_rail():
				text = Loc.t("walk.prompt_fish")
	_prompt.text = text


func _session_state() -> Dictionary:
	return Session.state if Session.has_state() else {}


func _toast(text: String) -> void:
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.toast.emit(text)
