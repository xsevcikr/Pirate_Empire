class_name CrewsScreen
extends MenuScreen
## The pirate crews page (from the rivals page): the pirate league, then each crew in its colours with its captain,
## ships, the waters it holds, its lagoon if the player has found it, and the latest news. Nothing here shows how
## hurt anyone is: the player only learns that by fighting them.

const NEWS_SHOWN: int = 6


func _init() -> void:
	super()
	_title_key = "pcrew.title"
	dim = 0.6


func build() -> void:
	_box.custom_minimum_size = Vector2(760, 0)
	var st: Dictionary = Session.state
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)
	_heading(col, Loc.t("pcrew.league"))
	var rank: int = 1
	for row: Dictionary in PirateCrews.league(st):
		var who: String = Loc.t("pcrew.you") if row["id"] == "player" else str(CrewData.def(row["id"])["name"])
		var l: Label = _line(col, "%d.  %s  -  %d %s" % [rank, who, int(row["score"]), Loc.t("pcrew.renown")])
		if row["id"] == "player":
			l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		rank += 1
	for id: String in CrewData.ORDER:
		_crew_card(col, st, id)
	var news: Array = PirateCrews.root(st)["news"]
	if not news.is_empty():
		_heading(col, Loc.t("pcrew.news"))
		for i in range(news.size() - 1, maxi(-1, news.size() - 1 - NEWS_SHOWN), -1):
			_line(col, "%s %d: %s" % [Loc.t("pcrew.day"), int(news[i]["day"]), PirateCrews.news_text(news[i])])
	add_button("menu.back", close)


func _crew_card(parent: Control, st: Dictionary, id: String) -> void:
	var d: Dictionary = CrewData.def(id)
	var c: Dictionary = PirateCrews.get_crew(st, id)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	parent.add_child(head)
	var swatch := ColorRect.new()
	swatch.color = d["color"]
	swatch.custom_minimum_size = Vector2(26, 26)
	head.add_child(swatch)
	var name := Label.new()
	name.text = "%s  -  %s %s" % [d["name"], Loc.t("pcrew.captain"), d["captain"]]
	name.add_theme_font_size_override("font_size", 22)
	head.add_child(name)
	if bool(c["eliminated"]):
		_line(parent, "    " + Loc.t("pcrew.gone"))
		return
	var held := PackedStringArray()
	for reg: String in WorldMap.REGIONS:
		if PirateCrews.owner_of(st, reg) == id:
			held.append(Loc.t("region." + reg))
	_line(parent, "    %s: %d   %s: %s" % [Loc.t("pcrew.ships"), int(c["fleet"]), Loc.t("pcrew.holds"), ", ".join(held) if not held.is_empty() else "-"])
	_line(parent, "    %s: %s" % [Loc.t("pcrew.style"), Loc.t("pcrew.style." + str(d["style"]))])
	var lag: String = Loc.t("pcrew.lagoon_unknown")
	if bool(c["lagoon_known"]):
		lag = Loc.t("pcrew.lagoon_at") % Loc.t("region." + str(d["home"]))
	_line(parent, "    " + lag)
	var claims := PackedStringArray()
	var all: Dictionary = PirateCrews.root(st)["claims"]
	for isl: String in all:
		if all[isl]["crew"] == id:
			claims.append(isl)
	if not claims.is_empty():
		_line(parent, "    %s: %s" % [Loc.t("pcrew.claims"), ", ".join(claims)])
	var maps: Array = (PirateCrews.root(st)["maps"] as Dictionary).get(id, [])
	if not maps.is_empty():
		_line(parent, "    " + Loc.t("pcrew.has_maps") % maps.size())
	var mood: String = "pcrew.mood.calm"
	if float(c["grudge"]) >= 60.0:
		mood = "pcrew.mood.hunting"
	elif float(c["grudge"]) >= 30.0:
		mood = "pcrew.mood.angry"
	_line(parent, "    " + Loc.t(mood))


func _heading(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	parent.add_child(l)


func _line(parent: Control, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l
