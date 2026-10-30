class_name DiceScreen
extends MenuScreen
## Liar's dice against a tavern regular: bid with the arrows, call a bluff, win or lose the stake.

var game: LiarsDice
var bet: int = 10
var shady: bool = false
var rng := RandomNumberGenerator.new()
var qty: int = 1
var face: int = 1
var _msg: String = ""


static func make(stake: int, dodgy: bool, seed_v: int) -> DiceScreen:
	var s := DiceScreen.new()
	s.bet = stake
	s.shady = dodgy
	s.rng.seed = seed_v
	var kinds: Array = GameData.LIARS_DICE["opponents"].keys()
	s.game = LiarsDice.new(s.rng, str(kinds[seed_v % kinds.size()]))
	return s


func _init() -> void:
	super()
	_title_key = "games.dice"
	dim = 0.7


func build() -> void:
	var mine := Label.new()
	mine.text = "%s: %s" % [Loc.t("dice.yours"), " ".join(game.mine.map(func(d: int) -> String: return str(d)))]
	mine.add_theme_font_size_override("font_size", 26)
	_box.add_child(mine)
	var theirs := Label.new()
	theirs.text = "%s: %s (%s)" % [Loc.t("dice.theirs"), "? ".repeat(game.theirs.size()).strip_edges(), Loc.t("dice.kind." + game.personality)]
	_box.add_child(theirs)
	var bid := Label.new()
	bid.text = Loc.t("dice.no_bid") if game.bid_qty == 0 else Loc.t("dice.bid") % [game.bid_qty, game.bid_face, Loc.t("dice.by_you") if game.bid_by_player else Loc.t("dice.by_them")]
	_box.add_child(bid)
	if _msg != "":
		var m := Label.new()
		m.text = _msg
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(m)
	if game.over:
		var res: Dictionary = MiniGames.settle_dice(Session.state, game, bet, shady, rng)
		var end := Label.new()
		end.text = Loc.t("dice.won") % bet if game.player_won else Loc.t("dice.lost") % bet
		_box.add_child(end)
		if str(res["map_fragment"]) != "":
			_toast("dice.fragment")
		add_button("menu.back", close)
		return
	var row := HBoxContainer.new()
	row.add_child(_step("-", func() -> void: qty = maxi(qty - 1, 1)))
	var ql := Label.new()
	ql.text = "%d x" % qty
	row.add_child(ql)
	row.add_child(_step("+", func() -> void: qty = mini(qty + 1, game.total_dice())))
	row.add_child(_step("<", func() -> void: face = maxi(face - 1, 1)))
	var fl := Label.new()
	fl.text = str(face)
	row.add_child(fl)
	row.add_child(_step(">", func() -> void: face = mini(face + 1, 6)))
	_box.add_child(row)
	var can: bool = game.is_raise(qty, face)
	var b: Button = add_button("dice.make_bid", _bid)
	b.disabled = not can
	var c: Button = add_button("dice.call", _call)
	c.disabled = game.bid_qty == 0 or game.bid_by_player
	add_button("menu.back", close)


func _step(text: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void:
		f.call()
		_rebuild())
	return b


func _bid() -> void:
	if not game.player_bid(qty, face):
		return
	var answer: String = game.npc_turn()
	_after(answer)


func _call() -> void:
	game.call_bid(true)
	_after("call")


func _after(answer: String) -> void:
	if answer == "call" or game.over:
		var lc: Dictionary = game.last_call
		_msg = Loc.t("dice.revealed") % [int(lc["actual"]), int(lc["bid_face"]), Loc.t("dice.you_win_round") if bool(lc["player_won"]) else Loc.t("dice.they_win_round")]
		qty = 1
		face = 1
	else:
		_msg = Loc.t("dice.they_raise")
		qty = mini(game.bid_qty, game.total_dice())
		face = game.bid_face
	_rebuild()


func _toast(key: String) -> void:
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.toast.emit(Loc.t(key))
