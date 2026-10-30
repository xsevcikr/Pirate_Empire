class_name TimingScreen
extends MenuScreen
## The timing games on one bar: arm wrestling, knife throwing and the drinking contest. A marker sweeps the bar;
## stop it near the middle. Arm wrestling then asks for button mashing.

var mode: String = "arm"
var rng := RandomNumberGenerator.new()
var _cursor: float = 0.0
var _t: float = 0.0
var _bar: ProgressBar
var _info: Label
var _phase: String = "bar"  ## bar, mash, done
var _accuracy: float = 0.0
var _mashes: int = 0
var _mash_left: float = 5.0
var _knife: KnifeThrow
var _drink: DrinkingContest
var _speed: float = 1.6
var _result_text: String = ""


static func make(game_mode: String, seed_v: int) -> TimingScreen:
	var s := TimingScreen.new()
	s.mode = game_mode
	s.rng.seed = seed_v
	if game_mode == "knife":
		s._knife = KnifeThrow.new()
		s._speed = TAU * float(GameData.KNIFE["board_spin_rps"]) * 2.0
	elif game_mode == "drinking":
		s._drink = DrinkingContest.new(s.rng)
	return s


func _init() -> void:
	super()
	dim = 0.7


func build() -> void:
	_title_key = "games." + mode
	var title := Label.new()
	title.text = Loc.t(_title_key)
	title.add_theme_font_size_override("font_size", 30)
	_box.add_child(title)
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(420, 28)
	_box.add_child(_bar)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_info)
	if _phase == "done":
		_info.text = _result_text
		add_button("menu.back", close)
		return
	add_button("games.stop" if _phase == "bar" else "games.mash", _press)
	add_button("menu.back", close)
	_refresh_info()


func _process(delta: float) -> void:
	if _bar == null or _phase == "done":
		return
	_t += delta
	if _phase == "bar":
		var extra: float = _drink.sway() * 2.0 if _drink != null else 0.0
		_cursor = 0.5 + 0.5 * sin(_t * (_speed + extra) * 2.0)
		_bar.value = _cursor
	elif _phase == "mash":
		_mash_left -= delta
		_bar.value = clampf(float(_mashes) / float(GameData.ARM_WRESTLE["mash_cap"]), 0.0, 1.0)
		if _mash_left <= 0.0:
			_finish_arm()


func _press() -> void:
	if _phase == "mash":
		_mashes += 1
		return
	var acc: float = 1.0 - absf(_cursor - 0.5) * 2.0
	match mode:
		"arm":
			_accuracy = acc
			_phase = "mash"
			_mash_left = 5.0
			_rebuild()
			return
		"knife":
			_knife.throw_knife(1.0 - acc)
			_info.text = "%s %s" % [Loc.t("games.score"), str(_knife.scores)]
			if _knife.done():
				var res: Dictionary = MiniGames.settle_knife(Session.state, _knife)
				_end(Loc.t("knife.done") % [_knife.total(), int(res["gold"])] + (" " + Loc.t("knife.outfit") if bool(res["outfit"]) else ""))
		"drinking":
			var standing: bool = _drink.drink(acc)
			_info.text = Loc.t("drink.round") % _drink.drinks
			if not standing:
				var res2: Dictionary = MiniGames.settle_drinking(Session.state, _drink)
				_end(Loc.t("drink.done") % [_drink.rounds_won(), int(res2["gold"])] + (" " + Loc.t("drink.rumour") if bool(res2["rumour"]) else ""))


func _finish_arm() -> void:
	var opp: String = ["dockhand", "sailor", "brute"][rng.randi() % 3]
	var won: bool = ArmWrestle.resolve(_accuracy, _mashes, opp, rng)
	var room: bool = int(Session.state["crew"]) < PortService.ship_stats(Session.state["ship_class"]).crew_max
	var res: Dictionary = MiniGames.settle_arm_wrestle(Session.state, won, room)
	var text: String = Loc.t("arm.won") % Loc.t("arm.opp." + opp) if won else Loc.t("arm.lost") % Loc.t("arm.opp." + opp)
	if bool(res["recruit"]):
		PortService.hire(Session.state, "green", Session.state.get("docked_at", PortData.START_PORT))
		text += " " + Loc.t("arm.recruited")
	_end(text)


func _end(text: String) -> void:
	_phase = "done"
	_result_text = text
	_rebuild()


func _refresh_info() -> void:
	match mode:
		"arm":
			_info.text = Loc.t("arm.hint")
		"knife":
			_info.text = Loc.t("knife.hint")
		"drinking":
			_info.text = Loc.t("drink.hint")
