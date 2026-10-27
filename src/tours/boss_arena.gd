class_name BossArena
extends RefCounted
## Where each boss is fought: the island it guards, how wide the arena is and what fills it. Leaving the arena
## lets the boss heal 20% a minute (Boss.in_arena); the arena itself only answers where the player is.

const ARENAS: Dictionary = {
	"shell_king": {"island": "Skull Atoll", "radius": 140.0, "kind": "beach", "on_foot": true},
	"sea_serpent": {"island": "Moana Reef", "radius": 900.0, "kind": "reef", "on_foot": false},
	"valcourt": {"island": "Admiralty Rock", "radius": 1200.0, "kind": "line_of_battle", "on_foot": false},
	"ghost_admiral": {"island": "Wraith Isle", "radius": 1100.0, "kind": "fog", "on_foot": false},
	"brass_colossus": {"island": "Cinder Bay", "radius": 150.0, "kind": "lava_works", "on_foot": true},
	"ice_leviathan": {"island": "Frostmourn", "radius": 1300.0, "kind": "ice_field", "on_foot": false},
	"kraken": {"island": "Kraken's Maw", "radius": TourHazards.WHIRL_RADIUS_M, "kind": "whirlpool", "on_foot": false},
	"black_ibrahim": {"island": "Brimstone Isle", "radius": 1500.0, "kind": "fleet_anchorage", "on_foot": false},
}


static func ids() -> Array:
	return ARENAS.keys()


static func centre(boss_id: String) -> Vector2:
	var g: WorldGen = PortData.gen()
	var i: int = g.index_of(ARENAS[boss_id]["island"])
	return g.islands[i]["pos"] as Vector2 if i >= 0 else Vector2.ZERO


static func contains(boss_id: String, p: Vector2) -> bool:
	return p.distance_to(centre(boss_id)) <= float(ARENAS[boss_id]["radius"])


## Advance a boss one tick for a player at p. Returns the attack that landed, if any.
static func tick(boss_id: String, boss: Boss, p: Vector2, delta: float) -> String:
	boss.in_arena = contains(boss_id, p)
	return boss.tick(delta)
