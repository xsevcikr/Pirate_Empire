class_name NewGameScreen
extends MenuScreen
## Captain name, difficulty and world seed.

const DIFFICULTIES: Array[String] = ["menu.diff_0", "menu.diff_1", "menu.diff_2", "menu.diff_3"]

var name_edit: LineEdit
var difficulty: OptionButton
var seed_edit: SpinBox
var start_button: Button


func _init() -> void:
	super()
	_title_key = "menu.new_game"


func build() -> void:
	name_edit = LineEdit.new()
	name_edit.text = ""
	name_edit.placeholder_text = Loc.t("menu.default_captain")
	add_row("menu.captain_name", name_edit)
	difficulty = OptionButton.new()
	for k in DIFFICULTIES:
		difficulty.add_item(Loc.t(k))
	difficulty.select(0)  # Easy first: the game is meant to be friendly for young captains
	add_row("menu.difficulty", difficulty)
	seed_edit = SpinBox.new()
	seed_edit.min_value = 1
	seed_edit.max_value = 999999
	seed_edit.value = 1
	add_row("menu.seed", seed_edit)
	start_button = add_button("menu.start", _on_start)
	add_button("menu.back", close)


func _on_start() -> void:
	Session.begin_new(name_edit.text, difficulty.selected, int(seed_edit.value))
	Session.enter_world(get_tree())
