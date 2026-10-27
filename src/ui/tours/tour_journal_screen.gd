class_name TourJournalScreen
extends MenuScreen
## The treasure journal (N): the map pieces held, the rotate puzzle that joins them, the step the tour is on, the
## three hint buttons and the button that starts the encounter when the ship is at the right place.

var director: TourDirector
var tour_id: String = ""


func _init() -> void:
	super()
	_title_key = "tour.journal"
	dim = 0.55


func build() -> void:
	var tours: Array[String] = []
	for id: String in TourData.all_ids():
		if MapFragments.owned(Session.state, id) > 0:
			tours.append(id)
	if tours.is_empty():
		_label(Loc.t("tour.no_map"))
		add_button("menu.back", close)
		return
	if tour_id == "" or not tours.has(tour_id):
		tour_id = tours[0]
	for id in tours:
		var b: Button = add_button(TourData.tour(id)["name"], _pick.bind(id))
		b.disabled = id == tour_id
		if TourState.is_done(Session.state, id):
			b.text += "  (%s)" % Loc.t("tour.done")
	_show_tour()
	add_button("menu.back", close)


func _pick(id: String) -> void:
	tour_id = id
	_rebuild()


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(l)
	return l


func _show_tour() -> void:
	var st: Dictionary = Session.state
	var owned: int = MapFragments.owned(st, tour_id)
	_label(Loc.t("tour.pieces") % owned)
	_label(Loc.t("tour.view%d" % clampi(owned, 1, 3)))
	if TourState.is_done(st, tour_id):
		_label(Loc.t("tour.done"))
		return
	var step: Dictionary = TourState.current_step(st, tour_id)
	var idx: int = int(TourState.progress(st, tour_id)["step"])
	_label(Loc.t("tour.step") % [idx + 1, TourData.steps(tour_id).size()])
	if owned >= TourData.FRAGMENTS_PER_TOUR:
		_label(Loc.t(step["text"]))
	if step["kind"] == "clue":
		if owned >= TourData.FRAGMENTS_PER_TOUR:
			var t: Array[int] = director.puzzle_turns(tour_id)
			for i in t.size():
				add_button("tour.rotate", _rotate.bind(i)).text = "%s  (%d°)" % [Loc.t("tour.rotate") % (i + 1), t[i] * 90]
	elif director != null and director.near_step(tour_id):
		match step["kind"]:
			"landing":
				add_button("tour.paces_ask", _paces)
			"dungeon":
				add_button("tour.encounter", _encounter.bind(true))
			"guardian":
				add_button("tour.encounter", _encounter.bind(false))
	if owned < TourData.FRAGMENTS_PER_TOUR:
		return
	add_button("tour.hint_free", _hint.bind(1))
	add_button("tour.hint_tavern", _hint.bind(2)).text = Loc.t("tour.hint_tavern") % TourData.HINT_COST[2]
	add_button("tour.hint_chart", _hint.bind(3)).text = Loc.t("tour.hint_chart") % TourData.HINT_COST[3]
	var shown: int = int(TourState.progress(st, tour_id)["hints"].get(step["id"], 0))
	for lv in range(1, shown + 1):
		_label("%d: %s" % [lv, Loc.t("%s.hint%d" % [step["text"], lv])])


func _rotate(i: int) -> void:
	director.rotate_piece(tour_id, i)
	_rebuild()


func _hint(level: int) -> void:
	TourState.hint(Session.state, tour_id, level)
	_rebuild()


func _paces() -> void:
	var step: Dictionary = TourState.current_step(Session.state, tour_id)
	director.count_paces(tour_id, int(step["paces"]))
	if bool(TourState.progress(Session.state, tour_id).get("spot_found", false)):
		director.dig_spot(tour_id)
	_rebuild()


func _encounter(dungeon: bool) -> void:
	var screen := TourEncounterScreen.new()
	screen.director = director
	screen.tour_id = tour_id
	if dungeon:
		screen.run = director.start_dungeon(tour_id)
	else:
		screen.fight = director.start_guardian(tour_id)
	open_child(screen)
