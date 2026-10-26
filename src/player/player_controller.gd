class_name PlayerController
extends Node
## Turns keyboard input into rudder and sail commands for one ship.

var ship: Ship
var wind: WindModel


func _unhandled_input(event: InputEvent) -> void:
	if ship == null:
		return
	if event.is_action_pressed("sail_up"):
		ship.sail_level = mini(ship.sail_level + 1, 3)
	elif event.is_action_pressed("sail_down"):
		ship.sail_level = maxi(ship.sail_level - 1, 0)
	elif event.is_action_pressed("crew_focus"):
		ship.crew.focus = ((ship.crew.focus + 1) % 4) as CrewState.Focus
	for i in GunData.AMMO_ORDER.size():
		if event.is_action_pressed("ammo_%d" % (i + 1)):
			ship.broadside.set_ammo(GunData.AMMO_ORDER[i])


func _physics_process(delta: float) -> void:
	if ship == null:
		return
	ship.rudder_input = Input.get_axis("steer_left", "steer_right")
	ship.broadside.set_elevation(ship.broadside.elevation_deg + Input.get_axis("elev_down", "elev_up") * 8.0 * delta)
	if Input.is_action_pressed("fire_port"):
		ship.broadside.fire(Broadside.Side.PORT)
	if Input.is_action_pressed("fire_starboard"):
		ship.broadside.fire(Broadside.Side.STARBOARD)
	if wind:
		if Input.is_action_pressed("wind_cw"):
			wind.direction = wind.direction.rotated(deg_to_rad(20.0) * delta)
		if Input.is_action_pressed("wind_ccw"):
			wind.direction = wind.direction.rotated(deg_to_rad(-20.0) * delta)
		if Input.is_action_pressed("wind_stronger"):
			wind.speed_kn = minf(wind.speed_kn + 8.0 * delta, 50.0)
		if Input.is_action_pressed("wind_weaker"):
			wind.speed_kn = maxf(wind.speed_kn - 8.0 * delta, 0.0)
