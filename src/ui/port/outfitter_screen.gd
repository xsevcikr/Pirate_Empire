class_name OutfitterScreen
extends CatalogueScreen
## Weapons for the captain and ammunition for the guns, as a catalogue.


func _init() -> void:
	super()
	source = OutfitterCatalogue.new()
