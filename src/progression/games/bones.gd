class_name Bones
extends RefCounted
## "Bones": a 21-style card game. Cards 2-10 count their number, face cards 10, aces 11 or 1. Beat the dealer
## without going over 21; a two-card 21 pays 3 to 2; the dealer stands on 17.

var rng: RandomNumberGenerator
var deck: Array[int] = []
var player: Array[int] = []
var dealer: Array[int] = []
var over: bool = false
var outcome: String = ""  ## "win", "lose", "push" or "blackjack"


func _init(r: RandomNumberGenerator) -> void:
	rng = r
	for suit in int(GameData.BONES["suits"]):
		for rank in range(1, int(GameData.BONES["ranks"]) + 1):
			deck.append(rank)
	for i in range(deck.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: int = deck[i]
		deck[i] = deck[j]
		deck[j] = t
	player = [deck.pop_back(), deck.pop_back()]
	dealer = [deck.pop_back(), deck.pop_back()]
	if total(player) == int(GameData.BONES["target"]):
		_finish()


static func value_of(rank: int) -> int:
	return 11 if rank == 1 else mini(rank, 10)


static func total(hand: Array[int]) -> int:
	var t: int = 0
	var aces: int = 0
	for c in hand:
		t += value_of(c)
		aces += 1 if c == 1 else 0
	while t > int(GameData.BONES["target"]) and aces > 0:
		t -= 10
		aces -= 1
	return t


func hit() -> void:
	if over:
		return
	player.append(deck.pop_back())
	if total(player) >= int(GameData.BONES["target"]):
		_finish()


func stand() -> void:
	if not over:
		_finish()


func _finish() -> void:
	var target: int = int(GameData.BONES["target"])
	var pt: int = total(player)
	if pt <= target:
		while total(dealer) < int(GameData.BONES["dealer_stands"]):
			dealer.append(deck.pop_back())
	var dt: int = total(dealer)
	over = true
	if pt > target:
		outcome = "lose"
	elif pt == target and player.size() == 2 and dt != target:
		outcome = "blackjack"
	elif dt > target or pt > dt:
		outcome = "win"
	elif pt == dt:
		outcome = "push"
	else:
		outcome = "lose"


## Gold change for a bet: +bet, +1.5 bet, 0 or -bet.
func payout(bet: int) -> int:
	match outcome:
		"blackjack":
			return int(float(bet) * float(GameData.BONES["blackjack_pay"]))
		"win":
			return bet
		"lose":
			return -bet
	return 0
