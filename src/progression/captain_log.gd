class_name CaptainLog
extends RefCounted
## The captain's log writes itself: dated entries for battles, prizes, storms, discoveries, rivals and tours, in
## state["log"] (shared with the event log). Entries are {"day", "kind", "id"} plus an optional "arg".

const MAX_ENTRIES: int = 200
const KINDS: Array[String] = ["battle", "prize", "storm", "discovery", "rival", "tour", "level", "achievement", "event"]


static func add(state: Dictionary, kind: String, id: String, arg: String = "") -> void:
	var log: Array = state["log"]
	var e: Dictionary = {"day": int(state.get("day", 0)), "kind": kind, "id": id}
	if arg != "":
		e["arg"] = arg
	log.append(e)
	while log.size() > MAX_ENTRIES:
		log.pop_front()


## The text of an entry, from the strings table.
static func text(e: Dictionary) -> String:
	var key: String = "log.%s" % str(e.get("id", ""))
	var base: String = Loc.t(key)
	if base == key:
		base = Loc.t("log.generic") % str(e.get("id", ""))
	return base % str(e["arg"]) if e.has("arg") and base.contains("%s") else base


static func of_kind(state: Dictionary, kind: String) -> Array:
	return (state["log"] as Array).filter(func(e: Dictionary) -> bool: return e.get("kind", "") == kind)
