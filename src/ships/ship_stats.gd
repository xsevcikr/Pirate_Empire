class_name ShipStats
extends Resource
## Static, data-driven ship tuning (values mirror the spec's class table).

@export var class_id: String = "sloop"
@export var display_name: String = "Sloop"
@export var mass_kg: float = 90000.0
@export var length_m: float = 18.0
@export var beam_m: float = 5.0
@export var draft_m: float = 1.4
@export var freeboard_m: float = 2.0
@export var max_speed_kn: float = 14.0
@export var turn_rate_deg_s: float = 15.0
@export var square_rig: bool = false
## Time constant of acceleration (s); ~1.8x this to reach 95% of max speed.
@export var accel_tau_s: float = 14.0
@export var mast_count: int = 1
@export var hull_hp: float = 1200.0
@export var sail_hp: float = 400.0
@export var rudder_hp: float = 400.0
@export var armor: float = 10.0
@export var guns_per_side: int = 4
@export var section_count: int = 4
@export var crew_min: int = 8
@export var crew_max: int = 30
@export var cargo_t: float = 40.0
@export var price: int = 2000
@export var upkeep_per_day: int = 20
@export var infamy_required: int = 0
