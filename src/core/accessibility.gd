class_name Accessibility
extends RefCounted
## Accessibility values with their allowed ranges.

var camera_shake: float = 1.0  ## 0 to 1
var motion_blur: float = 0.0  ## 0 to 1
var fov: float = 65.0  ## 50 to 100
var subtitles: bool = true
var colorblind_markers: bool = false


func set_camera_shake(v: float) -> void:
	camera_shake = clampf(v, 0.0, 1.0)


func set_fov(v: float) -> void:
	fov = clampf(v, 50.0, 100.0)


## Camera shake in degrees for a hit: amplitude by damage, at most 0.6 degrees, scaled by the slider.
func shake_degrees(damage: float) -> float:
	return clampf(damage / 500.0, 0.0, 0.6) * camera_shake
