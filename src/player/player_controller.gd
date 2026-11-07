class_name PlayerController
extends Node
## Turns keyboard input into rudder and sail commands for one ship.

var ship: Ship
## The crew's standing order from the order buttons (CrewOrders); Tab picks a focus by hand and clears it.
var order: CrewOrders.Order = CrewOrders.Order.NONE


func give_order(o: CrewOrders.Order) -> void:
	if ship == null:
		return
	order = CrewOrders.give(ship, o, order)


func _unhandled_input(event: InputEvent) -> void:
	if ship == null:
		return
	if event.is_action_pressed("sail_up"):
		ship.sail_level = mini(ship.sail_level + 1, 3)
	elif event.is_action_pressed("sail_down"):
		ship.sail_level = maxi(ship.sail_level - 1, 0)
	elif event.is_action_pressed("crew_focus"):
		ship.crew.focus = ((ship.crew.focus + 1) % 4) as CrewState.Focus
		order = CrewOrders.Order.NONE
	for i in GunData.AMMO_ORDER.size():
		if event.is_action_pressed("ammo_%d" % (i + 1)):
			ship.broadside.set_ammo(GunData.AMMO_ORDER[i])


func _physics_process(delta: float) -> void:
	if ship == null:
		return
	ship.rudder_input = Input.get_axis("steer_left", "steer_right")
	var elev_in: float = Input.get_axis("elev_down", "elev_up")
	ship.broadside.set_elevation(ship.broadside.elevation_deg + elev_in * 8.0 * delta)
	var assist: bool = AimAssist.enabled(Session.state) and is_inside_tree()
	var ships: Array = get_tree().get_nodes_in_group("ships") if assist else []
	if assist and is_zero_approx(elev_in):  # Easy: the guns follow the nearest enemy so the aim marker is on him
		var side: int = AimAssist.best_side(ship, ships)
		if side >= 0:
			AimAssist.lay_guns(ship, side, ships)
	if Input.is_action_pressed("fire_port"):
		if assist:
			AimAssist.lay_guns(ship, Broadside.Side.PORT, ships)
		ship.broadside.fire(Broadside.Side.PORT)
	if Input.is_action_pressed("fire_starboard"):
		if assist:
			AimAssist.lay_guns(ship, Broadside.Side.STARBOARD, ships)
		ship.broadside.fire(Broadside.Side.STARBOARD)
	if order == CrewOrders.Order.ATTACK and is_inside_tree():
		CrewOrders.fight_at_will(ship, get_tree().get_nodes_in_group("ships"))
