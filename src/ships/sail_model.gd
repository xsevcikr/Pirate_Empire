class_name SailModel
extends RefCounted
## Point-of-sail speed multiplier curves (see spec section 3).

## [angle off wind in degrees, speed multiplier]
const FORE_AND_AFT: Array = [
	[0.0, 0.0], [28.0, 0.0], [34.0, 0.3], [45.0, 0.45], [60.0, 0.75],
	[90.0, 1.0], [110.0, 1.0], [130.0, 0.95], [150.0, 0.9], [180.0, 0.8],
]
const SQUARE: Array = [
	[0.0, 0.0], [38.0, 0.0], [44.0, 0.3], [60.0, 0.5], [80.0, 0.8],
	[100.0, 1.0], [130.0, 1.05], [150.0, 0.95], [180.0, 0.85],
]
const LEVELS: PackedFloat32Array = [0.0, 0.5, 0.75, 1.0]
const LEVEL_NAMES: PackedStringArray = ["Furled", "Battle", "Half", "Full"]


static func speed_factor(angle_deg: float, square_rig: bool) -> float:
	var table: Array = SQUARE if square_rig else FORE_AND_AFT
	var a: float = clampf(absf(angle_deg), 0.0, 180.0)
	for i in range(table.size() - 1):
		var p0: Array = table[i]
		var p1: Array = table[i + 1]
		if a <= p1[0]:
			var t: float = smoothstep(0.0, 1.0, inverse_lerp(p0[0], p1[0], a))
			return lerpf(p0[1], p1[1], t)
	return table[table.size() - 1][1]


static func point_of_sail(angle_deg: float, square_rig: bool) -> String:
	var no_go: float = 38.0 if square_rig else 28.0
	if angle_deg < no_go:
		return "In irons"
	if angle_deg < 50.0:
		return "Close-hauled"
	if angle_deg < 70.0:
		return "Close reach"
	if angle_deg < 110.0:
		return "Beam reach"
	if angle_deg < 150.0:
		return "Broad reach"
	return "Running"
