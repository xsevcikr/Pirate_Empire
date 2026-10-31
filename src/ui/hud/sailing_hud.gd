class_name SailingHud
extends CanvasLayer
## Minimal sailing HUD: speed, sail level, point of sail, wind and clock.

var ship: Ship
var wind: WindModel
var clock: Node

var target: Ship
var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(32, 28)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)
	var help := Label.new()
	help.text = "A/D steer   W/S sails   RMB drag look   Q/E fire port/starboard   R/F elevation   1-5 ammo   Tab crew focus   F1-F5 crew orders   F6 rum   Z damage control   H sing a shanty   Space dock   G hold to board   Esc pause"
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.position = Vector2(32, -48)
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	help.add_theme_constant_override("outline_size", 5)
	add_child(help)


func _process(_delta: float) -> void:
	if ship == null or wind == null:
		return
	var heading_deg: float = fposmod(rad_to_deg(atan2(ship.heading().x, -ship.heading().y)), 360.0)
	var angle: float = ship.angle_off_wind
	var hour: float = clock.hour if clock else 12.0
	var b: Broadside = ship.broadside
	var d: DamageModel = ship.damage
	var combat: String = "\nGuns P %d/%d  S %d/%d   Ammo %s x%d   Elevation %.1f deg\nHull %d%%   Flooding %d%%   Fires %d   Crew %d (%s)" % [
		b.ready_count(0), b.gun_count(), b.ready_count(1), b.gun_count(), b.ammo_id, int(b.ammo[b.ammo_id]), b.elevation_deg,
		int(d.hull_fraction() * 100.0), int(d.flood_fraction() * 100.0), d.fires_burning(), ship.crew.count,
		CrewState.Focus.keys()[ship.crew.focus].capitalize()]
	if target and is_instance_valid(target):  # the enemy's hull is not shown: only what the eye can see, his masts
		combat += "\nTarget %s: masts %d/%d%s" % [target.stats.display_name,
			target.damage.mast_down.count(false), target.stats.mast_count, "  SUNK" if target.damage.sunk else ""]
	if not Session.state.is_empty():
		combat += "\n" + Loc.t("hud.captain_hp") % [ceili(CaptainHealth.hp(Session.state)), roundi(DeckData.FIGHTER_HP), floori(CaptainHealth.rum_supply(Session.state) / DeckData.RUM_SUPPLY_PER_DRINK + 0.0001)]
	_label.text = "%s   %.1f kn   heading %03d\nSails: %s   %s (%d deg off wind)\nWind %.0f kn   sea state %.1f   %02d:%02d\nHeel %.0f deg" % [
		ship.stats.display_name, ship.speed_knots(), int(heading_deg),
		SailModel.LEVEL_NAMES[ship.sail_level], SailModel.point_of_sail(angle, ship.stats.square_rig), int(angle),
		wind.speed_kn, wind.sea_state(), int(hour), int(fposmod(hour, 1.0) * 60.0),
		ship.heel_deg(),
	] + combat
