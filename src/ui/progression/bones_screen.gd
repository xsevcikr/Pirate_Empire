class_name BonesScreen
extends MenuScreen
## Bones, the pirate 21: hit or stand against the house.

var game: Bones
var bet: int = 10
var rng := RandomNumberGenerator.new()
var _settled: bool = false


static func make(stake: int, seed_v: int) -> BonesScreen:
	var s := BonesScreen.new()
	s.bet = stake
	s.rng.seed = seed_v
	s.game = Bones.new(s.rng)
	return s


func _init() -> void:
	super()
	_title_key = "games.bones"
	dim = 0.7


static func card_name(rank: int) -> String:
	return ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"][rank - 1]


func build() -> void:
	var you := Label.new()
	you.text = "%s: %s  (%d)" % [Loc.t("bones.yours"), " ".join(game.player.map(func(c: int) -> String: return card_name(c))), Bones.total(game.player)]
	you.add_theme_font_size_override("font_size", 24)
	_box.add_child(you)
	var house := Label.new()
	if game.over:
		house.text = "%s: %s  (%d)" % [Loc.t("bones.house"), " ".join(game.dealer.map(func(c: int) -> String: return card_name(c))), Bones.total(game.dealer)]
	else:
		house.text = "%s: %s ?" % [Loc.t("bones.house"), card_name(game.dealer[0])]
	_box.add_child(house)
	if game.over:
		if not _settled:
			_settled = true
			var res: Dictionary = MiniGames.settle_bones(Session.state, game, bet, rng)
			if int(res["rumour"]) >= 0:
				var bus: Node = Svc.node("EventBus")
				if bus != null:
					bus.toast.emit(Loc.t("rumour.%d" % int(res["rumour"])))
		var end := Label.new()
		end.text = Loc.t("bones." + game.outcome) % absi(game.payout(bet))
		_box.add_child(end)
		add_button("menu.back", close)
		return
	add_button("bones.hit", func() -> void:
		game.hit()
		_rebuild())
	add_button("bones.stand", func() -> void:
		game.stand()
		_rebuild())
