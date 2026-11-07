class_name AutoDrive
extends Node
## K hands the ship to auto drive and lets the captain walk the deck; K again (or the badge button) takes the helm
## back. Auto drive follows the course marked on the chart (M) and stops there, or holds the heading if no course is
## set, steering round islands and ships. It lets go of the wheel by itself when the ship is hit, runs aground or
## has no way out, so the captain is never left strolling while the ship is in trouble.

signal changed(on: bool)

const BLOCKED_GIVE_UP_S: float = 4.0
const SHIP_SCAN_M: float = 260.0
const SAIL_SEE_THROUGH: float = 0.6  ## on foot the camera is down among the sails, so they turn see-through

var controller: PlayerController
var rig: CameraRig
var overlay: GameOverlay
var pilot: Autopilot
var walker: DeckWalker
var badge: AutoDriveBadge
var _ship: Ship
var _blocked_s: float = 0.0


func _init() -> void:
	pilot = Autopilot.new(PortData.gen().islands)


func _ready() -> void:
	name = "AutoDrive"
	badge = AutoDriveBadge.new()
	badge.drive = self
	add_child(badge)


func is_on() -> bool:
	return pilot != null and pilot.is_on()


func ship() -> Ship:
	return controller.ship if controller != null else null


func toggle() -> void:
	if is_on():
		take_helm("autodrive.helm")
	else:
		engage()


func engage() -> bool:
	var s: Ship = ship()
	if s == null or s.damage.sunk or s.grounding.stuck:
		_toast("autodrive.cant")
		return false
	var course: Array = []
	if Session.has_state():
		course = Session.state.get("course", [])
	pilot.engage(_flat(s.global_position), s.heading(), course)
	if s.sail_level < 2:
		s.sail_level = 2
	_ship = s
	_blocked_s = 0.0
	if not s.hit_taken.is_connected(_on_hit):
		s.hit_taken.connect(_on_hit)
	controller.auto_drive = true
	walker = DeckWalker.new()
	walker.setup(s)
	s.add_child(walker)
	if rig != null:
		walker.camera = rig.camera
		rig.set_walker(walker.anchor)
	_see_through_sails(s, SAIL_SEE_THROUGH)
	Sfx.play("ui_confirm")
	_toast("autodrive.on_course" if pilot.mode == Autopilot.Mode.COURSE else "autodrive.on_hold")
	changed.emit(true)
	return true


## Ends auto drive; `why` is the string key of the toast that says why (empty for none).
func take_helm(why: String = "") -> void:
	if not is_on():
		return
	pilot.disengage()
	if controller != null:
		controller.auto_drive = false
	if _ship != null and is_instance_valid(_ship):
		_ship.rudder_input = 0.0
		_see_through_sails(_ship, 0.0)
		if _ship.hit_taken.is_connected(_on_hit):
			_ship.hit_taken.disconnect(_on_hit)
	if walker != null and is_instance_valid(walker):
		walker.queue_free()
	walker = null
	if rig != null:
		rig.set_walker(null)
	_ship = null
	if why != "":
		_toast(why)
	Sfx.play("ui_click")
	changed.emit(false)


func _on_hit(_result: Dictionary) -> void:
	take_helm("autodrive.under_fire")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("auto_drive") and not get_tree().paused:
		toggle()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not is_on():
		return
	var s: Ship = ship()
	if s == null or s != _ship or not is_instance_valid(s):  # a new ship was bought or the old one is gone
		take_helm()
		return
	if s.damage.sunk or s.grounding.stuck:
		take_helm("autodrive.aground")
		return
	var pos: Vector2 = _flat(s.global_position)
	var others: Array = []
	for n in get_tree().get_nodes_in_group("ships"):
		var o: Ship = n as Ship
		if o == null or o == s or o.damage.sunk:
			continue
		var p: Vector2 = _flat(o.global_position)
		if p.distance_to(pos) < SHIP_SCAN_M:
			others.append(p)
	var res: Dictionary = pilot.steer(pos, s.heading(), s.speed_forward_ms, others)
	s.rudder_input = float(res["rudder"])
	if int(res["sail"]) >= 0:
		s.sail_level = mini(s.sail_level, int(res["sail"]))
	if res["arrived"]:
		if Session.has_state():
			Session.state["course"] = []
		take_helm("autodrive.arrived")
		return
	_blocked_s = _blocked_s + delta if res["blocked"] else 0.0
	if _blocked_s > BLOCKED_GIVE_UP_S:
		take_helm("autodrive.blocked")


func _see_through_sails(s: Ship, amount: float) -> void:
	if s.visuals == null:
		return
	for m: ShaderMaterial in s.visuals.sail_materials:
		m.set_shader_parameter("see_through", amount)


func _toast(key: String) -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.add_toast(Loc.t(key))


static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)
