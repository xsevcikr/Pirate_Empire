extends SceneTree
## Renders the reworked deck combat to PNGs:
##   xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_combat.gd -- <mode> out.png
## modes: aim (captain aiming his pistol, a marine levelling his musket), orders (gun crew loading, repair party),
## fists (bare-knuckle with the crew panel), rum (the captain drinking)

var _scene: DeckFightScene
var _frames: int = 0
var _mode: String = "aim"
var _out: String = "user://combat.png"
var _at: int = 150


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = args[0]
	if args.size() > 1:
		_out = args[1]
	_at = {"orders": 420, "fists": 330}.get(_mode, 150)
	GameInput.register()
	var s: Dictionary = SaveGame.new_state()
	var names: Array[String] = ["Bones", "Mags", "Finn", "Patch", "Old Tom", "Red Ned", "Sully", "Kit", "Dutch", "Wren", "Hob", "Jory"]
	for i in 12:
		s["roster"].append({"name": names[i], "type": ["carpenter", "seasoned", "swordsman", "gunner"][i % 4], "level": 1, "xp": 0})
	if _mode == "fists":
		s["melee"] = ""
	s["captain_hp"] = 140.0 if _mode != "rum" else 90.0
	var faction: String = "pirate" if _mode == "fists" else "navy"
	var c: DeckCombat = DeckBridge.build(13, 1.0, 70.0, faction, 14, 1.0, 70.0, s, 9)
	_scene = DeckFightScene.new()
	root.add_child(_scene)
	_scene.start(c)
	root.size = Vector2i(1600, 900)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		return false
	var c: DeckCombat = _scene.combat
	var p: FighterState = c.player
	match _mode:
		"aim":
			if _frames == 2:
				p.set_mode(FighterState.Mode.GUN)
				c.command = DeckData.Command.HOLD
			var foe: FighterState = c.nearest_enemy(p)
			var i: Dictionary = {"heavy_held": true}
			if foe != null:
				i["aim_point"] = foe.pos
			_scene.intent = i
			if _frames == _at - 30:
				for e in c.fighters:
					if e.team == 1 and e.ranged != "" and e.is_standing():
						e.aim_left = 0.0
						e.aim_skill_deg = 3.0
						e.begin_aim(p.pos - e.pos)
						break
		"orders":
			if _frames == 2:
				c.command = DeckData.Command.HOLD
				_scene.give_order(DeckHud.Order.LOAD_CANNON)
				_scene.give_order(DeckHud.Order.REPAIR)
			DeckBridge.autopilot(c, 1.0 / 60.0)
		"fists":
			if _frames == 40:
				p.raise_block(c.time_s)
			DeckBridge.autopilot(c, 1.0 / 60.0)
		"rum":
			_scene.intent = {"rum": _frames == _at - 20}
	if _frames == _at:
		var img: Image = root.get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out, " t=", c.time_s, " mine=", c.standing_on_screen(0), " theirs=", c.standing_on_screen(1), " hp=", p.hp)
		quit()
	return false
