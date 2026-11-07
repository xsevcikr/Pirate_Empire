class_name DefeatScreen
extends MenuScreen
## Shown after the player's ship goes down: where they washed up and what it cost.

signal continued

var result: Dictionary = {}


func _init() -> void:
	super()
	dim = 0.75
	_title_key = "defeat.title"


func _ready() -> void:
	if bool(result.get("second_chance", false)):
		_title_key = "defeat.title_second"
	super()


func build() -> void:
	var l := Label.new()
	l.text = Loc.t("defeat.body") % [PortData.PORTS[result["port"]]["name"], int(result["gold_lost"]), int(result["crew_lost"])]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(l)
	var k := Label.new()
	if bool(result.get("second_chance", false)):
		k.text = Loc.t("defeat.second_chance")
	else:
		k.text = Loc.t("defeat.ship_kept" if bool(result["ship_kept"]) else "defeat.ship_lost")
	k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(k)
	add_button("menu.continue", func() -> void: continued.emit())
