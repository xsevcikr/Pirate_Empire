class_name MiniGameMenu
extends PortScreen
## The tavern's games table: choose a game and a stake. Fort towns also have the gunnery range.

const TAVERN_GAMES: Array[String] = ["dice", "bones", "arm", "drinking", "knife"]
var bet_index: int = 1
var shady: bool = false


func _init() -> void:
	super()
	_title_key = "games.title"
	dim = 0.0


func bet() -> int:
	return GameData.BETS[bet_index]


func build() -> void:
	add_header()
	var rng_seed: int = int(state()["seed"]) + int(state()["day"])
	shady = rng_seed % 3 == 0
	var stake := Label.new()
	stake.text = "%s: %d g" % [Loc.t("games.stake"), bet()]
	stake.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(stake)
	add_button("games.raise_stake", func() -> void:
		bet_index = (bet_index + 1) % GameData.BETS.size()
		_rebuild())
	begin_list(300.0)
	for g in TAVERN_GAMES:
		var needs_bet: bool = g in ["dice", "bones"]
		var ok: bool = not needs_bet or MiniGames.valid_bet(state(), bet())
		add_item_row("%s - %s" % [Loc.t("games." + g), Loc.t("games.%s.desc" % g)], [[Loc.t("games.play"), _play.bind(g) if ok else Callable()]])
	if bool(PortData.PORTS[port_id]["lawful"]):
		add_item_row("%s - %s" % [Loc.t("games.range"), Loc.t("games.range.desc")], [[Loc.t("games.play"), _play.bind("range")]])
	add_button("menu.back", close)


func _play(game: String) -> void:
	var seed_v: int = int(state()["seed"]) * 7919 + int(state()["day"]) * 31 + int(Time.get_ticks_msec() % 997)
	var screen: MenuScreen
	match game:
		"dice":
			screen = DiceScreen.make(bet(), shady, seed_v)
		"bones":
			screen = BonesScreen.make(bet(), seed_v)
		"range":
			screen = RangeScreen.make(seed_v)
		_:
			screen = TimingScreen.make(game, seed_v)
	open_child(screen)
