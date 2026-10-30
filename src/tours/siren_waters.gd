class_name SirenWaters
extends RefCounted
## The waters round a siren rock pull the helm toward the rocks and sap morale. Wax in the ears or a shanty the
## crew sings loudly enough (morale 40 or better) stops both; each siren shot down weakens the pull.

var centre: Vector2
var radius: float
var sirens_alive: int = TourData.SIREN["choir_size"]


func _init(centre_pos: Vector2, radius_m: float) -> void:
	centre = centre_pos
	radius = radius_m


func inside(p: Vector2) -> bool:
	return p.distance_to(centre) <= radius


## Force on the ship in newtons, toward the rocks, strongest at the rim of the choir's reach.
func pull(p: Vector2, protected: bool) -> Vector2:
	if protected or sirens_alive <= 0 or not inside(p):
		return Vector2.ZERO
	var d: float = p.distance_to(centre)
	var share: float = float(sirens_alive) / float(TourData.SIREN["choir_size"])
	return (centre - p).normalized() * float(TourData.SIREN["pull_n"]) * share * clampf(1.0 - d / radius, 0.2, 1.0)


func morale_drain(p: Vector2, protected: bool, delta: float) -> float:
	if protected or sirens_alive <= 0 or not inside(p):
		return 0.0
	return float(TourData.SIREN["morale_per_s"]) * delta * float(sirens_alive) / float(TourData.SIREN["choir_size"])


static func shanty_works(morale: float) -> bool:
	return morale >= float(TourData.SIREN["shanty_min_morale"])


func shoot_siren() -> void:
	sirens_alive = maxi(sirens_alive - 1, 0)
