class_name HitInfo
extends RefCounted
## One cannonball impact on a ship, in the ship's local space.

var local_position: Vector3 = Vector3.ZERO
var local_normal: Vector3 = Vector3.UP
var direction: Vector3 = Vector3.FORWARD  # unit travel direction, local space
var damage: float = 0.0  # gun damage after range falloff
var gun_id: String = "6pdr"
var ammo_id: String = "round"
var below_waterline: bool = false
var source: Node = null
