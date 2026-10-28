class_name ShipyardScreen
extends CatalogueScreen
## The ship upgrade station: buy a ship (with trade-in), install upgrades, repair and insure, as a catalogue.


func _init() -> void:
	super()
	source = ShipyardCatalogue.new()


func _buy_ship(class_id: String) -> bool:
	return buy_id("ship:" + class_id)


func _upgrade(line: String) -> bool:
	return buy_id("upg:" + line)
