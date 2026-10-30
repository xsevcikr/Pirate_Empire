class_name FishingScreen
extends MenuScreen
## Fishing from the deck: wait for the bite, then hold Reel (or Space) while watching the line. Too tight and it
## snaps, too slack and the fish slips away.

var game: Fishing
var rng := RandomNumberGenerator.new()
var _status: Label
var _line: ProgressBar
var _dist: ProgressBar
var _reel: Button
var _done: bool = false


static func make(seed_v: int) -> FishingScreen:
	var s := FishingScreen.new()
	s.rng.seed = seed_v
	s.game = Fishing.new(s.rng)
	return s


func _init() -> void:
	super()
	_title_key = "games.fishing"
	dim = 0.6


func build() -> void:
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_status)
	_line = ProgressBar.new()
	_line.max_value = float(GameData.FISHING["tension_break"])
	_line.custom_minimum_size = Vector2(420, 24)
	_line.show_percentage = false
	_box.add_child(_line)
	_dist = ProgressBar.new()
	_dist.max_value = 1.6
	_dist.custom_minimum_size = Vector2(420, 24)
	_dist.show_percentage = false
	_box.add_child(_dist)
	_reel = Button.new()
	_reel.text = Loc.t("fish.reel")
	_reel.custom_minimum_size = Vector2(0, 54)
	_box.add_child(_reel)
	add_button("menu.back", close)


func _process(delta: float) -> void:
	if game == null or _status == null or _done:
		return
	game.step(delta, _reel.button_pressed or Input.is_action_pressed("interact") or _reel.is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	_line.value = game.tension
	_dist.value = game.distance
	match game.phase:
		Fishing.Phase.WAITING:
			_status.text = Loc.t("fish.waiting")
		Fishing.Phase.REELING, Fishing.Phase.BITE:
			_status.text = Loc.t("fish.bite")
		Fishing.Phase.CAUGHT:
			_done = true
			_finish()
		Fishing.Phase.LOST:
			_done = true
			MiniGames.settle_fishing(Session.state, game, false)
			_status.text = Loc.t("fish.lost")


func _finish() -> void:
	var res: Dictionary = MiniGames.settle_fishing(Session.state, game, false)
	_status.text = Loc.t("fish.caught") % [Loc.t("fish." + game.fish), int(res["gold"])] + (" " + Loc.t("fish.bottle") if bool(res["bottle"]) else "")
