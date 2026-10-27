class_name SaveLoadScreen
extends MenuScreen
## Slot list. With a world attached it saves into the slot, otherwise it loads from it.

var world: Node = null  ## set when opened from the pause menu
var slot_buttons: Dictionary = {}  ## slot -> Button


func _init() -> void:
	super()
	_title_key = "ui.save"


func _ready() -> void:
	_title_key = "ui.save" if world != null else "ui.load"
	super()


func build() -> void:
	var slots: Array = Session.SLOTS.duplicate()
	if world == null:
		slots.push_front(Session.AUTOSAVE_SLOT)
	for s: int in slots:
		var label: String = Loc.t("menu.autosave") if s == Session.AUTOSAVE_SLOT else Loc.t("menu.slot") % s
		var b: Button = add_button("menu.back", _on_slot.bind(s))
		b.text = "%s: %s" % [label, Session.summary(s)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = world == null and SaveGame.read(s).is_empty()
		slot_buttons[s] = b
	add_button("menu.back", close)


func _on_slot(slot: int) -> void:
	if world != null:
		Session.save_to(world, slot)
		_rebuild()
	elif Session.load_slot(slot):
		Session.enter_world(get_tree())
