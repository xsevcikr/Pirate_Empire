class_name Difficulty
extends RefCounted
## Difficulty presets (spec section 6). AI never cheats on speed or reload; these only shape accuracy and pressure.

enum Level { EASY, NORMAL, HARD, LEGENDARY }

const TABLE: Dictionary = {
	Level.EASY: {"aim_error": 1.6, "reaction_s": 1.2, "damage_taken": 0.7, "ammo_switching": false, "max_attackers": 2, "hunter_freq": 0.5, "loot": 1.1},
	Level.NORMAL: {"aim_error": 1.0, "reaction_s": 0.7, "damage_taken": 1.0, "ammo_switching": true, "max_attackers": 3, "hunter_freq": 1.0, "loot": 1.0},
	Level.HARD: {"aim_error": 0.75, "reaction_s": 0.4, "damage_taken": 1.2, "ammo_switching": true, "max_attackers": 4, "hunter_freq": 1.5, "loot": 1.15},
	Level.LEGENDARY: {"aim_error": 0.55, "reaction_s": 0.25, "damage_taken": 1.4, "ammo_switching": true, "max_attackers": 5, "hunter_freq": 2.0, "loot": 1.3},
}

static var current: Level = Level.NORMAL


static func value(key: String, level: Level = current) -> Variant:
	return TABLE[level][key]
