class_name SailModel
extends RefCounted
## Sail settings. There are no wind mechanics: a ship makes the same speed on every heading, and the sail level
## alone (furled, battle, half, full) sets how fast she goes.

const LEVELS: PackedFloat32Array = [0.0, 0.5, 0.75, 1.0]
const LEVEL_NAMES: PackedStringArray = ["Furled", "Battle", "Half", "Full"]
