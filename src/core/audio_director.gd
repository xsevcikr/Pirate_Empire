class_name AudioDirector
extends RefCounted
## Chooses the music layer from the situation so a mixer can crossfade to it.

enum Music { EXPLORE, TENSION, COMBAT, BOARDING, BOSS, PORT, STORM }


static func pick(ctx: Dictionary) -> Music:
	if ctx.get("boss", false):
		return Music.BOSS
	if ctx.get("boarding", false):
		return Music.BOARDING
	if ctx.get("in_port", false):
		return Music.PORT
	if ctx.get("enemy_in_combat", false):
		return Music.COMBAT
	if ctx.get("weather", "clear") == "storm":
		return Music.STORM
	if ctx.get("hostile_dist", 99999.0) < 1500.0:
		return Music.TENSION
	return Music.EXPLORE
