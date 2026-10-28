class_name CatalogueSource
extends RefCounted
## What a catalogue sells. Subclass it, then open `CatalogueScreen.with_source(MySource.new())`.
## The screen asks for the items again after every purchase, so items() should read straight from the state.

var port_id: String = PortData.START_PORT


## i18n key of the screen title.
func title_key() -> String:
	return "cat.title"


## i18n keys of the tabs, in order. Every item's `category` must be one of these.
func categories() -> PackedStringArray:
	return PackedStringArray()


func items(_state: Dictionary) -> Array[CatalogueItem]:
	return []


## Spend the gold and hand over the item. Return false if refused; the screen then shows nothing new.
func buy(_state: Dictionary, _item: CatalogueItem) -> bool:
	return false


func gold(state: Dictionary) -> int:
	return int(state.get("gold", 0))


## Every icon this source can show, for tools/gen_catalogue_icons.gd.
func icon_list() -> PackedStringArray:
	return PackedStringArray()
