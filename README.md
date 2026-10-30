# Pirate Empire

A 3D pirate naval combat and empire game in Godot 4.4 (GDScript, Forward+).

## Run
Install Godot 4.4.x, open `project.godot`, press F5.

## Test
`tools/run_tests.sh` (needs `godot` on PATH): import, boot smoke test, unit tests.

## Roadmap
Built milestone by milestone (M0 skeleton, M1 ocean and sailing, M2 cannons, and so on).
The full design spec lives in `docs/SPEC.md`.

## Release tooling (M10)
- `tools/qa.sh` runs the full suite and fails on any ERROR line.
- `tools/soak.gd` runs a sailing and firing bot; pass `-- --minutes=240` for the 4-hour soak.
- `tools/export.sh` exports Windows, Linux and macOS (needs Godot export templates installed).

## Art

The game uses the CC0 Kenney kits in `assets/kenney/` (licences in each folder) with a shared toon shader (`shaders/toon.gdshader`) and look (`src/art/look.gd`). Everything the kits do not cover (sea, sky, bosses, effects) is built in code in the same flat-colour style.

## Crash damage and damage control (M23)

Ramming, sideswipes and groundings use the impact model in `src/physics/collision_model.gd`: energy from the
reduced mass and closing speed, scaled by where each hull was struck (stem 0.6, square on the side 1.3), plus a
scrape from the sliding speed. A blow worth 5%, 16% or 32% of the hull tears a small, big or gaping breach at the
contact point, which floods that section until it is fixed. `src/ships/damage_control.gd` sends the repair
hands (Tab to Repair focus for more) to the pumps, the holes, fires, rigging and the hull: holes are planked
with timber, fothered with canvas or stuffed with oakum; tools and carpenters speed the work, and a jury mast
takes timber and canvas. Press Z for the damage control panel to set the orders yourself.
