class_name CatalogueItem
extends RefCounted
## One card in a catalogue: what it is, what it does, what it costs and whether it can be bought.
## Sources build these fresh every time the screen draws, so they never need to be saved.

enum Status { AVAILABLE, LOCKED, OWNED, MAXED }

var id: String = ""
var category: String = ""  ## i18n key of the tab this card sits under
var title: String = ""  ## already translated
var blurb: String = ""  ## one short line under the title, already translated
var icon: String = ""  ## "kit/model" of a Kenney model or "proc/name"; see CatalogueIcons
var stats: Array = []  ## [[label, value], ...], both already translated
var price: int = 0
var requirement: String = ""  ## shown when LOCKED, e.g. "needs fame 300"
var status: Status = Status.AVAILABLE
var tier: int = -1  ## current tier for tiered items, -1 for none
var tiers: int = 0
var action_key: String = "cat.buy"
var note: String = ""  ## shown in place of the price or "Owned"/"Maxed" tag when set, already translated
var note_bad: bool = false  ## draw the note in red
var data: Dictionary = {}  ## anything the source needs back in buy()


static func make(item_id: String, category_key: String, item_title: String, item_icon: String, item_price: int) -> CatalogueItem:
	var it := CatalogueItem.new()
	it.id = item_id
	it.category = category_key
	it.title = item_title
	it.icon = item_icon
	it.price = item_price
	return it


func stat(label: String, value: String) -> CatalogueItem:
	stats.append([label, value])
	return self


func lock(why: String) -> CatalogueItem:
	status = Status.LOCKED
	requirement = why
	return self


func can_buy(gold: int) -> bool:
	return status == Status.AVAILABLE and price <= gold
