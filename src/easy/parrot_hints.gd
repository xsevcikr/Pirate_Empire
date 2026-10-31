class_name ParrotHints
extends RefCounted
## What the captain's parrot says when asked (or every HINT_EVERY_S at sea): first anything urgent (a leaking
## hull, empty food barrels, no crew), then which way the nearest hidden treasure lies, then a tip for the first
## goal still open. Returns a text key and its arguments, so tests read the choice without a scene.

const HINT_EVERY_S: float = 150.0
const LOW_HULL: float = 0.4
const LOW_FOOD_DAYS: float = 1.5
const NAME_KEY: String = "parrot.name"


## ctx: {"hull": 0..1, "pos": Vector2, "at_sea": bool}
static func pick(state: Dictionary, ctx: Dictionary) -> Dictionary:
	if float(ctx.get("hull", 1.0)) < LOW_HULL:
		return {"key": "parrot.hint_repair", "args": []}
	var sup: Dictionary = state.get("supplies", {})
	if float(sup.get("food", 99.0)) < LOW_FOOD_DAYS and int(state.get("crew", 0)) > 0:
		return {"key": "parrot.hint_food", "args": []}
	if int(state.get("crew", 0)) <= 0 and str(state.get("tutorial", "done")) == "done":
		return {"key": "parrot.hint_crew", "args": []}
	if ctx.has("pos"):
		var near: Array[Dictionary] = HiddenLoot.near(state, ctx["pos"], HiddenLoot.SPOT_M * 2.5)
		if not near.is_empty():
			var dir: String = HiddenLoot.compass(ctx["pos"], near[0]["pos"])
			return {"key": "parrot.hint_loot", "args": [Loc.t("compass." + dir)]}
	var open: Array[Dictionary] = EasyPlay.active(state, 1)
	if not open.is_empty():
		return {"key": "goal." + str(open[0]["id"]) + ".hint", "args": []}
	return {"key": "parrot.hint_idle", "args": []}


## The line as shown: "Polly: <hint>".
static func say(state: Dictionary, ctx: Dictionary) -> String:
	var h: Dictionary = pick(state, ctx)
	var text: String = Loc.t(str(h["key"]))
	if not (h["args"] as Array).is_empty():
		text = text % h["args"]
	return Loc.t("parrot.says") % [Loc.t(NAME_KEY), text]
