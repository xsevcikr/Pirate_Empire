class_name MathUtils
extends RefCounted

const KNOT_TO_MS: float = 0.514


static func knots_to_ms(knots: float) -> float:
	return knots * KNOT_TO_MS


static func ms_to_knots(ms: float) -> float:
	return ms / KNOT_TO_MS
