class_name RangeScreen
extends MenuScreen
## The gunnery range: click the floating targets within a minute. Hits earn gunnery XP.

var game: GunneryRange
var rng := RandomNumberGenerator.new()
var _field: Control
var _info: Label
var _done: bool = false


static func make(seed_v: int) -> RangeScreen:
	var s := RangeScreen.new()
	s.rng.seed = seed_v
	s.game = GunneryRange.new(s.rng)
	return s


func _init() -> void:
	super()
	_title_key = "games.range"
	dim = 0.7


func build() -> void:
	_info = Label.new()
	_box.add_child(_info)
	_field = RangeField.new()
	_field.set("game", game)
	_field.custom_minimum_size = Vector2(520, 300)
	_box.add_child(_field)
	add_button("menu.back", close)


func _process(delta: float) -> void:
	if game == null or _info == null or _done:
		return
	game.step(delta)
	_info.text = Loc.t("range.status") % [int(game.time_left), game.hits, game.shots]
	_field.queue_redraw()
	if game.over():
		_done = true
		var res: Dictionary = MiniGames.settle_range(Session.state, game)
		_info.text = Loc.t("range.done") % [game.hits, int(res["xp"])]


class RangeField extends Control:
	var game: GunneryRange

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.3, 0.45))
		for t in game.targets:
			var p := Vector2(float(t["x"]) * size.x, (1.0 - (float(t["range"]) - 60.0) / 160.0) * size.y * 0.8 + size.y * 0.1)
			var r: float = 18.0 * (100.0 / maxf(float(t["range"]), 50.0))
			draw_circle(p, r, Color(0.9, 0.3, 0.2))
			draw_circle(p, r * 0.5, Color(0.95, 0.95, 0.9))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not game.over():
			var p: Vector2 = (event as InputEventMouseButton).position
			var aim_range: float = 60.0 + (1.0 - (p.y - size.y * 0.1) / (size.y * 0.8)) * 160.0
			game.fire(p.x / size.x, aim_range)
