class_name LiarsDice
extends RefCounted
## Liar's dice against one NPC. Each side rolls five dice in secret and bids "at least N dice show F" across both
## hands; a bid must raise the quantity or the face. Calling a bid reveals everything: the loser of the call loses a
## die, and the first to run out of dice loses the game.

var rng: RandomNumberGenerator
var personality: String
var mine: Array[int] = []
var theirs: Array[int] = []
var bid_qty: int = 0
var bid_face: int = 0
var bid_by_player: bool = false
var over: bool = false
var player_won: bool = false
var last_call: Dictionary = {}


func _init(r: RandomNumberGenerator, who: String = "cautious") -> void:
	rng = r
	personality = who
	mine.resize(int(GameData.LIARS_DICE["dice"]))
	theirs.resize(int(GameData.LIARS_DICE["dice"]))
	roll()


func roll() -> void:
	for i in mine.size():
		mine[i] = rng.randi_range(1, int(GameData.LIARS_DICE["faces"]))
	for i in theirs.size():
		theirs[i] = rng.randi_range(1, int(GameData.LIARS_DICE["faces"]))
	bid_qty = 0
	bid_face = 0


func total_dice() -> int:
	return mine.size() + theirs.size()


func count_face(face: int) -> int:
	var n: int = 0
	for d in mine:
		n += 1 if d == face else 0
	for d in theirs:
		n += 1 if d == face else 0
	return n


func is_raise(qty: int, face: int) -> bool:
	if face < 1 or face > int(GameData.LIARS_DICE["faces"]) or qty < 1 or qty > total_dice():
		return false
	return qty > bid_qty or (qty == bid_qty and face > bid_face)


func player_bid(qty: int, face: int) -> bool:
	if over or not is_raise(qty, face):
		return false
	bid_qty = qty
	bid_face = face
	bid_by_player = true
	return true


## Odds that at least `qty` of `face` exist given the dice this side can see (`own`) and `hidden` unseen dice.
static func chance_at_least(qty: int, face: int, own: Array[int], hidden: int) -> float:
	var have: int = 0
	for d in own:
		have += 1 if d == face else 0
	var need: int = qty - have
	if need <= 0:
		return 1.0
	if need > hidden:
		return 0.0
	var p: float = 1.0 / float(GameData.LIARS_DICE["faces"])
	var total: float = 0.0
	for k in range(need, hidden + 1):
		total += _choose(hidden, k) * pow(p, k) * pow(1.0 - p, hidden - k)
	return total


static func _choose(n: int, k: int) -> float:
	var r: float = 1.0
	for i in k:
		r = r * float(n - i) / float(i + 1)
	return r


## The NPC answers the player's bid: calls it, or raises. Returns "call" or "raise".
func npc_turn() -> String:
	var def: Dictionary = GameData.LIARS_DICE["opponents"][personality]
	if bid_qty > 0:
		var truth: float = chance_at_least(bid_qty, bid_face, theirs, mine.size())
		if truth < float(def["call_at"]):
			return call_bid(false)
	# raise: the most likely higher bid, or a bluff
	var best_qty: int = 0
	var best_face: int = 0
	var best_p: float = -1.0
	for f in range(1, int(GameData.LIARS_DICE["faces"]) + 1):
		for q in range(1, total_dice() + 1):
			if not is_raise(q, f):
				continue
			var p: float = chance_at_least(q, f, theirs, mine.size())
			if p > best_p or (p == best_p and q < best_qty):
				best_p = p
				best_qty = q
				best_face = f
	if best_qty == 0:
		return call_bid(false)
	if rng.randf() < float(def["bluff"]):
		best_qty = mini(best_qty + 1, total_dice())
	bid_qty = best_qty
	bid_face = best_face
	bid_by_player = false
	return "raise"


## Somebody calls the standing bid. `by_player` says who called. The caller wins when the bid was false.
func call_bid(by_player: bool) -> String:
	var actual: int = count_face(bid_face)
	var bid_true: bool = actual >= bid_qty
	var caller_wins: bool = not bid_true
	var player_wins_call: bool = caller_wins if by_player else not caller_wins
	last_call = {"actual": actual, "bid_qty": bid_qty, "bid_face": bid_face, "player_won": player_wins_call, "by_player": by_player}
	if player_wins_call:
		theirs.pop_back()
	else:
		mine.pop_back()
	if theirs.is_empty():
		over = true
		player_won = true
	elif mine.is_empty():
		over = true
		player_won = false
	else:
		roll()
	return "call"
